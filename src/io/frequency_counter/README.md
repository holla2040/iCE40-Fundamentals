# Frequency Counter

Measures the frequency of an external signal and outputs the result via UART.

## Features

- 1-second gate time for direct Hz reading
- Measurement range: 0 Hz to 99,999,999 Hz
- UART output at 115200 baud (8N1)
- LED indicators for activity, overflow, and signal detection
- 2-flip-flop input synchronization for metastability protection

## Hardware

- **Input**: Any digital signal (3.3V logic level)
- **Output**: UART serial at 115200 baud
- **Update Rate**: Once per second

## Wiring

| Signal | Go Board | Description |
|--------|----------|-------------|
| Frequency Input | io_PMOD_7 | Signal to measure |
| Test Frequency | io_PMOD_10 | 6.25 MHz test output |
| UART TX | USB (built-in) | Serial output |

## Pin Table

| Signal | FPGA Pin | Direction | Description |
|--------|----------|-----------|-------------|
| i_Clk | 15 | Input | 25 MHz system clock |
| io_PMOD_7 | 78 | Input | External frequency input |
| io_PMOD_10 | 81 | Output | 6.25 MHz test signal |
| o_UART_TX | 74 | Output | Serial transmit |
| o_LED_1 | 56 | Output | Toggles each measurement |
| o_LED_2 | 57 | Output | Overflow (>99,999,999 Hz) |
| o_LED_3 | 59 | Output | Signal detected |
| o_LED_4 | 60 | Output | Unused |

## UART Output

Format: `<frequency> Hz\r\n`

Examples:
```
0 Hz
1000 Hz
12345678 Hz
```

Output updates once per second.

## Build and Flash

```bash
make        # Build bitstream
make flash  # Program FPGA
```

## Testing

**Self-test with built-in generator:**
1. Connect io_PMOD_10 (pin 81) to io_PMOD_7 (pin 78) with a jumper wire
2. Open a serial terminal at 115200 baud
3. Should display `6250000 Hz` every second

**External signal:**
1. Connect a signal generator to PMOD Pin 1
2. Open a serial terminal at 115200 baud
3. Observe frequency readings every second

## Modules

| File | Description |
|------|-------------|
| `frequency_counter_top.v` | Top module with UART output state machine |
| `freq_counter.v` | Core frequency counter with 1-second gate |
| `uart_tx.v` | UART transmitter (115200 baud) |
| `test_freq_gen.v` | 6.25 MHz test signal generator |

## See Also

- `src/serial/tx/` - UART transmitter standalone
- `src/io/button_debounce/` - Input synchronization techniques
