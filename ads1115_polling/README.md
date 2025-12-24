# ADS1115 I2C ADC (Polling Version)

Reads a 16-bit ADC value from an ADS1115 over I2C using polling and outputs readings via UART.

## Hardware

- **ADC**: ADS1115 16-bit I2C ADC
- **Mode**: Continuous conversion, AIN0 single-ended
- **Speed**: ~380 samples per second (limited by polling interval)
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
| A0          | Input signal | ADC input   |

Note: ALERT/RDY pin is not used in this version.

## Pin Table

| Signal      | Pin | Direction | Description           |
|-------------|-----|-----------|----------------------|
| i_Clk       | 15  | Input     | 25 MHz clock         |
| io_I2C_SCL  | 62  | Bidir     | I2C clock            |
| io_I2C_SDA  | 63  | Bidir     | I2C data             |
| o_ADDR      | 64  | Output    | ADS1115 address pin  |
| o_UART_TX   | 74  | Output    | UART serial output   |
| o_LED_1     | 56  | Output    | Blinks on reading    |
| o_LED_2     | 57  | Output    | Bar graph >= 25%     |
| o_LED_3     | 59  | Output    | Bar graph >= 50%     |
| o_LED_4     | 60  | Output    | Bar graph >= 75%     |

## UART Output

Readings are printed as 4-digit signed hex values:
```
7FFF
7FFE
8001
...
```

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
- `ads1115.v` - ADS1115 I2C driver (polling)
- `i2c_master.v` - Generic I2C master
- `uart_tx.v` - UART transmitter
- `hex_to_ascii.v` - Hex nibble to ASCII

## See Also

- `ads1115_interrupt/` - Version using ALERT/RDY pin for faster, more precise timing
