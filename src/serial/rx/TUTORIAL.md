# Serial RX - Verilog Tutorial

## What This Project Does

Receives characters over USB serial and controls an LED. Send '0' to turn off LED 1, '1' to turn it on. Demonstrates UART reception, input synchronization, and mid-bit sampling.

## Verilog Concepts Covered

- Input synchronization (metastability)
- Mid-bit sampling
- Receive shift registers
- Edge detection
- Data validation

## Why Receiving is Different from Transmitting

When transmitting, we control the timing. When receiving, we must:
1. Detect when a byte starts (start bit)
2. Sample at the right moment (middle of each bit)
3. Handle the fact that the input is asynchronous to our clock

## Code Walkthrough: uart_rx.v

### Input Synchronization

```verilog
reg [1:0] r_rx_sync;
always @(posedge i_clk) begin
  r_rx_sync <= {r_rx_sync[0], i_rx_in};
end
wire w_rx_bit = r_rx_sync[1];
```

This is critical for reliability. The external `i_rx_in` signal can change at any time, not synchronized to our clock. This causes **metastability** - the flip-flop might enter an undefined state.

The solution is a **synchronizer chain**:
1. `i_rx_in` feeds into `r_rx_sync[0]` (might be metastable)
2. `r_rx_sync[0]` feeds into `r_rx_sync[1]` (stable)
3. We only use `r_rx_sync[1]` (called `w_rx_bit`)

The `{r_rx_sync[0], i_rx_in}` syntax concatenates bits: the new value shifts in from the right.

Note the naming conventions: `r_` for registers, `w_` for wires, `i_` for inputs.

### Detecting the Start Bit

```verilog
IDLE: begin
  if (w_rx_bit == 0) begin
    r_state <= START_BIT;
  end
end
```

UART idles high. When we see a low (0), it might be a start bit. But we need to verify it's not just noise.

### Mid-Bit Sampling

```verilog
START_BIT: begin
  if (r_clk_count < (CLKS_PER_BIT - 1) / 2) begin
    r_clk_count <= r_clk_count + 1;
  end else begin
    r_clk_count <= 0;
    if (w_rx_bit == 0) begin  // Still low = valid start bit
      r_state <= DATA_BITS;
    end else begin
      r_state <= IDLE;        // Was just noise
    end
  end
end
```

Why sample in the middle? Look at the timing:

```
         ┌─────────────────┐
Signal:  │                 │
    ─────┘                 └─────
         ^        ^        ^
         │        │        │
       Edge    Middle    Edge
       (risky)  (safe)  (risky)
```

Sampling at edges is risky - the signal might be changing. The middle is the most stable point.

We wait half a bit time (`CLKS_PER_BIT / 2`), then verify the line is still low. This:
1. Confirms it's a real start bit (not noise)
2. Positions us in the middle for subsequent bits

### Receive Shift Register

```verilog
DATA_BITS: begin
  if (r_clk_count < CLKS_PER_BIT - 1) begin
    r_clk_count <= r_clk_count + 1;
  end else begin
    r_clk_count <= 0;
    r_rx_shift <= {w_rx_bit, r_rx_shift[7:1]};  // Shift in from left

    if (r_bit_index < 7) begin
      r_bit_index <= r_bit_index + 1;
    end else begin
      r_state <= STOP_BIT;
    end
  end
end
```

The receive shift register works opposite to transmit:

**Transmit**: shift right, output LSB
```
[7][6][5][4][3][2][1][0] → output
          └──────────┘
           shift right
```

**Receive**: shift right, input to MSB position
```
input → [7][6][5][4][3][2][1][0]
         └──────────┘
          shift right
```

The syntax `{w_rx_bit, r_rx_shift[7:1]}` means:
- Take `w_rx_bit` (1 bit)
- Concatenate with bits 7 down to 1 of `r_rx_shift` (7 bits)
- Result: new bit in position 7, old bits shifted right

After 8 bits, the byte is assembled correctly (LSB in position 0).

### Validating the Stop Bit

```verilog
STOP_BIT: begin
  if (r_clk_count < CLKS_PER_BIT - 1) begin
    r_clk_count <= r_clk_count + 1;
  end else begin
    if (w_rx_bit == 1) begin      // Stop bit should be high
      o_rx_data  <= r_rx_shift;   // Output the received byte
      o_rx_valid <= 1;            // Signal valid data
    end
    r_state <= IDLE;
  end
end
```

We only output data if the stop bit is correct (high). This catches framing errors - if the stop bit is low, something went wrong and we discard the byte.

## Code Walkthrough: serial_rx_top.v

### Simple Data Processing

```verilog
always @(posedge i_Clk) begin
  if (w_rst) begin
    o_LED_1 <= 0;
  end else if (w_rx_valid) begin
    if (w_rx_data == "0")
      o_LED_1 <= 0;
    else if (w_rx_data == "1")
      o_LED_1 <= 1;
  end
end
```

- `w_rx_valid` pulses high for one clock cycle when a byte is received
- We check the byte value and update the LED accordingly
- `"0"` and `"1"` are ASCII characters (48 and 49 in decimal)
- Other characters are ignored (LED keeps its current state)

### Output as Register

```verilog
output reg o_LED_1
```

Notice `o_LED_1` is declared as `reg` not `wire`. This is because we assign to it in an `always` block. Outputs driven by sequential logic must be registers.

## Key Takeaways

- **Synchronize external inputs** with a 2-flip-flop chain to prevent metastability
- **Sample in the middle** of each bit for reliable reception
- **Verify the start bit** after half a bit time to reject noise
- **Receive shift register** shifts in from MSB position (opposite of transmit)
- **Validate stop bit** to detect framing errors
- **rx_valid pulses** for one clock - use it as an enable signal
