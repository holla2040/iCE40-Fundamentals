# Button Debounce Tutorial

This tutorial explains switch debouncing and seven-segment displays.

## The Problem: Switch Bounce

When you press a mechanical button, the metal contacts don't make a clean connection. They literally bounce, creating rapid on-off-on-off transitions for a few milliseconds:

```
Ideal:     ______|‾‾‾‾‾‾‾‾‾‾
Reality:   ______|‾|_|‾|_|‾‾‾‾
                 ↑ bounce ↑
```

This can cause a single press to register 2-10 times.

## The Solution: Debounce Filter

Wait for the signal to be stable for a period (typically 10-20ms) before accepting the new value.

### debounce.v Explained

```verilog
parameter DEBOUNCE_COUNT = 250000;  // 10ms at 25MHz

reg [17:0] r_Count = 0;   // Counter for stability timing
reg r_State = 0;          // Current debounced state
```

The algorithm:
1. If input differs from current state, start counting
2. If input stays different for 250,000 clocks (10ms), update state
3. If input matches state again, reset counter

```verilog
if (i_Switch != r_State) begin
  if (r_Count < DEBOUNCE_COUNT - 1)
    r_Count <= r_Count + 1;    // Keep counting
  else begin
    r_State <= i_Switch;        // Accept new state
    r_Count <= 0;
  end
end else begin
  r_Count <= 0;                 // Reset - input matches
end
```

### Bypass Mode

When `i_Enable=0`, the raw input passes through:

```verilog
wire w_Output = i_Enable ? r_State : i_Switch;
```

This lets you see the difference between debounced and raw signals.

### Edge Detection

To trigger actions on button press (not hold), we detect rising edges:

```verilog
reg r_Switch_Prev = 0;

always @(posedge i_Clk)
  r_Switch_Prev <= w_Output;

assign o_Rise = w_Output & ~r_Switch_Prev;
```

`o_Rise` is HIGH for exactly one clock cycle when the button is first pressed.

## Seven-Segment Display

A 7-segment display has 7 LEDs arranged to form digits:

```
  AAA
 F   B
 F   B
  GGG
 E   C
 E   C
  DDD
```

### Encoding (Active Low)

The Nandland board uses active-low segments (0 = ON, 1 = OFF):

```verilog
case (i_Value)
  //                 GFEDCBA
  4'd0: r_Segment = 7'b1000000;  // 0: A,B,C,D,E,F on
  4'd1: r_Segment = 7'b1111001;  // 1: B,C on
  4'd2: r_Segment = 7'b0100100;  // 2: A,B,D,E,G on
  // ...
endcase
```

### Splitting Digits

To display a two-digit number:

```verilog
wire [3:0] w_Ones = r_Count % 10;  // Remainder
wire [3:0] w_Tens = r_Count / 10;  // Quotient
```

Note: Division/modulo by constants synthesizes efficiently as lookup tables.

## Top Module Structure

```
                    ┌─────────────────────────────────┐
  i_Switch_1 ──────►│ debounce (enable=r_Debounce_En) │──► w_Sw1_Rise
                    └─────────────────────────────────┘
                                                          │
                    ┌─────────────────────────────────┐   │
  i_Switch_2 ──────►│ debounce (enable=1)             │──►│ w_Sw2_Rise
                    └─────────────────────────────────┘   │
                                                          ▼
                    ┌─────────────────────────────────────────┐
                    │ Toggle: r_Debounce_En                   │
                    │ Counter: r_Count (0-99)                 │
                    └─────────────────────────────────────────┘
                              │                    │
                              ▼                    ▼
                    ┌──────────────┐    ┌──────────────┐
                    │  seven_seg   │    │  seven_seg   │
                    │  (tens)      │    │  (ones)      │
                    └──────────────┘    └──────────────┘
                              │                    │
                              ▼                    ▼
                        o_Segment1_*          o_Segment2_*
```

## Key Concepts

1. **Metastability**: External signals should be synchronized to the clock domain. The debounce filter inherently handles this.

2. **Counter Width**: 250,000 requires 18 bits (2^18 = 262,144).

3. **Active Low**: Many displays use active-low signaling. Check your hardware!

4. **Edge vs Level**: Use edge detection for button actions, level for switches.
