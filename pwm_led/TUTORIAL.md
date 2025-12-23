# PWM LED Tutorial

This tutorial explains pulse width modulation and how to create smooth LED fading.

## What is PWM?

PWM controls average power by rapidly switching between on and off. The ratio of on-time to total cycle time is called the **duty cycle**.

```
100% duty:  ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (always on)
 50% duty:  ‾‾‾‾____‾‾‾‾____  (half brightness)
 25% duty:  ‾‾______‾‾______  (dim)
  0% duty:  ________________  (always off)
```

At high enough frequency (>100Hz), your eye perceives the average brightness rather than the flicker.

## PWM Implementation

### The PWM Counter

```verilog
reg [7:0] r_PWM_Count = 0;

always @(posedge i_Clk) begin
  r_PWM_Count <= r_PWM_Count + 1;
end
```

This 8-bit counter cycles 0→255→0→255... at 25MHz/256 = 97.6kHz.

### Comparing to Duty Cycle

```verilog
assign o_LED_1 = (r_PWM_Count < r_Duty);
```

If `r_Duty = 64`, the LED is on for counts 0-63 (25% of the time).
If `r_Duty = 192`, the LED is on for counts 0-191 (75% of the time).

```
r_Duty = 64:   ‾‾______‾‾______  25% brightness
               0  64  255

r_Duty = 192:  ‾‾‾‾‾‾__‾‾‾‾‾‾__  75% brightness
               0    192 255
```

## Fade Logic

### Slow Updates

We don't want to change brightness every clock cycle - that would be instant. Instead, we update once every ~400 PWM cycles:

```verilog
localparam FADE_SPEED = 400;
reg [8:0] r_Fade_Count = 0;

always @(posedge i_Clk) begin
  if (r_PWM_Count == 0) begin      // Once per PWM cycle
    if (r_Fade_Count < FADE_SPEED - 1)
      r_Fade_Count <= r_Fade_Count + 1;
    else begin
      r_Fade_Count <= 0;
      // Update duty cycle here
    end
  end
end
```

This gives: 25MHz / 256 / 400 / 256 = ~0.95 seconds per fade direction.

### Triangle Wave

To fade up and down, we use a direction flag:

```verilog
reg r_Direction = 0;  // 0 = up, 1 = down

if (r_Direction == 0) begin
  if (r_Duty == 255) begin
    r_Direction <= 1;  // Start going down
    r_Duty <= 254;
  end else
    r_Duty <= r_Duty + 1;
end else begin
  if (r_Duty == 0) begin
    r_Direction <= 0;  // Start going up
    r_Duty <= 1;
  end else
    r_Duty <= r_Duty - 1;
end
```

This creates a triangle wave pattern for brightness:

```
Duty
255 |    /\        /\
    |   /  \      /  \
128 |  /    \    /    \
    | /      \  /      \
  0 |/        \/        \
    +-------------------> Time
```

## Key Concepts

1. **PWM Frequency**: Must be fast enough to avoid visible flicker (>100Hz). We use 97.6kHz - way more than needed, but simple to implement.

2. **Resolution**: 8-bit gives 256 brightness levels. More bits = smoother fading but diminishing returns for LEDs.

3. **Nested Counters**: The PWM counter runs fast (97.6kHz), while the fade counter runs slow (~1Hz) by counting PWM cycles.

4. **Non-blocking Assignment**: All `<=` assignments happen simultaneously at clock edge, preventing race conditions.

## Variations to Try

- **Different fade speed**: Change `FADE_SPEED` constant
- **Multiple LEDs**: Add more outputs with phase-shifted duty cycles
- **Button control**: Use switches to set brightness level
- **Breathing effect**: Use sine lookup table instead of triangle wave
