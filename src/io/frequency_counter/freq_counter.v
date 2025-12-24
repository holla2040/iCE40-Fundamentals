// Frequency Counter Core Module
// Counts rising edges of input signal over a 1-second gate period

module freq_counter #(
  parameter CLK_FREQ = 25_000_000  // 25 MHz system clock
)(
  input  wire        i_clk,
  input  wire        i_rst,
  input  wire        i_freq_in,       // External frequency input
  output reg  [31:0] o_count_out,     // Measured frequency in Hz
  output reg         o_count_valid,   // Pulse high when new count ready
  output reg         o_signal_detect  // High if any edges detected
);

  // Gate period: 1 second = CLK_FREQ cycles
  localparam GATE_CYCLES = CLK_FREQ - 1;

  // Input synchronizer (2-FF for metastability)
  reg [1:0] r_sync_ff;
  wire w_freq_sync = r_sync_ff[1];

  // Edge detection
  reg r_freq_prev;
  wire w_rising_edge = w_freq_sync && !r_freq_prev;

  // Gate timer
  reg [24:0] r_gate_timer;
  wire w_gate_done = (r_gate_timer == GATE_CYCLES);

  // Frequency counter
  reg [31:0] r_freq_count;

  // Synchronize input signal
  always @(posedge i_clk) begin
    if (i_rst) begin
      r_sync_ff <= 2'b00;
    end else begin
      r_sync_ff <= {r_sync_ff[0], i_freq_in};
    end
  end

  // Edge detection register
  always @(posedge i_clk) begin
    if (i_rst) begin
      r_freq_prev <= 1'b0;
    end else begin
      r_freq_prev <= w_freq_sync;
    end
  end

  // Main counter logic
  always @(posedge i_clk) begin
    if (i_rst) begin
      r_gate_timer    <= 0;
      r_freq_count    <= 0;
      o_count_out     <= 0;
      o_count_valid   <= 1'b0;
      o_signal_detect <= 1'b0;
    end else begin
      o_count_valid <= 1'b0;  // Default: no valid pulse

      if (w_gate_done) begin
        // Gate period complete - latch count and reset
        o_count_out     <= r_freq_count;
        o_count_valid   <= 1'b1;
        o_signal_detect <= (r_freq_count != 0);
        r_freq_count    <= w_rising_edge ? 32'd1 : 32'd0;
        r_gate_timer    <= 0;
      end else begin
        // Continue counting
        r_gate_timer <= r_gate_timer + 1;
        if (w_rising_edge) begin
          r_freq_count <= r_freq_count + 1;
        end
      end
    end
  end

endmodule
