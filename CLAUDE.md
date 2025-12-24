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
├── src/           # Project source code
│   ├── io/        # Digital I/O projects (blink, button_debounce, pwm_led, frequency_counter)
│   ├── serial/    # UART projects (tx, rx, echo)
│   ├── adc/       # ADC projects (spi/ad7476, i2c/ads1115_*)
│   └── dac/       # DAC projects (spi/dac121s101)
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

Follow these conventions for all Verilog code:

### Formatting
- **Indentation**: 2 spaces (no tabs)
- **Line length**: 80 characters preferred, 100 max

### Naming Conventions
| Prefix | Usage | Example |
|--------|-------|---------|
| `i_` | Input ports | `i_Clk`, `i_Switch_1` |
| `o_` | Output ports | `o_LED_1`, `o_UART_TX` |
| `r_` | Registers | `r_Count`, `r_State` |
| `w_` | Wires | `w_Rx_Valid`, `w_Output` |
| `UPPERCASE` | Constants/parameters | `CLK_FREQ`, `BAUD_RATE` |
| `S_` or `UPPERCASE` | State machine states | `S_IDLE`, `START_BIT` |

### Sequential Logic
- Use synchronous reset (iCE40 has no dedicated reset routing)
- Use non-blocking assignment (`<=`) in `always @(posedge clk)` blocks
- Reset all registers in the reset block

### Combinational Logic
- Use blocking assignment (`=`) in `always @*` blocks and `assign` statements
- Every `case` statement must have a `default`

### Module Instantiation
- Always use named port connections (`.port(signal)`)
- Never use positional arguments

See `docs/UNDERSTANDING_THE_CODE.md` for detailed explanations of these conventions.

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
