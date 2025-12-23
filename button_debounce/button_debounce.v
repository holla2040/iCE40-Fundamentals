// Button Debounce Demo
// Visual demonstration of switch debouncing
//
// Switch 1: Increment counter (shown on 7-segment displays)
// Switch 2: Toggle debounce on/off
// LED 1: ON when debounce is enabled
//
// Without debounce, a single press may count multiple times.
// With debounce enabled, each press counts exactly once.

module top (
  input  i_Clk,
  input  i_Switch_1,
  input  i_Switch_2,
  output o_LED_1,
  output o_Segment1_A,
  output o_Segment1_B,
  output o_Segment1_C,
  output o_Segment1_D,
  output o_Segment1_E,
  output o_Segment1_F,
  output o_Segment1_G,
  output o_Segment2_A,
  output o_Segment2_B,
  output o_Segment2_C,
  output o_Segment2_D,
  output o_Segment2_E,
  output o_Segment2_F,
  output o_Segment2_G
);

  // Debounce enable state (toggled by Switch 2)
  reg r_Debounce_En = 1'b0;

  // Counter value (0-99)
  reg [6:0] r_Count = 0;

  // Debounced signals
  wire w_Sw1_Rise;
  wire w_Sw2_Rise;

  // Debounce Switch 1 (controlled by enable toggle)
  debounce debounce_sw1 (
    .i_Clk(i_Clk),
    .i_Switch(i_Switch_1),
    .i_Enable(r_Debounce_En),
    .o_Switch(),
    .o_Rise(w_Sw1_Rise)
  );

  // Debounce Switch 2 (always enabled for clean toggle)
  debounce debounce_sw2 (
    .i_Clk(i_Clk),
    .i_Switch(i_Switch_2),
    .i_Enable(1'b1),
    .o_Switch(),
    .o_Rise(w_Sw2_Rise)
  );

  // Toggle debounce enable on Switch 2 press
  always @(posedge i_Clk) begin
    if (w_Sw2_Rise)
      r_Debounce_En <= ~r_Debounce_En;
  end

  // Increment counter on Switch 1 press
  always @(posedge i_Clk) begin
    if (w_Sw1_Rise) begin
      if (r_Count >= 99)
        r_Count <= 0;
      else
        r_Count <= r_Count + 1;
    end
  end

  // Split counter into tens and ones digits
  wire [3:0] w_Ones = r_Count % 10;
  wire [3:0] w_Tens = r_Count / 10;

  // Seven-segment outputs
  wire [6:0] w_Seg1;
  wire [6:0] w_Seg2;

  seven_seg seg_tens (
    .i_Value(w_Tens),
    .o_Segment(w_Seg1)
  );

  seven_seg seg_ones (
    .i_Value(w_Ones),
    .o_Segment(w_Seg2)
  );

  // Assign segment outputs
  assign {o_Segment1_G, o_Segment1_F, o_Segment1_E, o_Segment1_D,
          o_Segment1_C, o_Segment1_B, o_Segment1_A} = w_Seg1;
  assign {o_Segment2_G, o_Segment2_F, o_Segment2_E, o_Segment2_D,
          o_Segment2_C, o_Segment2_B, o_Segment2_A} = w_Seg2;

  // LED indicates debounce is enabled
  assign o_LED_1 = r_Debounce_En;

endmodule
