// Button Debounce Filter
// Waits for input to be stable for 10ms before changing output
// When i_Enable=0, bypasses filter (passes raw input)

module debounce (
  input  i_Clk,
  input  i_Switch,
  input  i_Enable,
  output o_Switch,
  output o_Rise     // Single-cycle pulse on rising edge
);

  // 10ms at 25MHz = 250,000 clocks
  // Need 18 bits to count to 250,000
  parameter DEBOUNCE_COUNT = 250000;

  reg [17:0] r_Count = 0;
  reg r_State = 0;
  reg r_Switch_Prev = 0;

  // Debounced or raw output based on enable
  wire w_Output = i_Enable ? r_State : i_Switch;

  always @(posedge i_Clk) begin
    r_Switch_Prev <= w_Output;

    if (i_Switch != r_State) begin
      // Input differs from current state, count up
      if (r_Count < DEBOUNCE_COUNT - 1)
        r_Count <= r_Count + 1;
      else begin
        // Stable long enough, update state
        r_State <= i_Switch;
        r_Count <= 0;
      end
    end else begin
      // Input matches state, reset counter
      r_Count <= 0;
    end
  end

  assign o_Switch = w_Output;
  assign o_Rise = w_Output & ~r_Switch_Prev;

endmodule
