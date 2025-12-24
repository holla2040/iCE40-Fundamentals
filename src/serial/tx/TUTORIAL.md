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
  input  wire       clk,
  ...
);
```

Parameters make modules reusable. The `#(...)` syntax defines parameters that can be overridden when instantiating.

- `CLK_FREQ`: System clock frequency in Hz
- `BAUD`: Bits per second for serial communication

### Calculated Constants

```verilog
localparam CLKS_PER_BIT = CLK_FREQ / BAUD;
```

`localparam` is a constant calculated at compile time. At 25 MHz with 115200 baud:
- 25,000,000 / 115,200 = 217 clock cycles per bit

This tells us how long to hold each bit.

### State Machine States

```verilog
localparam IDLE      = 3'd0;
localparam START_BIT = 3'd1;
localparam DATA_BITS = 3'd2;
localparam STOP_BIT  = 3'd3;

reg [2:0] state;
```

A **state machine** (FSM) tracks where we are in a sequence. States are encoded as numbers. The `3'd0` syntax means "3-bit decimal 0".

### The State Machine

```verilog
always @(posedge clk) begin
  if (rst) begin
    // Reset all registers
  end else begin
    case (state)
      IDLE: begin
        // Wait for tx_start
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
    endcase
  end
end
```

The `case` statement selects behavior based on current state. Each state:
1. Does its job (drive output, count clocks)
2. Decides when to move to the next state

### Shift Register for Data

```verilog
tx_out <= tx_shift[0];  // Output LSB
tx_shift <= tx_shift >> 1;  // Shift right
```

A shift register moves bits through a register:
- `tx_shift[0]` gets the least significant bit
- `>> 1` shifts all bits right, bringing in 0 from the left
- After 8 shifts, all original bits have been sent

### Bit Timing

```verilog
if (clk_count < CLKS_PER_BIT - 1) begin
  clk_count <= clk_count + 1;
end else begin
  clk_count <= 0;
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
  .clk(i_Clk),
  .rst(rst),
  .tx_data(tx_data),
  .tx_start(tx_start),
  .tx_out(o_UART_TX),
  .tx_busy(tx_busy)
);
```

This creates an instance of `uart_tx` named `uart_inst`:
- `#(...)` overrides default parameters
- `.port(signal)` connects module ports to local signals
- The UART module handles the protocol; top module handles the message

### Reset Generation

```verilog
reg [3:0] rst_count = 4'hF;
wire rst = rst_count != 0;
always @(posedge i_Clk) begin
  if (rst_count != 0)
    rst_count <= rst_count - 1;
end
```

FPGAs don't have a reset button by default. This creates a "power-on reset":
- Counter starts at 15 (4'hF)
- Counts down to 0 over 15 clock cycles
- `rst` is high while counting, then goes low forever

### Handshake Protocol

```verilog
SEND_CHAR: begin
  if (!tx_busy) begin    // Wait until UART is ready
    tx_start <= 1;       // Pulse start signal
    state <= WAIT_DONE;
  end
end

WAIT_DONE: begin
  if (tx_busy) begin
    // Transmission in progress
  end else if (!tx_start) begin
    // Done, move to next character
  end
end
```

The top module and UART module communicate via handshake signals:
1. Top checks `tx_busy` is low (UART ready)
2. Top pulses `tx_start` high
3. UART sets `tx_busy` high and begins transmitting
4. Top waits for `tx_busy` to go low (transmission complete)
5. Repeat for next byte

## Key Takeaways

- **Parameters** make modules reusable with different configurations
- **State machines** sequence complex operations step by step
- **Shift registers** convert parallel data to serial (or vice versa)
- **Handshake signals** coordinate between modules
- **Hierarchical design**: top module orchestrates, sub-modules implement details
- **Baud timing**: count clock cycles to hold each bit for the right duration
