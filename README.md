# Lattice iCE40 FPGA Projects

Minimal example projects for Lattice iCE40 development boards.

## Hardware

| Board | FPGA | Package | Clock |
|-------|------|---------|-------|
| Nandland Go Board | iCE40 HX1K | VQ100 | 25 MHz |
| iCEBreaker v1.1 | iCE40UP5K | QFN48 | 12 MHz |

**Toolchain**: yosys, nextpnr-ice40, iceprog

## Repository Structure

```
├── src/           # Project source code
├── config/        # Build configuration (common.mk, template PCF)
├── docs/          # Datasheets
└── other/         # Legacy/reference material
```

## Projects

| Directory | Description |
|-----------|-------------|
| `src/adc/` | AD7476A 12-bit ADC SPI master |
| `src/ads1115_interrupt/` | ADS1115 I2C ADC with interrupt mode |
| `src/ads1115_polling/` | ADS1115 I2C ADC with polling mode |
| `src/blink/` | LED blinker |
| `src/button_debounce/` | Button debounce demo with 7-seg display |
| `src/dac/` | DAC121S101 12-bit DAC SPI master |
| `src/pwm_led/` | PWM LED fader |
| `src/serial_echo/` | UART echo (RX + TX combined) |
| `src/serial_rx/` | UART RX at 115200 baud |
| `src/serial_tx/` | UART TX at 115200 baud |

## Build

```
cd src/<project>
make        # Build bitstream (outputs to /tmp/build/<project>/)
make flash  # Program FPGA
make clean  # Remove build artifacts
```
