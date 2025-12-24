# Lattice iCE40 FPGA Projects

Learn FPGA development with minimal, well-documented example projects for the Lattice iCE40.

**Designed for use with [Claude Code](https://claude.ai/claude-code)** - an AI coding assistant that understands this codebase and can help you build, modify, and learn from these projects.

## Hardware

| Board | FPGA | Package | Clock |
|-------|------|---------|-------|
| Nandland Go Board | iCE40 HX1K | VQ100 | 25 MHz |

**Toolchain**: yosys, nextpnr-ice40, iceprog

## Repository Structure

```
├── src/           # Project source code
│   ├── io/        # Digital I/O projects
│   │   ├── blink/
│   │   ├── button_debounce/
│   │   ├── frequency_counter/
│   │   └── pwm_led/
│   ├── serial/    # UART serial projects
│   │   ├── echo/
│   │   ├── rx/
│   │   └── tx/
│   ├── adc/       # Analog-to-Digital converter projects
│   │   ├── i2c/
│   │   │   ├── ads1115_interrupt/
│   │   │   └── ads1115_polling/
│   │   └── spi/
│   │       └── ad7476/
│   └── dac/       # Digital-to-Analog converter projects
│       └── spi/
│           └── dac121s101/
├── config/        # Build configuration
│   └── common.mk
├── docs/          # Datasheets and reference
│   └── pins_nandland_go.pcf
└── other/         # Legacy/reference material
    ├── icestudio/
    └── tutorial_original/
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

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/UNDERSTANDING_THE_CODE.md`](docs/UNDERSTANDING_THE_CODE.md) | Guide to reading and understanding the Verilog code |
| [`docs/pins_nandland_go.pcf`](docs/pins_nandland_go.pcf) | Master pin definitions for the Go Board |
| Each project's `TUTORIAL.md` | Beginner-friendly explanation of that project |
