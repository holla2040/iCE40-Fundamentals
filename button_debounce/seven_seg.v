// Seven-Segment Display Decoder
// Converts 4-bit BCD (0-9) to 7-segment pattern
// Active LOW outputs (accent on = 0)

module seven_seg (
  input  [3:0] i_Value,
  output [6:0] o_Segment  // {G, F, E, D, C, B, A}
);

  reg [6:0] r_Segment;

  always @(*) begin
    case (i_Value)
      //                 GFEDCBA
      4'd0: r_Segment = 7'b1000000;  // 0
      4'd1: r_Segment = 7'b1111001;  // 1
      4'd2: r_Segment = 7'b0100100;  // 2
      4'd3: r_Segment = 7'b0110000;  // 3
      4'd4: r_Segment = 7'b0011001;  // 4
      4'd5: r_Segment = 7'b0010010;  // 5
      4'd6: r_Segment = 7'b0000010;  // 6
      4'd7: r_Segment = 7'b1111000;  // 7
      4'd8: r_Segment = 7'b0000000;  // 8
      4'd9: r_Segment = 7'b0010000;  // 9
      default: r_Segment = 7'b1111111;  // blank
    endcase
  end

  assign o_Segment = r_Segment;

endmodule
