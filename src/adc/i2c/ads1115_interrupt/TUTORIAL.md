# ADS1115 I2C ADC Tutorial (Interrupt Version)

This project extends the polling version by using the ALERT/RDY pin to trigger reads exactly when new data is available, achieving maximum sample rate.

## What This Project Does

The ADS1115 driver:
1. Configures the ADC for continuous conversion on AIN0
2. Configures the comparator to assert ALERT on every conversion
3. Waits for ALERT falling edge (new data ready)
4. Reads the conversion register via I2C
5. Transmits the result via UART

## Verilog Concepts Covered

- Edge detection on external signals
- Using comparator thresholds for data-ready signaling
- Event-driven vs polling design
- Additional I2C register configuration

## Polling vs Interrupt: Why It Matters

The polling version reads the ADC at fixed intervals:

```
Poll  ─────┬─────────────┬─────────────┬─────────
           │             │             │
ADC   ──┬──┴──┬──┬──┬──┬─┴─┬──┬──┬──┬─┴─┬──┬──
        │     │  │  │  │   │  │  │  │   │  │
        └─────┴──┴──┴──┴───┴──┴──┴──┴───┴──┴──
        Missed samples        ↑ Read happens to align
```

The interrupt version reads exactly when data is ready:

```
ALERT ────┐    ┌────┐    ┌────┐    ┌────
          └────┘    └────┘    └────┘
              ↓         ↓         ↓
Read    ──────┴─────────┴─────────┴─────
              Every sample captured
```

## The ALERT/RDY Pin Trick

The ADS1115's comparator normally compares ADC readings against thresholds. But we can configure it to pulse on every conversion:

**The trick**: Set thresholds so the condition is always true:
- Hi_thresh = 0x8000 (most negative in two's complement)
- Lo_thresh = 0x7FFF (most positive in two's complement)

Since every ADC reading is either:
- >= 0x8000 (negative) → above Hi_thresh
- <= 0x7FFF (positive) → below Lo_thresh

...the comparator always triggers, pulsing ALERT on each new sample.

```verilog
// Threshold values for "always trigger" mode
localparam HI_THRESH_MSB = 8'h80;
localparam HI_THRESH_LSB = 8'h00;
localparam LO_THRESH_MSB = 8'h7F;
localparam LO_THRESH_LSB = 8'hFF;
```

## Config Register Differences

The config register differs from the polling version:

```verilog
// Polling version: COMP_QUE=11 (comparator disabled)
localparam CONFIG_LSB = 8'hE3;

// Interrupt version: COMP_QUE=00 (comparator enabled, assert after 1 conversion)
localparam CONFIG_LSB = 8'hE0;
```

The COMP_QUE field controls how many consecutive threshold crossings trigger ALERT:
- 00 = 1 conversion
- 01 = 2 conversions
- 10 = 4 conversions
- 11 = Disabled

## Additional Register Writes

The interrupt version writes three registers at startup (vs one for polling):

1. **Config register** (0x01) - same as polling, but with comparator enabled
2. **Lo_thresh register** (0x02) - set to 0x7FFF
3. **Hi_thresh register** (0x03) - set to 0x8000

```verilog
// State progression
S_INIT ──> S_WRITE_CONFIG ──> S_WRITE_LO ──> S_WRITE_HI ──> S_WAIT_ALERT
```

Each register write is a complete I2C transaction:
```
START → ADDR+W → ACK → REG_PTR → ACK → MSB → ACK → LSB → ACK → STOP
```

## Edge Detection

The driver watches for a falling edge on the ALERT pin:

```verilog
reg r_alert_prev;

always @(posedge i_clk) begin
  r_alert_prev <= i_alert;

  // ...

  S_WAIT_ALERT: begin
    // Falling edge: r_alert_prev=1 and i_alert=0
    if (r_alert_prev && !i_alert) begin
      r_state <= S_READ_START;
    end
  end
end
```

This is a standard edge detection pattern:
```
i_alert:       ────┐     ┌────
                   └─────┘
r_alert_prev:  ─────┐    ┌────  (delayed 1 clock)
                    └────┘
Falling edge:  ───┐────────     (1 clock pulse)
                  └
```

Note the naming: `r_alert_prev` is a register (stores previous value), `i_alert` is an input port.

## Timing Analysis

At 860 SPS, a new conversion is ready every 1.16 ms.

Each read transaction takes approximately:
- Start: 4 bit-times
- Address+W: 9 bit-times (8 data + 1 ACK)
- Register pointer: 9 bit-times
- Repeated start: 4 bit-times
- Address+R: 9 bit-times
- Read MSB: 9 bit-times
- Read LSB: 9 bit-times
- Stop: 4 bit-times

Total: ~57 bit-times × 10µs (at 100kHz I2C) = 570µs

This leaves plenty of margin within the 1.16ms conversion period.

## UART Bandwidth

At 860 SPS with output format "XXXX\r\n" (6 characters):
- 860 × 6 = 5160 characters/second
- At 115200 baud (11520 chars/sec max), we have ~55% utilization

This is sustainable with margin to spare.

## Module Hierarchy

```
ads1115_top
├── SB_IO (sda_io) - Open-drain SDA
├── SB_IO (scl_io) - Open-drain SCL
├── ads1115
│   └── i2c_master - Handles all I2C signaling
├── uart_tx - Serial output
└── hex_to_ascii (×4) - Binary to hex conversion
```

## Comparison with Polling Version

| Aspect | Polling | Interrupt |
|--------|---------|-----------|
| Wires | 4 (VDD, GND, SCL, SDA) | 5 (+ ALERT) |
| Sample rate | ~380 SPS (limited by poll interval) | 860 SPS (full speed) |
| Timing | Fixed interval | Event-driven |
| Complexity | Simpler | Slightly more complex |
| CPU usage | Constant polling | Only on events |

## When to Use Each Version

**Use Polling when:**
- You want simpler wiring
- Lower sample rates are acceptable
- The ADC is the only I2C device (no bus contention concerns)

**Use Interrupt when:**
- You need maximum sample rate
- Precise timing matters (e.g., audio sampling)
- Multiple I2C devices share the bus
- You want to minimize unnecessary bus traffic

## Key Takeaways

1. **Threshold trick**: Setting impossible thresholds makes the comparator fire on every sample
2. **Edge detection**: Use a registered copy of the signal to detect transitions
3. **Event-driven design**: React to external signals rather than polling at fixed intervals
4. **Same I2C core**: The i2c_master module is identical; only the driver logic changes

## See Also

- `ads1115_polling/` - Simpler version without ALERT pin
- `src/serial/tx/` - UART transmitter details
- `docs/ads1115.pdf` - Full ADS1115 datasheet
