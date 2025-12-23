# Lattice iCE40 FPGA Projects

Minimal example projects for Lattice iCE40 development boards.

## Hardware

| Board | FPGA | Package | Clock |
|-------|------|---------|-------|
| Nandland Go Board | iCE40 HX1K | VQ100 | 25 MHz |
| iCEBreaker v1.1 | iCE40UP5K | QFN48 | 12 MHz |

**Toolchain**: yosys, nextpnr-ice40, iceprog

## Projects

| Directory | Description |
|-----------|-------------|
| `adc/` | AD7476A 12-bit ADC SPI master |
| `blink/` | LED blinker |
| `dac/` | DAC121S101 12-bit DAC SPI master |
| `serial_tx/` | UART TX at 115200 baud |
| `serial_rx/` | UART RX at 115200 baud |
| `serial_echo/` | UART echo (RX + TX combined) |
| `button_debounce/` | Button debounce demo with 7-seg display |

## Build

```
cd <project>
make        # Build bitstream
make flash  # Program FPGA
```
