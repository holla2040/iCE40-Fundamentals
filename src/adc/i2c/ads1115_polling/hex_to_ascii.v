// Hex Nibble to ASCII Converter
// Converts 4-bit value to ASCII hex character

module hex_to_ascii (
  input  wire [3:0] i_hex,
  output reg  [7:0] o_ascii
);

  always @(*) begin
    case (i_hex)
      4'h0: o_ascii = "0";
      4'h1: o_ascii = "1";
      4'h2: o_ascii = "2";
      4'h3: o_ascii = "3";
      4'h4: o_ascii = "4";
      4'h5: o_ascii = "5";
      4'h6: o_ascii = "6";
      4'h7: o_ascii = "7";
      4'h8: o_ascii = "8";
      4'h9: o_ascii = "9";
      4'hA: o_ascii = "A";
      4'hB: o_ascii = "B";
      4'hC: o_ascii = "C";
      4'hD: o_ascii = "D";
      4'hE: o_ascii = "E";
      4'hF: o_ascii = "F";
    endcase
  end

endmodule
