# Blink - Verilog Tutorial

## What This Project Does

Blinks four LEDs at different rates using a single counter. This is the "Hello World" of FPGA projects.

## Verilog Concepts Covered

- Module declaration
- Input and output ports
- Registers (`reg`)
- Always blocks with clock edge
- Continuous assignment (`assign`)
- Bit slicing

## Code Walkthrough

### Module Declaration

```verilog
module blink (
  input  i_Clk,
  output o_LED_1,
  output o_LED_2,
  output o_LED_3,
  output o_LED_4
);
```

Every Verilog design starts with a `module`. Think of it like a function definition:
- `blink` is the module name
- Inside the parentheses are the **ports** - connections to the outside world
- `input` ports receive signals (like the clock)
- `output` ports drive signals (like the LEDs)

### Registers

```verilog
reg [32:0] counter = 0;
```

A `reg` (register) stores a value. Unlike a wire, it remembers its value between clock cycles.

- `[32:0]` means 33 bits wide (bits 32 down to 0)
- `= 0` initializes it to zero at startup

**Why 33 bits?** At 25 MHz, a 33-bit counter takes about 5.7 minutes to overflow. We only use bits 23-26 for the LEDs, but having extra bits doesn't hurt.

### Always Block (Synchronous Logic)

```verilog
always @(posedge i_Clk) begin
  counter <= counter + 1;
end
```

This is the heart of synchronous digital design:

- `always @(posedge i_Clk)` means "do this on every rising edge of the clock"
- `posedge` = positive edge (0 to 1 transition)
- `<=` is **non-blocking assignment** - the standard for sequential logic
- The counter increments by 1 every clock cycle (every 40 nanoseconds at 25 MHz)

### Continuous Assignment

```verilog
assign o_LED_1 = counter[26];
assign o_LED_2 = counter[25];
assign o_LED_3 = counter[24];
assign o_LED_4 = counter[23];
```

`assign` creates a permanent connection - the output always equals the right side.

**Bit slicing** `counter[26]` extracts just bit 26 from the counter. Each bit toggles at a different rate:

| Bit | Toggles Every | Period | Frequency |
|-----|---------------|--------|-----------|
| 26 | 2^26 clocks | ~2.7 sec | ~0.37 Hz |
| 25 | 2^25 clocks | ~1.3 sec | ~0.75 Hz |
| 24 | 2^24 clocks | ~0.67 sec | ~1.5 Hz |
| 23 | 2^23 clocks | ~0.34 sec | ~3 Hz |

**The math:** At 25 MHz, bit N toggles every 2^N / 25,000,000 seconds.

### End Module

```verilog
endmodule
```

Closes the module definition.

## Key Takeaways

- **Modules** are the building blocks of Verilog designs
- **Registers** store values; use them in `always` blocks
- **`always @(posedge clk)`** runs on every clock edge - this is synchronous logic
- **`assign`** creates combinational (instant) connections
- **Bit slicing** extracts individual bits - useful for frequency division
- A simple counter can generate multiple clock frequencies
