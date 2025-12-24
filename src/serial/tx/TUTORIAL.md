# Serial TX - Verilog Tutorial

## What This Project Does

Sends "Hello from FPGA!" over USB serial every second. Demonstrates UART transmission, state machines, and hierarchical module design.

## Verilog Concepts Covered

- Parameters and localparams
- State machines (FSM)
- Module instantiation
- Shift registers
- Memory arrays
- Initial blocks
- Handshake signals

## UART Protocol Basics

UART (Universal Asynchronous Receiver/Transmitter) sends data one bit at a time:

```
Idle ──┐     ┌─┬─┬─┬─┬─┬─┬─┬─┐     ┌── Idle
       │     │0│1│2│3│4│5│6│7│     │
       └─────┴─┴─┴─┴─┴─┴─┴─┴─┴─────┘
       Start  Data bits (LSB first)  Stop
       bit                           bit
```

- **Idle**: Line stays high (1)
- **Start bit**: Goes low (0) to signal start
- **Data bits**: 8 bits, least significant bit first
- **Stop bit**: Goes high (1) to signal end

## Code Walkthrough: uart_tx.v

### Parameterized Module

```verilog
module uart_tx #(
  parameter CLK_FREQ = 12_000_000,
  parameter BAUD     = 115200
)(
  input  wire       i_clk,
  input  wire       i_rst,
  input  wire [7:0] i_tx_data,
  input  wire       i_tx_start,
  output reg        o_tx_out,
  output reg        o_tx_busy
);
```

Parameters make modules reusable. The `#(...)` syntax defines parameters that can be overridden when instantiating.

- `CLK_FREQ`: System clock frequency in Hz
- `BAUD`: Bits per second for serial communication
- Note the `i_`/`o_` prefixes on ports per project style guide

### Calculated Constants

```verilog
localparam CLKS_PER_BIT = CLK_FREQ / BAUD;
```

`localparam` is a constant calculated at compile time. At 25 MHz with 115200 baud:
- 25,000,000 / 115,200 = 217 clock cycles per bit

This tells us how long to hold each bit.

### State Machine States

```verilog
localparam IDLE      = 2'd0;
localparam START_BIT = 2'd1;
localparam DATA_BITS = 2'd2;
localparam STOP_BIT  = 2'd3;

reg [1:0] r_state;
```

A **state machine** (FSM) tracks where we are in a sequence. States are encoded as numbers. The `2'd0` syntax means "2-bit decimal 0". Note the `r_` prefix indicating this is a register.

### The State Machine

```verilog
always @(posedge i_clk) begin
  if (i_rst) begin
    // Reset all registers
  end else begin
    case (r_state)
      IDLE: begin
        // Wait for i_tx_start
      end
      START_BIT: begin
        // Send start bit (low)
      end
      DATA_BITS: begin
        // Send 8 data bits
      end
      STOP_BIT: begin
        // Send stop bit (high)
      end
      default: r_state <= IDLE;
    endcase
  end
end
```

The `case` statement selects behavior based on current state. Each state:
1. Does its job (drive output, count clocks)
2. Decides when to move to the next state

Note: Always include a `default` clause in case statements.

### Shift Register for Data

```verilog
o_tx_out <= r_tx_shift[0];  // Output LSB
r_tx_shift <= r_tx_shift >> 1;  // Shift right
```

A shift register moves bits through a register:
- `r_tx_shift[0]` gets the least significant bit
- `>> 1` shifts all bits right, bringing in 0 from the left
- After 8 shifts, all original bits have been sent

### Bit Timing

```verilog
if (r_clk_count < CLKS_PER_BIT - 1) begin
  r_clk_count <= r_clk_count + 1;
end else begin
  r_clk_count <= 0;
  // Move to next bit
end
```

Each bit must be held for exactly `CLKS_PER_BIT` clock cycles to maintain correct baud rate.

## Code Walkthrough: serial_top.v

### Memory Array for Message

```verilog
reg [7:0] message [0:15];
initial begin
  message[0] = "H";
  message[1] = "e";
  ...
end
```

- `reg [7:0] message [0:15]` declares an array of 16 bytes
- `initial` blocks run once at startup (synthesis tools convert this to initial values)
- Characters like `"H"` are converted to ASCII (72)

### Module Instantiation

```verilog
uart_tx #(
  .CLK_FREQ(25_000_000),
  .BAUD(115200)
) uart_inst (
  .i_clk(i_Clk),
  .i_rst(w_rst),
  .i_tx_data(r_tx_data),
  .i_tx_start(r_tx_start),
  .o_tx_out(o_UART_TX),
  .o_tx_busy(w_tx_busy)
);
```

This creates an instance of `uart_tx` named `uart_inst`:
- `#(...)` overrides default parameters
- `.port(signal)` connects module ports to local signals
- The UART module handles the protocol; top module handles the message
- Note port naming: `i_` for inputs, `o_` for outputs

### Reset Generation

```verilog
reg [3:0] r_rst_count = 4'hF;
wire w_rst = r_rst_count != 0;
always @(posedge i_Clk) begin
  if (r_rst_count != 0)
    r_rst_count <= r_rst_count - 1;
end
```

FPGAs don't have a reset button by default. This creates a "power-on reset":
- Counter starts at 15 (4'hF)
- Counts down to 0 over 15 clock cycles
- `w_rst` is high while counting, then goes low forever

### Handshake Protocol

```verilog
SEND_CHAR: begin
  if (!w_tx_busy) begin    // Wait until UART is ready
    r_tx_start <= 1;       // Pulse start signal
    r_state <= WAIT_DONE;
  end
end

WAIT_DONE: begin
  if (w_tx_busy) begin
    // Transmission in progress
  end else if (!r_tx_start) begin
    // Done, move to next character
  end
end
```

The top module and UART module communicate via handshake signals:
1. Top checks `w_tx_busy` is low (UART ready)
2. Top pulses `r_tx_start` high
3. UART sets `o_tx_busy` high and begins transmitting
4. Top waits for `w_tx_busy` to go low (transmission complete)
5. Repeat for next byte

## Key Takeaways

- **Parameters** make modules reusable with different configurations
- **State machines** sequence complex operations step by step
- **Shift registers** convert parallel data to serial (or vice versa)
- **Handshake signals** coordinate between modules
- **Hierarchical design**: top module orchestrates, sub-modules implement details
- **Baud timing**: count clock cycles to hold each bit for the right duration
