# Button Debounce Demo

Visual demonstration of switch debouncing using seven-segment displays.

## Description

Mechanical switches "bounce" when pressed, causing multiple electrical transitions. Without debouncing, a single button press can register as 2-10 presses. This project lets you see the difference.

## Controls

| Input | Function |
|-------|----------|
| Switch 1 | Increment counter |
| Switch 2 | Toggle debounce on/off |

| Output | Meaning |
|--------|---------|
| 7-Seg Display | Counter value (00-99) |
| LED 1 | ON = debounce enabled |

## Usage

1. Flash the FPGA: `make flash`
2. Press Switch 1 repeatedly - counter jumps erratically (no debounce)
3. Press Switch 2 to enable debounce (LED 1 lights)
4. Press Switch 1 again - counter increments cleanly by 1

## Pin Assignments

| Signal | Pin | Description |
|--------|-----|-------------|
| i_Clk | 15 | 25 MHz clock |
| i_Switch_1 | 53 | Count button |
| i_Switch_2 | 51 | Debounce toggle |
| o_LED_1 | 56 | Debounce status |
| o_Segment1_A | 3 | 7-seg tens digit |
| o_Segment1_B | 4 | |
| o_Segment1_C | 93 | |
| o_Segment1_D | 91 | |
| o_Segment1_E | 90 | |
| o_Segment1_F | 1 | |
| o_Segment1_G | 2 | |
| o_Segment2_A | 100 | 7-seg ones digit |
| o_Segment2_B | 99 | |
| o_Segment2_C | 97 | |
| o_Segment2_D | 95 | |
| o_Segment2_E | 94 | |
| o_Segment2_F | 8 | |
| o_Segment2_G | 96 | |

## Modules

- `button_debounce.v` - Top module
- `debounce.v` - 10ms debounce filter with bypass
- `seven_seg.v` - BCD to 7-segment decoder
