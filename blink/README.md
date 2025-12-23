# Blink

Blinks all four LEDs at different rates using a counter.

## Pins

| Signal | Pin | Description |
|--------|-----|-------------|
| i_Clk | 15 | 25 MHz clock |
| o_LED_1 | 56 | Slowest blink |
| o_LED_2 | 57 | |
| o_LED_3 | 59 | |
| o_LED_4 | 60 | Fastest blink |

## Usage

```
make
make flash
```
