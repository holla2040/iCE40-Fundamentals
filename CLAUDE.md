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

## Repository Structure
```
├── src/           # Project source code (all projects here)
├── config/        # Build configuration
│   └── common.mk
├── docs/          # Datasheets and reference
│   └── pins_nandland_go.pcf  # Master pin definitions (matches schematic)
└── other/         # Legacy/reference material
```

## Project Structure
Each project directory in `src/` must contain:
- `*.v` - Verilog source files
- `pins.pcf` - Pin constraint file (subset of docs/pins_nandland_go.pcf)
- `Makefile` - Build with `make`, flash with `make flash`
- `README.md` - Brief description, pin table, usage
- `TUTORIAL.md` - Beginner-friendly Verilog explanation

## Pin Naming Convention
All projects MUST use signal names from `docs/pins_nandland_go.pcf`. This ensures consistency with the board schematic. Each project's `pins.pcf` should be a subset containing only the pins used by that project.

## Build Commands
```bash
cd src/<project>
make        # Build bitstream (outputs to /tmp/build/<project>/)
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
cd src/<project_dir> && make
```

Fix any synthesis or place-and-route errors before proceeding.

IMPORTANT: After ANY code changes, review the project's README.md and TUTORIAL.md for necessary updates. Documentation must stay in sync with the code.

## Git Rules

CRITICAL: Do NOT commit or push changes automatically. Wait for explicit user instruction:
- Only commit when user says "commit"
- Only push when user says "push"
- Never assume permission for git operations
