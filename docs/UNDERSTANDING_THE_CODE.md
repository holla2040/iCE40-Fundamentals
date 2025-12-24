# Understanding the Code

This guide helps you read and understand the Verilog code in this repository. You don't need to memorize these patterns - Claude Code knows them. But understanding them will help you read code, review what Claude generates, and spot mistakes.

## TL;DR

| Prefix/Pattern | Meaning | Example |
|----------------|---------|---------|
| `i_` | Input port | `i_Clk`, `i_Switch_1` |
| `o_` | Output port | `o_LED_1`, `o_UART_TX` |
| `r_` | Register (stores value) | `r_Count`, `r_State` |
| `w_` | Wire (connection) | `w_Rx_Valid`, `w_Output` |
| `UPPERCASE` | Constant | `CLK_FREQ`, `BAUD_RATE` |
| `S_` or `IDLE` | State machine state | `S_IDLE`, `START_BIT` |
| `<=` | Register assignment | `r_Count <= r_Count + 1` |
| `=` | Combinational assignment | `assign w_Out = a & b` |

**The one rule:** Use `<=` inside `always @(posedge clk)` blocks, use `=` everywhere else.

Read on for the *why* behind each pattern.

---

## Why Consistent Code Matters

Imagine reading a book where every chapter uses different spelling conventions. "Color" in chapter 1, "colour" in chapter 2. The meaning is the same, but it's distracting and confusing.

Code is the same way. When signal names follow a pattern, you can focus on *what the code does* instead of *what things are called*. Consistency reduces mental effort.

In a team (or when working with Claude), everyone following the same patterns means:
- You can read anyone's code quickly
- Bugs are easier to spot (inconsistency stands out)
- Less time debating style, more time solving problems

---

## The Naming Patterns You'll See

### Inputs Start with `i_`, Outputs Start with `o_`

When you see a signal in a module's port list, the first two characters tell you its direction:

```verilog
module blink (
  input  i_Clk,      // i_ means input
  output o_LED_1     // o_ means output
);
```

**Why this helps:** When you're reading code and see `i_Switch_1`, you instantly know it's coming *into* the module from outside. When you see `o_UART_TX`, you know it's going *out* to the physical pin.

### Registers Start with `r_`

A register holds a value across clock cycles. It's like a variable that remembers:

```verilog
reg [17:0] r_Count;    // r_ means register
reg        r_State;
```

**Why this helps:** When you see `r_Count <= r_Count + 1`, the `r_` tells you this value persists. It was something last clock cycle, and it'll be something new next clock cycle.

### Wires Start with `w_`

A wire is a direct connection - it doesn't store anything, just passes a value through:

```verilog
wire w_Rx_Valid;       // w_ means wire
wire [7:0] w_Rx_Byte;
```

**Why this helps:** When you see `w_Output`, you know it's computed from something else *right now*. It's not remembered from before.

### The Difference Matters

```verilog
reg  r_LED;           // This STORES the LED state
wire w_Button_Pressed; // This IS the button state right now

always @(posedge clk) begin
  if (w_Button_Pressed)   // Check the wire (current value)
    r_LED <= ~r_LED;      // Toggle the register (stored value)
end
```

If you mix these up, your design won't work. The prefixes prevent that confusion.

---

## Constants Are UPPERCASE

When you see `UPPERCASE_WITH_UNDERSCORES`, it's a constant - a value that never changes:

```verilog
parameter CLK_FREQ = 25_000_000;   // 25 MHz - set once, never changes
localparam IDLE = 3'd0;            // State value - fixed
localparam BAUD_RATE = 115200;     // Serial speed - constant
```

**Why this helps:** When reading `if (counter == CLKS_PER_BIT)`, you know `CLKS_PER_BIT` is a fixed value defined somewhere, not something that changes at runtime.

### `parameter` vs `localparam`

- `parameter` can be overridden when the module is instantiated (like a function argument)
- `localparam` is fixed inside the module (like a constant)

```verilog
module uart_rx #(
  parameter CLK_FREQ = 25_000_000,  // Can be changed per-instance
  parameter BAUD = 115200
)(
  ...
);
  localparam CLKS_PER_BIT = CLK_FREQ / BAUD;  // Calculated, fixed internally
```

---

## State Machines Use Named States

Instead of magic numbers, state machines use named constants:

```verilog
// Define what each state means
localparam IDLE      = 3'd0;
localparam START_BIT = 3'd1;
localparam DATA_BITS = 3'd2;
localparam STOP_BIT  = 3'd3;

// Use the names, not numbers
case (state)
  IDLE:      ...
  START_BIT: ...
  DATA_BITS: ...
  STOP_BIT:  ...
endcase
```

**Why this helps:** `if (state == IDLE)` is readable. `if (state == 3'd0)` is not. Six months later, you won't remember what `3'd0` meant.

Sometimes you'll see an `S_` prefix for states:

```verilog
localparam S_IDLE     = 4'd0;
localparam S_START    = 4'd1;
localparam S_ADDR     = 4'd2;
localparam S_ADDR_ACK = 4'd3;
```

This is common in complex modules with many constants, so states are easy to identify.

---

## Module Connections Use Named Ports

When one module uses another, connections are explicit:

```verilog
uart_rx #(
  .CLK_FREQ(25_000_000),    // Parameter name = value
  .BAUD(115200)
) u_uart (
  .clk(i_Clk),              // Port name = signal
  .rst(w_Reset),
  .rx_in(i_UART_RX),
  .rx_data(w_Rx_Byte),
  .rx_valid(w_Rx_Valid)
);
```

**Why this helps:** You can see exactly what connects to what. The left side (`.clk`) is the port on `uart_rx`. The right side (`i_Clk`) is the signal in the current module.

This catches mistakes. If you accidentally connect the wrong signal, it's visible. With positional connections (which we avoid), a mistake is invisible:

```verilog
// BAD: Which signal connects to which port?
uart_rx u_uart (i_Clk, w_Reset, i_UART_RX, w_Rx_Byte, w_Rx_Valid);
```

---

## Clock and Reset Are Always First

In every module, you'll see clock and reset listed first:

```verilog
module my_module (
  input  i_Clk,        // Always first
  input  i_Rst,        // Always second (if present)
  input  i_Data,       // Then other inputs
  output o_Result      // Then outputs
);
```

**Why this helps:** You always know where to find them. Consistency means you don't have to hunt.

---

## The Structure of an `always` Block

Sequential logic (registers) uses this pattern:

```verilog
always @(posedge i_Clk) begin
  if (i_Rst) begin
    // Reset everything to known values
    r_Counter <= 0;
    r_State   <= IDLE;
  end else begin
    // Normal operation
    r_Counter <= r_Counter + 1;
  end
end
```

Key things to notice:

1. **`@(posedge i_Clk)`** - This code runs on the rising edge of the clock
2. **Reset comes first** - Always check reset before doing anything else
3. **`<=` not `=`** - Sequential blocks use non-blocking assignment
4. **Reset everything** - Every register gets a reset value

**Why reset everything?** When the FPGA powers on, registers contain random garbage. Without reset, your state machine might start in an impossible state.

---

## Two Kinds of Assignment

This is crucial and trips up many beginners:

### `<=` (Non-blocking) - For Registers

Used in `always @(posedge clk)` blocks:

```verilog
always @(posedge clk) begin
  a <= b;    // All these happen
  b <= c;    // "at the same time"
  c <= a;    // (actually: at the clock edge)
end
```

After this block, `a`, `b`, and `c` have rotated values. They all read the *old* values and write *new* values simultaneously.

### `=` (Blocking) - For Combinational Logic

Used in `always @*` blocks or `assign` statements:

```verilog
always @* begin
  temp = a + b;      // Calculate temp first
  result = temp * 2; // Then use temp
end
```

These execute in order, like normal programming.

**The rule:** Use `<=` inside `always @(posedge clk)`. Use `=` everywhere else. Mixing them causes subtle bugs.

---

## Reading a Complete Module

Here's a small module with all the patterns:

```verilog
// File header: what this does
// Button Debounce Filter

module debounce (
  input  i_Clk,           // Clock and reset first
  input  i_Switch,        // Then inputs
  output o_Stable         // Then outputs
);

  // Constants are UPPERCASE
  parameter DEBOUNCE_COUNT = 250000;

  // Registers have r_ prefix
  reg [17:0] r_Count;
  reg        r_State;

  // Sequential logic with reset
  always @(posedge i_Clk) begin
    if (i_Switch != r_State) begin
      if (r_Count < DEBOUNCE_COUNT - 1)
        r_Count <= r_Count + 1;
      else begin
        r_State <= i_Switch;
        r_Count <= 0;
      end
    end else begin
      r_Count <= 0;
    end
  end

  // Output assignment
  assign o_Stable = r_State;

endmodule
```

When you read this, the prefixes tell you:
- `i_Clk`, `i_Switch` come from outside
- `r_Count`, `r_State` are stored values
- `o_Stable` goes outside
- `DEBOUNCE_COUNT` is a fixed constant

---

## What To Do When Reviewing Claude's Code

When Claude generates Verilog, check:

1. **Are prefixes consistent?** All inputs should have `i_`, outputs `o_`, registers `r_`, wires `w_`

2. **Is there a reset?** Every `always @(posedge clk)` block should reset all its registers

3. **Are assignments correct?** `<=` in clocked blocks, `=` in combinational blocks

4. **Are constants named?** No magic numbers - values should have `UPPERCASE` names

5. **Does the case have a default?** Every `case` statement needs a `default` to prevent latches

If something looks inconsistent, ask Claude to fix it. The patterns exist to catch bugs before they happen.

---

## Summary

| When you see... | It means... |
|-----------------|-------------|
| `i_Something` | Input port (from outside) |
| `o_Something` | Output port (to outside) |
| `r_Something` | Register (stores a value) |
| `w_Something` | Wire (just a connection) |
| `UPPERCASE` | Constant (never changes) |
| `S_SOMETHING` | State machine state |
| `<=` | Non-blocking (for registers) |
| `=` | Blocking (for combinational) |

You don't need to memorize this. Refer back when you're reading code and something isn't clear. Over time, these patterns will become automatic.
