// Test Frequency Generator
// Generates a 6.25 MHz square wave for testing the frequency counter
// Connect io_PMOD_10 to io_PMOD_7 with a jumper wire to test

module test_freq_gen (
  input  wire i_Clk,      // 25 MHz system clock
  output reg  o_Freq_Out  // Test frequency output
);

  // Generate 6.25 MHz from 25 MHz clock (50% duty cycle)
  // 25 MHz / 4 = 6.25 MHz, toggle every 2 cycles
  localparam HALF_PERIOD = 2 - 1;

  reg [0:0] r_counter = 0;

  always @(posedge i_Clk) begin
    if (r_counter >= HALF_PERIOD) begin
      r_counter  <= 0;
      o_Freq_Out <= ~o_Freq_Out;
    end else begin
      r_counter <= r_counter + 1;
    end
  end

endmodule
