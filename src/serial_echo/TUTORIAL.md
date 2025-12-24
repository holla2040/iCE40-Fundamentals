# Serial Echo - Verilog Tutorial

## What This Project Does

Echoes characters received over USB serial back to the sender with swapped case. Type `Hello` and see `hELLO`. This combines the uart_rx and uart_tx modules into a bidirectional system.

## Verilog Concepts Covered

- Module reuse
- Multi-module instantiation
- Data flow between modules
- Simple buffering
- Combinational data transformation

## Why Echo Needs a State Machine

You might think echo is simple: receive a byte, send it back. But there's a timing issue:

```
RX:  ──────┐ rx_valid (1 cycle pulse)
           └──────────────────────

TX:        ┌─────────────────────┐
           │      tx_busy        │
           └─────────────────────┘
```

- `rx_valid` pulses for only one clock cycle
- The TX module might be busy from a previous byte
- We need to capture and hold the received byte until TX is ready

## Code Walkthrough

### Module Instantiation

```verilog
uart_rx #(
  .CLK_FREQ(25_000_000),
  .BAUD(115200)
) rx_inst (
  .clk(i_Clk),
  .rst(rst),
  .rx_in(i_UART_RX),
  .rx_data(rx_data),
  .rx_valid(rx_valid)
);

uart_tx #(
  .CLK_FREQ(25_000_000),
  .BAUD(115200)
) tx_inst (
  .clk(i_Clk),
  .rst(rst),
  .tx_data(tx_data),
  .tx_start(tx_start),
  .tx_out(o_UART_TX),
  .tx_busy(tx_busy)
);
```

Both modules are instantiated with:
- Same clock and reset (shared infrastructure)
- Same baud rate parameters
- Different instance names (`rx_inst`, `tx_inst`)
- Connected to their respective pins and internal signals

### Case Swap Conversion

```verilog
wire is_lower = (rx_data >= "a") && (rx_data <= "z");
wire is_upper = (rx_data >= "A") && (rx_data <= "Z");
wire [7:0] rx_swapped = is_lower ? (rx_data - 8'h20) :
                        is_upper ? (rx_data + 8'h20) : rx_data;
```

This is **combinational logic** - no clock, just wires:

- `is_lower` is true if the character is 'a' through 'z'
- `is_upper` is true if the character is 'A' through 'Z'
- In ASCII, lowercase letters are 0x61-0x7A, uppercase are 0x41-0x5A
- The difference is 0x20 (32 decimal)
- Nested ternary operators select: lowercase→subtract, uppercase→add, else→passthrough

The conversion happens instantly - `rx_swapped` always reflects the case-swapped version of `rx_data`.

### Data Flow

```
             ┌─────────┐         ┌───────────┐
i_UART_RX ──▶│ uart_rx │──▶ rx_data ──▶ UPPER ──┐
             └─────────┘         └───────────┘  │
                                   rx_valid     │
                                                ▼
                                      ┌──────────────┐
                                      │ Echo State   │
                                      │   Machine    │
                                      └──────────────┘
                                              │
             ┌─────────┐       tx_data        │
o_UART_TX ◀──│ uart_tx │◀───── tx_start ◀─────┘
             └─────────┘
```

The top module coordinates:
1. RX module receives bytes independently
2. State machine captures `rx_data` when `rx_valid` pulses
3. State machine waits for TX to be ready (`!tx_busy`)
4. State machine starts transmission

### Echo State Machine

```verilog
localparam IDLE    = 2'd0;
localparam WAIT_TX = 2'd1;
localparam SENDING = 2'd2;

reg [1:0] state = IDLE;
reg [7:0] echo_data;
```

Three states handle the timing:

**IDLE** - Waiting for data
```verilog
IDLE: begin
  if (rx_valid) begin
    echo_data <= rx_upper;  // Capture uppercase version
    state     <= WAIT_TX;
  end
end
```

When `rx_valid` pulses, we capture `rx_upper` (the uppercase version) into `echo_data`. This is critical - `rx_data` is only valid for one cycle.

**WAIT_TX** - Waiting for transmitter
```verilog
WAIT_TX: begin
  if (!tx_busy) begin
    tx_data  <= echo_data;
    tx_start <= 1;
    state    <= SENDING;
  end
end
```

We wait until the transmitter is free, then start transmission. If we didn't have this state, we might try to transmit while TX is still busy from a previous byte.

**SENDING** - Waiting for transmission to complete
```verilog
SENDING: begin
  if (tx_busy) begin
    // TX started, wait for completion
  end else begin
    state <= IDLE;
  end
end
```

We wait for `tx_busy` to go high (transmission started), then wait for it to go low (transmission complete). Then we return to IDLE, ready for the next byte.

### The Capture Buffer

```verilog
reg [7:0] echo_data;
```

This single register is our buffer. It holds the received byte while we wait for TX. Without it:

```
// BAD - race condition
if (rx_valid && !tx_busy) begin
  tx_data  <= rx_data;   // rx_data might change!
  tx_start <= 1;
end
```

The problem: by the time TX finishes and we try to send another byte, `rx_data` has already changed (or become invalid).

### Why Not a FIFO?

For simple echo, a single register works. But if bytes arrive faster than we can send them (impossible at same baud rate, but consider different rates), we'd drop bytes.

A more robust design would use a FIFO (First-In-First-Out buffer):

```
RX ──▶ [FIFO] ──▶ TX
```

This is left as an exercise - the concepts are the same, just with a deeper buffer.

## Module Reuse

Notice we didn't modify uart_rx.v or uart_tx.v at all. They're generic, reusable modules:

| Module | Inputs | Outputs | Purpose |
|--------|--------|---------|---------|
| uart_rx | rx_in | rx_data, rx_valid | Receive bytes |
| uart_tx | tx_data, tx_start | tx_out, tx_busy | Transmit bytes |

The top module just wires them together with glue logic. This is **hierarchical design** - build small, tested modules, then compose them.

### Backspace Handling

When the user presses backspace, the terminal (with local echo) already moves the cursor left. We need to overwrite the previous character and move back. We send two characters: Space (overwrite), BS (move back).

```verilog
wire is_backspace = (rx_data == 8'h08) || (rx_data == 8'h7F);

SEND_BS: begin
  if (!tx_busy) begin
    tx_data  <= bs_step ? 8'h08 : 8'h20;  // 0=Space, 1=BS
    tx_start <= 1;
    if (bs_step)
      state <= SENDING;
    else
      bs_step <= 1;
  end
end
```

The `bs_step` flag tracks which character we're sending. We check for both 0x08 (BS) and 0x7F (DEL) since terminals vary.

### CR to CR+LF Conversion

Terminals send only CR (carriage return, 0x0D) when you press Enter. To move to a new line, we need to send both CR and LF (line feed, 0x0A).

```verilog
need_lf <= (rx_data == 8'h0D);  // Flag if CR received
```

The state machine checks this flag after sending a character:

```verilog
SENDING: begin
  if (!tx_busy) begin
    if (need_lf)
      state <= SEND_LF;   // Go send LF
    else
      state <= IDLE;      // Done
  end
end

SEND_LF: begin
  if (!tx_busy) begin
    tx_data  <= 8'h0A;    // LF
    tx_start <= 1;
    need_lf  <= 0;
    state    <= SENDING;  // Wait for LF to finish
  end
end
```

This pattern - using a flag to conditionally send extra characters - is common for protocol conversions.

## Key Takeaways

- **Module reuse**: Same uart_rx/uart_tx modules work in different projects
- **Combinational transformation**: Use wires and ternary operators for instant data conversion
- **Capture immediately**: When data is valid for one cycle, save it right away
- **Coordinate with handshakes**: Check `tx_busy` before starting new transmission
- **Buffer data**: Hold received data until the transmitter is ready
- **State machines coordinate**: Even simple tasks need sequencing when timing matters
- **Hierarchical design**: Build small modules, compose them into larger systems
- **Protocol conversion**: Use flags and counters to trigger multi-character sequences
