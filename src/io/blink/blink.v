// Blink LED for Nandland Go Board
// iCE40HX1K - 25MHz clock

module blink (
  input  i_Clk,
  output o_LED_1,
  output o_LED_2,
  output o_LED_3,
  output o_LED_4
);

  // 25MHz clock, ~24 bits needed for ~1 second
  reg [32:0] r_counter = 0;

  always @(posedge i_Clk) begin
    r_counter <= r_counter + 1;
  end

  // Each LED blinks at different rate
  assign o_LED_1 = r_counter[26];
  assign o_LED_2 = r_counter[25];
  assign o_LED_3 = r_counter[24];
  assign o_LED_4 = r_counter[23];

endmodule
