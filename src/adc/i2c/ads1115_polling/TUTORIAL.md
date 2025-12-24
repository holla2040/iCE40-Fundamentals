# ADS1115 I2C ADC Tutorial (Polling Version)

This project teaches I2C master implementation, open-drain I/O on iCE40, and interfacing with external ADC chips.

## What This Project Does

The ADS1115 driver:
1. Configures the ADC for continuous conversion on AIN0
2. Periodically polls the conversion register via I2C
3. Converts the 16-bit reading to hex ASCII
4. Transmits the result via UART

## Verilog Concepts Covered

- I2C master state machine
- Open-drain I/O using SB_IO primitives
- Multi-byte I2C transactions
- Hierarchical module design
- Polling-based peripheral communication

## Understanding I2C Protocol

I2C is a two-wire serial protocol with a clock line (SCL) and data line (SDA).

### Signal Characteristics

Both lines are open-drain with pull-up resistors:
- To send '1': release the line (pull-up pulls it high)
- To send '0': actively drive the line low

```
       VDD
        │
       ┌┴┐
       │ │ Pull-up (typically 4.7k)
       └┬┘
        │
   ─────┴───── SDA or SCL
        │
      ┌───┐
      │   │ Device drives low
      └───┘
```

### I2C Transaction Structure

Every I2C transaction follows this pattern:

```
START → ADDRESS + R/W → ACK → DATA → ACK → ... → STOP
```

**Start Condition**: SDA falls while SCL is high
**Stop Condition**: SDA rises while SCL is high
**Data Transfer**: SDA changes only when SCL is low; sampled when SCL is high

```
SCL:  ────┐   ┌───┐   ┌───┐   ┌───┐   ┌────
          └───┘   └───┘   └───┘   └───┘
SDA:  ──┐   ┌───────┐       ┌───────────
        └───┘ bit7  └───────┘ bit6 ...

      START   D7      D6      D5
```

## Open-Drain I/O on iCE40

The iCE40 pins are push-pull by default. For I2C, we need open-drain behavior using the SB_IO primitive:

```verilog
SB_IO #(
  .PIN_TYPE(6'b1010_01),  // Output with tristate, input registered
  .PULLUP(1'b1)           // Enable internal pull-up
) sda_io (
  .PACKAGE_PIN(io_PMOD_3),
  .OUTPUT_ENABLE(!sda_out),  // Drive low when sda_out=0
  .D_OUT_0(1'b0),            // Always output 0 when driving
  .D_IN_0(sda_in)            // Read actual pin state
);
```

Key insight: We always output 0, but control whether we're driving:
- `sda_out = 1` → `OUTPUT_ENABLE = 0` → line floats high (via pull-up)
- `sda_out = 0` → `OUTPUT_ENABLE = 1` → line driven low

## I2C Master Implementation

The I2C master in `i2c_master.v` uses a state machine with 4-phase timing per bit:

```verilog
localparam CLKS_PER_BIT = CLK_FREQ / I2C_FREQ / 4;
```

Each bit transfer has 4 phases:
- Phase 0: Set SDA (SCL low)
- Phase 1: Raise SCL
- Phase 2: Hold SCL high (sample point)
- Phase 3: Lower SCL

```
         Phase 0   Phase 1   Phase 2   Phase 3
SCL:     ─────────┐         ┌─────────┐
                  └─────────┘         └─────────
SDA:     ═══════════════════════════════════════
         setup     rise      sample    fall
```

### State Machine Overview

```
S_IDLE ──> S_START ──> S_ADDR ──> S_ADDR_ACK ──> S_WAIT_CMD
                                                      │
                ┌─────────────────────────────────────┘
                │
                ├── i_wvalid ──> S_WRITE ──> S_WRITE_ACK ──┐
                │                                          │
                ├── i_rready ──> S_READ ──> S_READ_ACK ────┤
                │                                          │
                └── i_stop ──> S_STOP ──> S_IDLE           │
                                                           │
                ┌──────────────────────────────────────────┘
                └──> S_WAIT_CMD
```

## ADS1115 Configuration

The ADS1115 has 4 registers accessed via I2C:

| Pointer | Register | Description |
|---------|----------|-------------|
| 0x00 | Conversion | 16-bit ADC result |
| 0x01 | Config | Operating mode settings |
| 0x02 | Lo_thresh | Comparator low threshold |
| 0x03 | Hi_thresh | Comparator high threshold |

### Config Register (16-bit)

```
Bit 15:    OS       - Operational status (write 1 to start conversion)
Bit 14-12: MUX      - Input multiplexer (100 = AIN0 vs GND)
Bit 11-9:  PGA      - Gain (001 = ±4.096V)
Bit 8:     MODE     - 0=continuous, 1=single-shot
Bit 7-5:   DR       - Data rate (111 = 860 SPS)
Bit 4:     COMP_MODE
Bit 3:     COMP_POL
Bit 2:     COMP_LAT
Bit 1-0:   COMP_QUE - Comparator queue (11 = disabled)
```

In code:
```verilog
localparam CONFIG_MSB = 8'hC2;  // OS=1, MUX=100, PGA=001, MODE=0
localparam CONFIG_LSB = 8'hE3;  // DR=111, COMP_QUE=11 (disabled)
```

## Writing to the ADS1115

To write to a register:

1. START
2. Send address byte (0x48 << 1 | 0) = 0x90 for write
3. Wait for ACK
4. Send register pointer (0x01 for config)
5. Wait for ACK
6. Send MSB of data
7. Wait for ACK
8. Send LSB of data
9. Wait for ACK
10. STOP

```verilog
S_WRITE_CONFIG: begin
  case (step)
    0: begin
      i2c_addr  <= ADDR;     // 0x48
      i2c_rw    <= 0;        // Write mode
      i2c_start <= 1;
      step      <= 1;
    end
    1: if (i2c_done) begin
      if (i2c_ack_recv)      // NACK = device not found
        state <= S_ERROR;
      else begin
        i2c_wdata  <= REG_CONFIG;  // 0x01
        i2c_wvalid <= 1;
        step       <= 2;
      end
    end
    // ... continue with CONFIG_MSB, CONFIG_LSB
  endcase
end
```

## Reading from the ADS1115

Reading requires a "repeated start" to switch from write (setting pointer) to read:

1. START
2. Send address + write bit
3. ACK
4. Send register pointer (0x00 for conversion)
5. ACK
6. REPEATED START (start without stop)
7. Send address + read bit
8. ACK
9. Read MSB, send ACK
10. Read LSB, send NACK (last byte)
11. STOP

The NACK after the last byte tells the slave we're done reading.

## Polling Strategy

This version polls the conversion register at a fixed interval:

```verilog
S_WAIT_POLL: begin
  // Poll every ~2.6ms (65536 clocks at 25MHz)
  if (poll_cnt == 0) begin
    poll_cnt <= 16'hFFFF;
    state    <= S_READ_START;
  end else begin
    poll_cnt <= poll_cnt - 1;
  end
end
```

At 860 SPS, the ADC produces a new sample every ~1.16ms. Polling every 2.6ms ensures we always get a fresh reading, though we miss some samples.

## Hex to ASCII Conversion

The `hex_to_ascii` module converts a 4-bit nibble to its ASCII representation:

```verilog
module hex_to_ascii (
  input  wire [3:0] i_hex,
  output reg  [7:0] o_ascii
);
  always @(*) begin
    if (i_hex < 10)
      o_ascii = 8'h30 + i_hex;        // '0' to '9'
    else
      o_ascii = 8'h41 + (i_hex - 10); // 'A' to 'F'
  end
endmodule
```

## Error Handling

The driver detects a missing device by checking the ACK after the address byte:

```verilog
if (i2c_ack_recv) begin  // NACK received
  i2c_stop <= 1;
  state    <= S_ERROR;
end
```

On error, all 4 LEDs light up and "E" is sent via UART.

## Key Takeaways

1. **I2C is open-drain**: Use SB_IO primitives for proper bidirectional signaling
2. **4-phase timing**: Each bit needs setup, rise, hold, and fall phases
3. **Repeated start**: Allows switching R/W direction without releasing the bus
4. **ACK/NACK protocol**: Receiver acknowledges each byte; NACK signals end of read
5. **Polling trade-off**: Simple but may miss samples; see interrupt version for better approach

## See Also

- `ads1115_interrupt/` - Uses ALERT pin for precise conversion timing
- `src/serial/tx/` - UART transmitter details
