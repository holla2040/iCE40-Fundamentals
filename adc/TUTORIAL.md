# ADC - Verilog Tutorial

## What This Project Does

Reads 200 samples from an AD7476A 12-bit SPI ADC and stores them in memory. Triggered by an external signal, it captures a burst of analog measurements.

## Verilog Concepts Covered

- SPI protocol (receive)
- MISO synchronization
- Memory write operations
- Data capture registers
- Extracting data from protocol frames

## SPI Receive vs Transmit

The ADC uses SPI like the DAC, but data flows the opposite direction:

```
         FPGA                    ADC
        ┌─────┐                ┌─────┐
        │     │──── SCLK ─────▶│     │  Clock (FPGA generates)
        │     │◀─── MISO ──────│     │  Data FROM ADC
        │     │──── CS_N ─────▶│     │  Chip Select
        └─────┘                └─────┘
```

- **MOSI** (Master Out): FPGA sends to peripheral (DAC)
- **MISO** (Master In): Peripheral sends to FPGA (ADC)

The AD7476A protocol:
- CS_N going low starts a conversion
- 16 clock cycles to read data
- Format: `[0][0][0][0][D11:D0]` - 4 zeros then 12-bit data
- Data valid on falling edge, sample on rising edge

## Code Walkthrough: adc_sweep Module

### Memory Write Logic

```verilog
reg [11:0] adc_memory [0:NUM_POINTS-1];
reg mem_wr_en;
reg [11:0] captured_data;

always @(posedge clk) begin
  if (mem_wr_en)
    adc_memory[point_index] <= captured_data;
end
```

Unlike reading (which has a separate output register), writing is direct:
- `mem_wr_en` enables the write
- Data goes into the address specified by `point_index`
- Write happens on the clock edge when `mem_wr_en` is high

### Data Capture Register

```verilog
WAIT_ADC: begin
  if (adc_done) begin
    captured_data <= adc_data;  // Capture the data
    state <= STORE;
  end
end

STORE: begin
  mem_wr_en <= 1'b1;  // Write captured data to memory
  ...
end
```

Why capture first, then write?
1. `adc_data` is only valid briefly when `adc_done` pulses
2. We capture it into `captured_data` to hold it stable
3. Then we assert `mem_wr_en` to write it to memory

This is a common pattern: **capture, then process**.

### Sweep State Machine

```
IDLE ──▶ READ_ADC ──▶ WAIT_ADC ──▶ STORE ──┐
  ▲                                  │     │
  │                                  │     │
  └──────────────────────────────────┴─────┘
           (done or next sample)
```

1. **IDLE**: Wait for start trigger
2. **READ_ADC**: Pulse `adc_start` to begin SPI transaction
3. **WAIT_ADC**: Wait for `adc_done`, capture data
4. **STORE**: Write to memory, loop or finish

## Code Walkthrough: adc_spi Module

### MISO Synchronization

```verilog
reg [1:0] miso_sync;
always @(posedge clk) begin
  miso_sync <= {miso_sync[0], adc_miso};
end
wire miso_in = miso_sync[1];
```

Just like UART RX, we synchronize the input to prevent metastability. The ADC's MISO signal is driven by the ADC's clock domain, not ours.

### Sampling on Rising Edge

```verilog
if (!adc_sclk) begin  // About to go high = rising edge
  shift_reg <= {shift_reg[14:0], miso_in};
  bit_cnt <= bit_cnt - 1;
end
```

The AD7476A updates MISO on the falling edge of SCLK. We sample on the rising edge when the data is stable:

```
SCLK:  ─┐   ┌───┐   ┌───┐   ┌──
        │   │   │   │   │   │
        └───┘   └───┘   └───┘

MISO:  ═══X═══════X═══════X════
          ^       ^       ^
          │       │       │
        Sample  Sample  Sample
       (rising) (rising) (rising)
```

### Receive Shift Register

```verilog
shift_reg <= {shift_reg[14:0], miso_in};
```

For receiving, we shift left and insert new bits on the right:
- Take bits 14:0 (drop the MSB)
- Append `miso_in` on the right
- After 16 shifts, `shift_reg[11:0]` contains the 12-bit value

This is the opposite of transmit (which shifts right and outputs MSB).

### Extracting the Data

```verilog
DONE: begin
  data <= shift_reg[11:0];  // Extract 12-bit value
  done <= 1'b1;
end
```

The AD7476A sends 4 leading zeros, then 12 bits of data. After shifting in all 16 bits:
- `shift_reg[15:12]` = leading zeros (discard)
- `shift_reg[11:0]` = actual ADC reading (keep)

## DAC vs ADC Comparison

| Aspect | DAC (Transmit) | ADC (Receive) |
|--------|----------------|---------------|
| Data pin | MOSI (output) | MISO (input) |
| Shift direction | Left (MSB first out) | Left (new bits in from right) |
| Data source | Register to pin | Pin to register |
| Edge | Output on falling | Sample on rising |
| Synchronization | Not needed | Required |
| Memory | Read before send | Write after receive |

## Key Takeaways

- **MISO must be synchronized** - it's an asynchronous input from the ADC
- **Sample on rising edge** when the ADC updates data on falling edge
- **Capture data immediately** when it's valid, then process it
- **Memory writes** use an enable signal (`mem_wr_en`)
- **Receive shift register** shifts left, inserting new bits on the right
- **Extract useful bits** from the protocol frame after reception
- **Same SPI clock** works for both directions - only data direction differs
