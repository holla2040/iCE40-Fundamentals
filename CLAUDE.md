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
Each project directory must contain:
- `*.v` - Verilog source files
- `pins.pcf` - Pin constraint file
- `Makefile` - Build with `make`, flash with `make flash`
- `README.md` - Brief description, pin table, usage
- `TUTORIAL.md` - Beginner-friendly Verilog explanation

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

## Code Style

- **Indentation**: 2 spaces (no tabs)

## Development Rules

IMPORTANT: After ANY Verilog (.v) or constraint (.pcf) changes, run `make` in the project directory to verify compilation succeeds. Do not consider a change complete until it compiles without errors.

```bash
cd <project_dir> && make
```

Fix any synthesis or place-and-route errors before proceeding.

IMPORTANT: After ANY code changes, review the project's README.md and TUTORIAL.md for necessary updates. Documentation must stay in sync with the code.

## Git Rules

CRITICAL: Do NOT commit or push changes automatically. Wait for explicit user instruction:
- Only commit when user says "commit"
- Only push when user says "push"
- Never assume permission for git operations
