# Frequency Counter Tutorial

This project teaches frequency measurement using a gated counter, decimal conversion without division, and multi-byte UART transmission.

## What This Project Does

The frequency counter:
1. Counts rising edges of an input signal over exactly 1 second
2. Converts the count to decimal ASCII digits
3. Transmits the result as "12345 Hz\r\n" via UART

## Verilog Concepts Covered

- Gated counting (measurement windows)
- Input synchronization (metastability prevention)
- Edge detection
- Binary to decimal conversion (without division)
- Multi-state UART transmission
- Leading zero suppression

## How Frequency Measurement Works

### The Gate Principle

Frequency is "events per second." To measure it:
1. Open a "gate" for exactly 1 second
2. Count how many rising edges occur
3. Close the gate and report the count

```
         1 second gate
    |<----------------->|
    ┌───────────────────┐
Gate│                   │
    └───────────────────┘

Input ___┌─┐_┌─┐_┌─┐_┌─┐_┌─┐___
         1   2   3   4   5

Result: 5 Hz
```

### Implementation in freq_counter.v

```verilog
localparam GATE_CYCLES = CLK_FREQ - 1;  // 24,999,999 for 25 MHz

always @(posedge clk) begin
  if (gate_done) begin
    // Gate complete - save count and restart
    count_out  <= freq_count;
    count_valid <= 1'b1;
    freq_count <= rising_edge ? 32'd1 : 32'd0;
    gate_timer <= 0;
  end else begin
    // Continue counting
    gate_timer <= gate_timer + 1;
    if (rising_edge)
      freq_count <= freq_count + 1;
  end
end
```

Key points:
- `gate_timer` counts from 0 to 24,999,999 (1 second at 25 MHz)
- `freq_count` increments on each rising edge during the gate
- When gate completes, we save the count and restart immediately

## Why Input Synchronization Matters

External signals are asynchronous to the FPGA clock. Without synchronization, the signal could change during a clock edge, causing **metastability** - where a flip-flop gets stuck in an undefined state.

### The 2-Flip-Flop Synchronizer

```verilog
reg [1:0] sync_ff;
wire freq_sync = sync_ff[1];

always @(posedge clk) begin
  sync_ff <= {sync_ff[0], freq_in};
end
```

```
            ┌─────┐     ┌─────┐
freq_in ───>│ FF0 │────>│ FF1 │───> freq_sync
            └─────┘     └─────┘
              │           │
              clk         clk
```

The first flip-flop may go metastable, but it has one full clock cycle to settle before FF1 samples it. This reduces metastability probability to negligible levels.

## Edge Detection

To count frequency, we need to detect rising edges (not just high levels):

```verilog
reg freq_prev;
wire rising_edge = freq_sync && !freq_prev;

always @(posedge clk) begin
  freq_prev <= freq_sync;
end
```

```
freq_sync:   ___┌───────────┐___
freq_prev:   _____┌───────────┐_  (delayed 1 clock)
rising_edge: ___┌─┐_____________  (pulse for 1 clock)
```

## Binary to Decimal Without Division

FPGAs don't have efficient division hardware. Converting binary to decimal digits normally requires dividing by 10 repeatedly. Instead, we use **repeated subtraction**.

### The Algorithm

To extract the digit for position N (where N represents 10^N):
1. Subtract 10^N from the value while it's >= 10^N
2. Count how many times we subtracted
3. That count is the digit

Example: Converting 12345 to decimal

```
Position 4 (10000s): 12345 - 10000 = 2345, digit = 1
Position 3 (1000s):  2345 - 1000 = 1345, again: 345, digit = 2
Position 2 (100s):   345 - 100 = 245, 145, 45, digit = 3
Position 1 (10s):    45 - 10 = 35, 25, 15, 5, digit = 4
Position 0 (1s):     5 - 1 = 4, 3, 2, 1, 0, digit = 5
```

### Implementation

```verilog
// Powers of 10 lookup table
always @(*) begin
  case (digit_pos)
    4'd0: current_power = 32'd10_000_000;
    4'd1: current_power = 32'd1_000_000;
    // ... etc
  endcase
end

// Subtraction loop (one subtraction per clock)
ST_SUBTRACT: begin
  if (work_val >= current_power) begin
    work_val  <= work_val - current_power;
    digit_val <= digit_val + 1;
  end else begin
    // Done with this digit
    if (digit_val != 0 || !leading_zero) begin
      digits[num_digits] <= 8'h30 + digit_val;  // ASCII '0' + digit
      num_digits <= num_digits + 1;
      leading_zero <= 1'b0;
    end
    state <= ST_NEXT_POS;
  end
end
```

### Leading Zero Suppression

We don't want to output "00012345 Hz" - we want "12345 Hz". The `leading_zero` flag tracks whether we've seen a non-zero digit yet:

- If `leading_zero` is true and digit is 0, skip storing it
- Once we store any digit, set `leading_zero` to false
- Special case: if all digits are 0, store a single "0"

## Multi-Byte UART Transmission

Sending multiple characters requires careful handshaking with the UART module.

### The TX Wait Pattern

```verilog
ST_TX_DIGIT: begin
  if (!tx_busy && !tx_start) begin     // Wait for TX ready
    tx_data  <= digits[digit_idx];      // Load character
    tx_start <= 1'b1;                   // Start transmission
    state    <= ST_TX_WAIT;             // Wait for completion
  end
end

ST_TX_WAIT: begin
  if (tx_busy) begin
    // TX is active, wait
  end else if (!tx_start) begin
    // TX complete, continue
    state <= next_state;
  end
end
```

### State Flow

```
ST_IDLE ──> ST_SUBTRACT ──> ST_NEXT_POS ──> ST_TX_DIGIT
                                                │
    ┌───────────────────────────────────────────┘
    │
    └──> ST_TX_SPACE ──> ST_TX_H ──> ST_TX_z ──> ST_TX_CR ──> ST_TX_LF ──> ST_IDLE
```

Each TX state follows the same pattern:
1. Wait for `!tx_busy && !tx_start`
2. Load character into `tx_data`
3. Pulse `tx_start`
4. Go to `ST_TX_WAIT`
5. When complete, go to next state

## Timing Analysis

At 115200 baud, each character takes ~87 microseconds to transmit.

For a 8-digit number + " Hz\r\n" (12 characters total):
- Transmission time: 12 * 87 = ~1.04 ms

For conversion of an 8-digit number:
- Worst case: 9 subtractions per digit * 8 positions = 72 clocks
- At 25 MHz: 72 * 40ns = 2.88 microseconds

Total processing time is well under the 1-second measurement window.

## Key Takeaways

1. **Gated counting** measures frequency by counting edges in a fixed time window
2. **2-FF synchronizers** prevent metastability when sampling asynchronous signals
3. **Repeated subtraction** converts binary to decimal without expensive division
4. **State machines** coordinate multi-step operations like digit conversion and UART transmission
5. **Handshaking** (checking busy/ready signals) prevents data loss in serial communication
