// Test Frequency Generator
// Generates a 500 kHz square wave for testing the frequency counter
// Connect io_PMOD_10 to io_PMOD_7 with a jumper wire to test

module test_freq_gen (
  input  wire i_Clk,      // 25 MHz system clock
  output reg  o_Freq_Out  // Test frequency output
);

  // Generate 500,000 Hz from 25 MHz clock (exact division)
  // 25,000,000 / 500,000 = 50 cycles per period
  // Toggle every 25 cycles for 50% duty cycle
  localparam HALF_PERIOD = 25 - 1;

  reg [4:0] counter = 0;

  always @(posedge i_Clk) begin
    if (counter >= HALF_PERIOD) begin
      counter    <= 0;
      o_Freq_Out <= ~o_Freq_Out;
    end else begin
      counter <= counter + 1;
    end
  end

endmodule
