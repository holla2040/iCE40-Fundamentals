// PWM LED Fader
// Smoothly fades LED1 up and down using pulse width modulation

module top (
  input  i_Clk,
  output o_LED_1
);

  // 8-bit PWM counter (25MHz / 256 = 97.6kHz PWM frequency)
  reg [7:0] r_PWM_Count = 0;

  // 8-bit duty cycle (0 = off, 255 = full brightness)
  reg [7:0] r_Duty = 0;

  // Fade direction (0 = up, 1 = down)
  reg r_Direction = 0;

  // Fade speed counter
  // 25MHz / 256 (PWM) / 256 (duty steps) / 400 = ~0.95 sec per fade
  reg [8:0] r_Fade_Count = 0;
  localparam FADE_SPEED = 400;

  // PWM counter - runs continuously
  always @(posedge i_Clk) begin
    r_PWM_Count <= r_PWM_Count + 1;
  end

  // Fade logic - update duty cycle slowly
  always @(posedge i_Clk) begin
    if (r_PWM_Count == 0) begin
      // Once per PWM cycle
      if (r_Fade_Count < FADE_SPEED - 1) begin
        r_Fade_Count <= r_Fade_Count + 1;
      end else begin
        r_Fade_Count <= 0;

        // Update duty cycle
        if (r_Direction == 0) begin
          // Fading up
          if (r_Duty == 255) begin
            r_Direction <= 1;
            r_Duty <= 254;
          end else begin
            r_Duty <= r_Duty + 1;
          end
        end else begin
          // Fading down
          if (r_Duty == 0) begin
            r_Direction <= 0;
            r_Duty <= 1;
          end else begin
            r_Duty <= r_Duty - 1;
          end
        end
      end
    end
  end

  // PWM output: LED on when counter < duty cycle
  assign o_LED_1 = (r_PWM_Count < r_Duty);

endmodule
