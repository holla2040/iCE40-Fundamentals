# Lattice iCE40 FPGA Projects

## Toolchain
- **Synthesis**: yosys
- **Place & Route**: nextpnr-ice40
- **Bitstream**: icepack
- **Programming**: iceprog

## Target Hardware
- **FPGA**: iCE40 HX1K
- **Package**: VQ100
- **Board**: Nandland Go Board
- **Clock**: 25 MHz

## Project Structure
Each project directory contains:
- `*.v` - Verilog source files
- `pins.pcf` - Pin constraint file
- `Makefile` - Build with `make`, flash with `make flash`

## Build Commands
```bash
make        # Build bitstream
make flash  # Program FPGA
make clean  # Remove build artifacts
```

## Pin Constraint Format (PCF)
```
set_io signal_name pin_number
```

## Development Rules

IMPORTANT: After ANY Verilog (.v) or constraint (.pcf) changes, run `make` in the project directory to verify compilation succeeds. Do not consider a change complete until it compiles without errors.

```bash
cd <project_dir> && make
```

Fix any synthesis or place-and-route errors before proceeding.
