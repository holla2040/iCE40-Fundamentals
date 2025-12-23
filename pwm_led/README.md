# PWM LED Fader

Smoothly fades LED1 up and down using pulse width modulation.

## Description

Demonstrates PWM (Pulse Width Modulation) by continuously fading an LED between off and full brightness. The LED appears to smoothly dim and brighten in a ~2 second cycle.

## Outputs

| Output | Description |
|--------|-------------|
| LED 1 | Fades up and down continuously |

## Pin Assignments

| Signal | Pin | Description |
|--------|-----|-------------|
| i_Clk | 15 | 25 MHz clock |
| o_LED_1 | 56 | PWM-controlled LED |

## Technical Details

- **PWM Frequency**: 97.6 kHz (25 MHz / 256)
- **Resolution**: 8-bit (256 brightness levels)
- **Fade Cycle**: ~2 seconds (1 sec up, 1 sec down)

## Usage

1. Flash the FPGA: `make flash`
2. Watch LED1 smoothly fade up and down
