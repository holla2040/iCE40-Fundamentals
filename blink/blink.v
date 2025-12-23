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
  reg [32:0] counter = 0;

  always @(posedge i_Clk) begin
    counter <= counter + 1;
  end

  // Each LED blinks at different rate
  assign o_LED_1 = counter[26];
  assign o_LED_2 = counter[25];
  assign o_LED_3 = counter[24];
  assign o_LED_4 = counter[23];

/* original
  // Each LED blinks at different rate
  reg [23:0] counter = 0;
  assign o_LED_1 = counter[23];  // ~1.5 sec period
  assign o_LED_2 = counter[22];  // ~0.75 sec period
  assign o_LED_3 = counter[21];  // ~0.38 sec period
  assign o_LED_4 = counter[20];  // ~0.19 sec period
*/

endmodule
