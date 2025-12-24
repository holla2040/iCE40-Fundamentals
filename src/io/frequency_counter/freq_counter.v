// Frequency Counter Core Module
// Counts rising edges of input signal over a 1-second gate period

module freq_counter #(
  parameter CLK_FREQ = 25_000_000  // 25 MHz system clock
)(
  input  wire        clk,
  input  wire        rst,
  input  wire        freq_in,       // External frequency input
  output reg  [31:0] count_out,     // Measured frequency in Hz
  output reg         count_valid,   // Pulse high when new count ready
  output reg         signal_detect  // High if any edges detected
);

  // Gate period: 1 second = CLK_FREQ cycles
  localparam GATE_CYCLES = CLK_FREQ - 1;

  // Input synchronizer (2-FF for metastability)
  reg [1:0] sync_ff;
  wire freq_sync = sync_ff[1];

  // Edge detection
  reg freq_prev;
  wire rising_edge = freq_sync && !freq_prev;

  // Gate timer
  reg [24:0] gate_timer;
  wire gate_done = (gate_timer == GATE_CYCLES);

  // Frequency counter
  reg [31:0] freq_count;

  // Synchronize input signal
  always @(posedge clk) begin
    if (rst) begin
      sync_ff <= 2'b00;
    end else begin
      sync_ff <= {sync_ff[0], freq_in};
    end
  end

  // Edge detection register
  always @(posedge clk) begin
    if (rst) begin
      freq_prev <= 1'b0;
    end else begin
      freq_prev <= freq_sync;
    end
  end

  // Main counter logic
  always @(posedge clk) begin
    if (rst) begin
      gate_timer    <= 0;
      freq_count    <= 0;
      count_out     <= 0;
      count_valid   <= 1'b0;
      signal_detect <= 1'b0;
    end else begin
      count_valid <= 1'b0;  // Default: no valid pulse

      if (gate_done) begin
        // Gate period complete - latch count and reset
        count_out     <= freq_count;
        count_valid   <= 1'b1;
        signal_detect <= (freq_count != 0);
        freq_count    <= rising_edge ? 32'd1 : 32'd0;
        gate_timer    <= 0;
      end else begin
        // Continue counting
        gate_timer <= gate_timer + 1;
        if (rising_edge) begin
          freq_count <= freq_count + 1;
        end
      end
    end
  end

endmodule
