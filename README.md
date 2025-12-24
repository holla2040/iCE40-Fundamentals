# Lattice iCE40 FPGA Projects

Minimal example projects for Lattice iCE40 development boards.

## Hardware

| Board | FPGA | Package | Clock |
|-------|------|---------|-------|
| Nandland Go Board | iCE40 HX1K | VQ100 | 25 MHz |

**Toolchain**: yosys, nextpnr-ice40, iceprog

## Repository Structure

```
├── src/           # Project source code
│   ├── io/        # Digital I/O projects
│   ├── serial/    # UART serial projects
│   ├── adc/       # Analog-to-Digital converter projects
│   └── dac/       # Digital-to-Analog converter projects
├── config/        # Build configuration (common.mk)
├── docs/          # Datasheets and reference
└── other/         # Legacy/reference material
```

## Projects

### I/O Projects

| Directory | Description |
|-----------|-------------|
| `src/io/blink/` | LED blinker |
| `src/io/button_debounce/` | Button debounce demo with 7-seg display |
| `src/io/pwm_led/` | PWM LED fader |
| `src/io/frequency_counter/` | Frequency counter with UART output |

### Serial Projects

| Directory | Description |
|-----------|-------------|
| `src/serial/tx/` | UART TX at 115200 baud |
| `src/serial/rx/` | UART RX at 115200 baud |
| `src/serial/echo/` | UART echo (RX + TX combined) |

### ADC Projects

| Directory | Description |
|-----------|-------------|
| `src/adc/spi/ad7476/` | AD7476A 12-bit ADC SPI master |
| `src/adc/i2c/ads1115_polling/` | ADS1115 I2C ADC with polling mode |
| `src/adc/i2c/ads1115_interrupt/` | ADS1115 I2C ADC with interrupt mode |

### DAC Projects

| Directory | Description |
|-----------|-------------|
| `src/dac/spi/dac121s101/` | DAC121S101 12-bit DAC SPI master |

## Build

```bash
cd src/<project>
make        # Build bitstream (outputs to /tmp/build/<project>/)
make flash  # Program FPGA
make clean  # Remove build artifacts
```
