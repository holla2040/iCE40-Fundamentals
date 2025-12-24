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
  reg [7:0] rst_cnt = 0;
  wire rst = !rst_cnt[7];
  always @(posedge i_Clk)
    if (!rst_cnt[7])
      rst_cnt <= rst_cnt + 1;

  // Frequency counter outputs
  wire [31:0] freq_count;
  wire        count_valid;
  wire        signal_detect;

  // Frequency counter instance
  freq_counter #(
    .CLK_FREQ(CLK_FREQ)
  ) u_freq_counter (
    .clk          (i_Clk),
    .rst          (rst),
    .freq_in      (io_PMOD_7),
    .count_out    (freq_count),
    .count_valid  (count_valid),
    .signal_detect(signal_detect)
  );

  // UART TX signals
  reg  [7:0] tx_data;
  reg        tx_start;
  wire       tx_busy;

  // UART TX instance
  uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD(BAUD)
  ) u_uart_tx (
    .clk     (i_Clk),
    .rst     (rst),
    .tx_data (tx_data),
    .tx_start(tx_start),
    .tx_out  (o_UART_TX),
    .tx_busy (tx_busy)
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

  reg [3:0] state;
  reg [3:0] next_state;  // Where to go after TX_WAIT

  // Decimal conversion registers
  reg [31:0] work_val;          // Working value for conversion
  reg [7:0]  digits [0:7];      // Up to 8 decimal digits (stored as ASCII)
  reg [3:0]  num_digits;        // How many digits we have
  reg [3:0]  digit_idx;         // Current digit being sent
  reg        leading_zero;      // Skip leading zeros
  reg [3:0]  digit_pos;         // Position in conversion (0-7)
  reg [3:0]  digit_val;         // Current digit value being built

  // Powers of 10 lookup
  reg [31:0] current_power;
  always @(*) begin
    case (digit_pos)
      4'd0: current_power = 32'd10_000_000;
      4'd1: current_power = 32'd1_000_000;
      4'd2: current_power = 32'd100_000;
      4'd3: current_power = 32'd10_000;
      4'd4: current_power = 32'd1_000;
      4'd5: current_power = 32'd100;
      4'd6: current_power = 32'd10;
      4'd7: current_power = 32'd1;
      default: current_power = 32'd1;
    endcase
  end

  // Latched frequency for display
  reg [31:0] latched_freq;
  reg        overflow;

  // LED toggle for activity indication
  reg led_toggle;

  // Main state machine
  always @(posedge i_Clk) begin
    if (rst) begin
      state        <= ST_IDLE;
      next_state   <= ST_IDLE;
      tx_start     <= 1'b0;
      tx_data      <= 8'd0;
      work_val     <= 32'd0;
      num_digits   <= 4'd0;
      digit_idx    <= 4'd0;
      leading_zero <= 1'b1;
      digit_pos    <= 4'd0;
      digit_val    <= 4'd0;
      latched_freq <= 32'd0;
      overflow     <= 1'b0;
      led_toggle   <= 1'b0;
    end else begin
      tx_start <= 1'b0;  // Default: no start pulse

      case (state)
        ST_IDLE: begin
          if (count_valid) begin
            // Latch the new frequency value
            latched_freq <= freq_count;
            overflow     <= (freq_count > 32'd99_999_999);
            led_toggle   <= ~led_toggle;
            // Start conversion
            work_val     <= freq_count;
            digit_pos    <= 4'd0;
            num_digits   <= 4'd0;
            leading_zero <= 1'b1;
            digit_val    <= 4'd0;
            state        <= ST_SUBTRACT;
          end
        end

        ST_SUBTRACT: begin
          // Subtract current power of 10 repeatedly to extract digit
          if (work_val >= current_power) begin
            work_val  <= work_val - current_power;
            digit_val <= digit_val + 1;
          end else begin
            // Done with this digit position
            if (digit_val != 0 || !leading_zero) begin
              // Store this digit
              digits[num_digits] <= 8'h30 + digit_val;  // ASCII '0' + digit
              num_digits         <= num_digits + 1;
              leading_zero       <= 1'b0;
            end
            state <= ST_NEXT_POS;
          end
        end

        ST_NEXT_POS: begin
          digit_val <= 4'd0;
          if (digit_pos < 4'd7) begin
            digit_pos <= digit_pos + 1;
            state     <= ST_SUBTRACT;
          end else begin
            // Done converting all positions
            if (num_digits == 0) begin
              // Value was 0
              digits[0]  <= 8'h30;  // ASCII '0'
              num_digits <= 4'd1;
            end
            digit_idx <= 4'd0;
            state     <= ST_TX_DIGIT;
          end
        end

        ST_TX_DIGIT: begin
          if (!tx_busy && !tx_start) begin
            if (digit_idx < num_digits) begin
              tx_data    <= digits[digit_idx];
              tx_start   <= 1'b1;
              digit_idx  <= digit_idx + 1;
              next_state <= ST_TX_DIGIT;
              state      <= ST_TX_WAIT;
            end else begin
              state <= ST_TX_SPACE;
            end
          end
        end

        ST_TX_SPACE: begin
          if (!tx_busy && !tx_start) begin
            tx_data    <= 8'h20;  // Space
            tx_start   <= 1'b1;
            next_state <= ST_TX_H;
            state      <= ST_TX_WAIT;
          end
        end

        ST_TX_H: begin
          if (!tx_busy && !tx_start) begin
            tx_data    <= 8'h48;  // 'H'
            tx_start   <= 1'b1;
            next_state <= ST_TX_z;
            state      <= ST_TX_WAIT;
          end
        end

        ST_TX_z: begin
          if (!tx_busy && !tx_start) begin
            tx_data    <= 8'h7A;  // 'z'
            tx_start   <= 1'b1;
            next_state <= ST_TX_CR;
            state      <= ST_TX_WAIT;
          end
        end

        ST_TX_CR: begin
          if (!tx_busy && !tx_start) begin
            tx_data    <= 8'h0D;  // CR
            tx_start   <= 1'b1;
            next_state <= ST_TX_LF;
            state      <= ST_TX_WAIT;
          end
        end

        ST_TX_LF: begin
          if (!tx_busy && !tx_start) begin
            tx_data    <= 8'h0A;  // LF
            tx_start   <= 1'b1;
            next_state <= ST_IDLE;
            state      <= ST_TX_WAIT;
          end
        end

        ST_TX_WAIT: begin
          // Wait for TX to start then complete
          if (tx_busy) begin
            // TX has started, wait for it to finish
          end else if (!tx_start) begin
            // TX done, go to next state
            state <= next_state;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

  // Test frequency generator instance (1000 Hz output)
  test_freq_gen u_test_freq_gen (
    .i_Clk     (i_Clk),
    .o_Freq_Out(io_PMOD_10)
  );

  // LED outputs
  assign o_LED_1 = led_toggle;      // Toggles each measurement
  assign o_LED_2 = overflow;        // Overflow indicator
  assign o_LED_3 = signal_detect;   // Signal present
  assign o_LED_4 = 1'b0;            // Unused

endmodule
