// Frequency Counter Top Module
// Measures input frequency and outputs via UART as "12345 Hz\r\n"

module frequency_counter_top (
  input  wire i_Clk,       // 25 MHz system clock
  input  wire io_PMOD_7,   // Frequency input (directly from PMOD)
  output wire o_UART_TX,   // Serial output
  output wire io_PMOD_10,  // Test frequency output
  output wire o_LED_1,     // Measurement active (toggles each second)
  output wire o_LED_2,     // Overflow indicator (>99,999,999 Hz)
  output wire o_LED_3,     // Signal detected
  output wire o_LED_4      // Unused
);

  // Parameters
  localparam CLK_FREQ = 25_000_000;
  localparam BAUD     = 115200;

  // Power-on reset generator
  reg [7:0] r_rst_cnt = 0;
  wire w_rst = !r_rst_cnt[7];
  always @(posedge i_Clk)
    if (!r_rst_cnt[7])
      r_rst_cnt <= r_rst_cnt + 1;

  // Frequency counter outputs
  wire [31:0] w_freq_count;
  wire        w_count_valid;
  wire        w_signal_detect;

  // Frequency counter instance
  freq_counter #(
    .CLK_FREQ(CLK_FREQ)
  ) u_freq_counter (
    .i_clk          (i_Clk),
    .i_rst          (w_rst),
    .i_freq_in      (io_PMOD_7),
    .o_count_out    (w_freq_count),
    .o_count_valid  (w_count_valid),
    .o_signal_detect(w_signal_detect)
  );

  // UART TX signals
  reg  [7:0] r_tx_data;
  reg        r_tx_start;
  wire       w_tx_busy;

  // UART TX instance
  uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD(BAUD)
  ) u_uart_tx (
    .i_clk     (i_Clk),
    .i_rst     (w_rst),
    .i_tx_data (r_tx_data),
    .i_tx_start(r_tx_start),
    .o_tx_out  (o_UART_TX),
    .o_tx_busy (w_tx_busy)
  );

  // Output state machine states
  localparam ST_IDLE      = 4'd0;
  localparam ST_SUBTRACT  = 4'd1;
  localparam ST_NEXT_POS  = 4'd2;
  localparam ST_TX_DIGIT  = 4'd3;
  localparam ST_TX_SPACE  = 4'd4;
  localparam ST_TX_H      = 4'd5;
  localparam ST_TX_z      = 4'd6;
  localparam ST_TX_CR     = 4'd7;
  localparam ST_TX_LF     = 4'd8;
  localparam ST_TX_WAIT   = 4'd9;

  reg [3:0] r_state;
  reg [3:0] r_next_state;  // Where to go after TX_WAIT

  // Decimal conversion registers
  reg [31:0] r_work_val;          // Working value for conversion
  reg [7:0]  r_digits [0:7];      // Up to 8 decimal digits (stored as ASCII)
  reg [3:0]  r_num_digits;        // How many digits we have
  reg [3:0]  r_digit_idx;         // Current digit being sent
  reg        r_leading_zero;      // Skip leading zeros
  reg [3:0]  r_digit_pos;         // Position in conversion (0-7)
  reg [3:0]  r_digit_val;         // Current digit value being built

  // Powers of 10 lookup
  reg [31:0] r_current_power;
  always @(*) begin
    case (r_digit_pos)
      4'd0: r_current_power = 32'd10_000_000;
      4'd1: r_current_power = 32'd1_000_000;
      4'd2: r_current_power = 32'd100_000;
      4'd3: r_current_power = 32'd10_000;
      4'd4: r_current_power = 32'd1_000;
      4'd5: r_current_power = 32'd100;
      4'd6: r_current_power = 32'd10;
      4'd7: r_current_power = 32'd1;
      default: r_current_power = 32'd1;
    endcase
  end

  // Latched frequency for display
  reg [31:0] r_latched_freq;
  reg        r_overflow;

  // LED toggle for activity indication
  reg r_led_toggle;

  // Main state machine
  always @(posedge i_Clk) begin
    if (w_rst) begin
      r_state        <= ST_IDLE;
      r_next_state   <= ST_IDLE;
      r_tx_start     <= 1'b0;
      r_tx_data      <= 8'd0;
      r_work_val     <= 32'd0;
      r_num_digits   <= 4'd0;
      r_digit_idx    <= 4'd0;
      r_leading_zero <= 1'b1;
      r_digit_pos    <= 4'd0;
      r_digit_val    <= 4'd0;
      r_latched_freq <= 32'd0;
      r_overflow     <= 1'b0;
      r_led_toggle   <= 1'b0;
    end else begin
      r_tx_start <= 1'b0;  // Default: no start pulse

      case (r_state)
        ST_IDLE: begin
          if (w_count_valid) begin
            // Latch the new frequency value
            r_latched_freq <= w_freq_count;
            r_overflow     <= (w_freq_count > 32'd99_999_999);
            r_led_toggle   <= ~r_led_toggle;
            // Start conversion
            r_work_val     <= w_freq_count;
            r_digit_pos    <= 4'd0;
            r_num_digits   <= 4'd0;
            r_leading_zero <= 1'b1;
            r_digit_val    <= 4'd0;
            r_state        <= ST_SUBTRACT;
          end
        end

        ST_SUBTRACT: begin
          // Subtract current power of 10 repeatedly to extract digit
          if (r_work_val >= r_current_power) begin
            r_work_val  <= r_work_val - r_current_power;
            r_digit_val <= r_digit_val + 1;
          end else begin
            // Done with this digit position
            if (r_digit_val != 0 || !r_leading_zero) begin
              // Store this digit
              r_digits[r_num_digits] <= 8'h30 + r_digit_val;  // ASCII '0' + digit
              r_num_digits           <= r_num_digits + 1;
              r_leading_zero         <= 1'b0;
            end
            r_state <= ST_NEXT_POS;
          end
        end

        ST_NEXT_POS: begin
          r_digit_val <= 4'd0;
          if (r_digit_pos < 4'd7) begin
            r_digit_pos <= r_digit_pos + 1;
            r_state     <= ST_SUBTRACT;
          end else begin
            // Done converting all positions
            if (r_num_digits == 0) begin
              // Value was 0
              r_digits[0]  <= 8'h30;  // ASCII '0'
              r_num_digits <= 4'd1;
            end
            r_digit_idx <= 4'd0;
            r_state     <= ST_TX_DIGIT;
          end
        end

        ST_TX_DIGIT: begin
          if (!w_tx_busy && !r_tx_start) begin
            if (r_digit_idx < r_num_digits) begin
              r_tx_data    <= r_digits[r_digit_idx];
              r_tx_start   <= 1'b1;
              r_digit_idx  <= r_digit_idx + 1;
              r_next_state <= ST_TX_DIGIT;
              r_state      <= ST_TX_WAIT;
            end else begin
              r_state <= ST_TX_SPACE;
            end
          end
        end

        ST_TX_SPACE: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data    <= 8'h20;  // Space
            r_tx_start   <= 1'b1;
            r_next_state <= ST_TX_H;
            r_state      <= ST_TX_WAIT;
          end
        end

        ST_TX_H: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data    <= 8'h48;  // 'H'
            r_tx_start   <= 1'b1;
            r_next_state <= ST_TX_z;
            r_state      <= ST_TX_WAIT;
          end
        end

        ST_TX_z: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data    <= 8'h7A;  // 'z'
            r_tx_start   <= 1'b1;
            r_next_state <= ST_TX_CR;
            r_state      <= ST_TX_WAIT;
          end
        end

        ST_TX_CR: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data    <= 8'h0D;  // CR
            r_tx_start   <= 1'b1;
            r_next_state <= ST_TX_LF;
            r_state      <= ST_TX_WAIT;
          end
        end

        ST_TX_LF: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data    <= 8'h0A;  // LF
            r_tx_start   <= 1'b1;
            r_next_state <= ST_IDLE;
            r_state      <= ST_TX_WAIT;
          end
        end

        ST_TX_WAIT: begin
          // Wait for TX to start then complete
          if (w_tx_busy) begin
            // TX has started, wait for it to finish
          end else if (!r_tx_start) begin
            // TX done, go to next state
            r_state <= r_next_state;
          end
        end

        default: r_state <= ST_IDLE;
      endcase
    end
  end

  // Test frequency generator instance (1000 Hz output)
  test_freq_gen u_test_freq_gen (
    .i_Clk     (i_Clk),
    .o_Freq_Out(io_PMOD_10)
  );

  // LED outputs
  assign o_LED_1 = r_led_toggle;      // Toggles each measurement
  assign o_LED_2 = r_overflow;        // Overflow indicator
  assign o_LED_3 = w_signal_detect;   // Signal present
  assign o_LED_4 = 1'b0;              // Unused

endmodule
