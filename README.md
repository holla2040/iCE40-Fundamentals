# Lattice iCE40 FPGA Projects

Minimal example projects for the Nandland Go Board.

## Hardware

- **FPGA**: iCE40 HX1K (VQ100 package)
- **Clock**: 25 MHz
- **Toolchain**: yosys, nextpnr-ice40, iceprog

## Projects

| Directory | Description |
|-----------|-------------|
| `adc/` | AD7476A 12-bit ADC SPI master |
| `blink/` | LED blinker |
| `dac/` | DAC121S101 12-bit DAC SPI master |
| `serial/` | UART TX at 115200 baud |

## Build

```
cd <project>
make        # Build bitstream
make flash  # Program FPGA
```
