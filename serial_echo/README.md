# Serial Echo

Bidirectional UART that echoes received characters back with swapped case. Combines uart_rx and uart_tx modules.

## Pins

| Signal | Pin | Description |
|--------|-----|-------------|
| i_Clk | 15 | 25 MHz clock |
| i_UART_RX | 73 | Serial RX from FTDI |
| o_UART_TX | 74 | Serial TX to FTDI |
| o_LED_1 | 56 | Lights during transmission |

## Usage

```
make
make flash
```

Connect at 115200 baud. Features:
- Case swap (a→A, Z→z)
- CR→CR+LF for proper newlines
- Backspace erases previous character
