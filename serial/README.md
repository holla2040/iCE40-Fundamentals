# Serial

UART transmitter at 115200 baud, 8N1. Sends "Hello from FPGA!" every second over USB.

## Pins

| Signal | Pin | Description |
|--------|-----|-------------|
| i_Clk | 15 | 25 MHz clock |
| o_UART_TX | 74 | Serial TX to FTDI |

## Usage

```
make
make flash
```

Connect at 115200 baud:
```
screen /dev/ttyUSB0 115200
```
