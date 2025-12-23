# Serial RX

UART receiver at 115200 baud, 8N1. Controls LED 1 based on received character.

## Pins

| Signal | Pin | Description |
|--------|-----|-------------|
| i_Clk | 15 | 25 MHz clock |
| i_UART_RX | 73 | Serial RX from FTDI |
| o_LED_1 | 56 | Controlled LED |

## Usage

```
make
make flash
```

Send characters over serial at 115200 baud:
- Send `0` to turn off LED 1
- Send `1` to turn on LED 1
