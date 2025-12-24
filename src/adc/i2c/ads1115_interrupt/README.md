# ADS1115 I2C ADC (Interrupt Version)

Reads a 16-bit ADC value from an ADS1115 over I2C using the ALERT/RDY pin and outputs readings via UART.

## Hardware

- **ADC**: ADS1115 16-bit I2C ADC
- **Mode**: Continuous conversion, AIN0 single-ended
- **Speed**: 860 samples per second (maximum rate)
- **Gain**: 1 (±4.096V full-scale range)
- **UART**: 115200 baud, 8N1

## Wiring

| ADS1115 Pin | Go Board Pin | Description |
|-------------|--------------|-------------|
| VDD         | 3.3V         | Power       |
| GND         | GND          | Ground      |
| SCL         | PMOD 4 (62)  | I2C Clock   |
| SDA         | PMOD 3 (63)  | I2C Data    |
| ADDR        | PMOD 2 (64)  | Address (directly from FPGA) |
| ALERT/RDY   | PMOD 1 (65)  | Data Ready  |
| A0          | Input signal | ADC input   |

Note: ALERT/RDY requires external pull-up resistor (typically 10k to VDD).

## Pin Table

| Signal      | Pin | Direction | Description           |
|-------------|-----|-----------|----------------------|
| i_Clk       | 15  | Input     | 25 MHz clock         |
| io_I2C_SCL  | 62  | Bidir     | I2C clock            |
| io_I2C_SDA  | 63  | Bidir     | I2C data             |
| o_ADDR      | 64  | Output    | ADS1115 address pin  |
| i_ALERT     | 65  | Input     | Conversion ready     |
| o_UART_TX   | 74  | Output    | UART serial output   |
| o_LED_1     | 56  | Output    | Blinks on reading    |
| o_LED_2     | 57  | Output    | ADC bit 15           |
| o_LED_3     | 59  | Output    | ADC bit 14           |
| o_LED_4     | 60  | Output    | ADC bit 13           |

## UART Output

Readings are printed as 4-digit signed hex values:
```
7FFF
7FFE
8001
...
```

At 860 SPS with 6 characters per reading, the output rate is about 5160 characters per second.

If the ADC is not detected (no I2C ACK), the output will be:
```
E
```
And all 4 LEDs will turn on to indicate the error.

## Build and Flash

```bash
make        # Build bitstream
make flash  # Program FPGA
```

## Modules

- `ads1115_top.v` - Top-level module
- `ads1115.v` - ADS1115 I2C driver (interrupt-driven)
- `i2c_master.v` - Generic I2C master
- `uart_tx.v` - UART transmitter
- `hex_to_ascii.v` - Hex nibble to ASCII

## ALERT/RDY Configuration

The driver configures the ADS1115 comparator thresholds to trigger ALERT on every conversion:
- Hi_thresh = 0x8000 (most negative)
- Lo_thresh = 0x7FFF (most positive)

This creates an impossible threshold condition, causing ALERT to pulse on each new reading.

## See Also

- `ads1115_polling/` - Simpler version without ALERT pin (fewer wires, but slower)
