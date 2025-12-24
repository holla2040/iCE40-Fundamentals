// Serial Echo for Nandland Go Board
// Receives characters and echoes them back with SWAPPED CASE
// 115200 baud, 8N1

module top (
  input  wire i_Clk,
  input  wire i_UART_RX,
  output wire o_UART_TX,
  output wire o_LED_1
);

  // Reset generation
  reg [3:0] r_rst_count = 4'hF;
  wire w_rst = r_rst_count != 0;
  always @(posedge i_Clk) begin
    if (r_rst_count != 0)
      r_rst_count <= r_rst_count - 1;
  end

  // UART RX signals
  wire [7:0] w_rx_data;
  wire       w_rx_valid;

  // Swap case: lowercase -> uppercase, uppercase -> lowercase
  wire w_is_lower = (w_rx_data >= "a") && (w_rx_data <= "z");
  wire w_is_upper = (w_rx_data >= "A") && (w_rx_data <= "Z");
  wire [7:0] w_rx_swapped = w_is_lower ? (w_rx_data - 8'h20) :
                            w_is_upper ? (w_rx_data + 8'h20) : w_rx_data;

  // UART TX signals
  reg  [7:0] r_tx_data;
  reg        r_tx_start;
  wire       w_tx_busy;

  // UART Receiver
  uart_rx #(
    .CLK_FREQ(25_000_000),
    .BAUD(115200)
  ) rx_inst (
    .i_clk(i_Clk),
    .i_rst(w_rst),
    .i_rx_in(i_UART_RX),
    .o_rx_data(w_rx_data),
    .o_rx_valid(w_rx_valid)
  );

  // UART Transmitter
  uart_tx #(
    .CLK_FREQ(25_000_000),
    .BAUD(115200)
  ) tx_inst (
    .i_clk(i_Clk),
    .i_rst(w_rst),
    .i_tx_data(r_tx_data),
    .i_tx_start(r_tx_start),
    .o_tx_out(o_UART_TX),
    .o_tx_busy(w_tx_busy)
  );

  // Detect special characters
  wire w_is_backspace = (w_rx_data == 8'h08) || (w_rx_data == 8'h7F);  // BS or DEL
  wire w_is_cr = (w_rx_data == 8'h0D);

  // Echo state machine
  localparam IDLE    = 3'd0;
  localparam WAIT_TX = 3'd1;
  localparam SENDING = 3'd2;
  localparam SEND_LF = 3'd3;  // Send LF after CR
  localparam SEND_BS = 3'd4;  // Backspace sequence: BS, Space, BS

  reg [2:0] r_state = IDLE;
  reg [7:0] r_echo_data;
  reg       r_need_lf;     // Flag: need to send LF after current char
  reg [1:0] r_bs_step;     // Backspace sequence step (0=BS, 1=Space, 2=BS)
  reg       r_tx_pending;  // TX initiated, waiting for completion
  reg       r_tx_was_busy; // w_tx_busy has been seen high since r_tx_start

  always @(posedge i_Clk) begin
    if (w_rst) begin
      r_state       <= IDLE;
      r_tx_start    <= 0;
      r_tx_data     <= 0;
      r_echo_data   <= 0;
      r_need_lf     <= 0;
      r_bs_step     <= 0;
      r_tx_pending  <= 0;
      r_tx_was_busy <= 0;
    end else begin
      r_tx_start <= 0;

      case (r_state)
        IDLE: begin
          if (w_rx_valid) begin
            if (w_is_backspace) begin
              r_bs_step <= 0;
              r_state   <= SEND_BS;
            end else begin
              r_echo_data <= w_rx_swapped;
              r_need_lf   <= w_is_cr;
              r_state     <= WAIT_TX;
            end
          end
        end

        WAIT_TX: begin
          if (!w_tx_busy) begin
            r_tx_data  <= r_echo_data;
            r_tx_start <= 1;
            r_state    <= SENDING;
          end
        end

        SENDING: begin
          if (w_tx_busy) begin
            // TX started, wait for completion
          end else begin
            if (r_need_lf) begin
              r_state <= SEND_LF;
            end else begin
              r_state <= IDLE;
            end
          end
        end

        SEND_LF: begin
          if (!w_tx_busy) begin
            r_tx_data  <= 8'h0A;  // LF
            r_tx_start <= 1;
            r_need_lf  <= 0;
            r_state    <= SENDING;
          end
        end

        SEND_BS: begin
          if (r_tx_pending) begin
            // Track when w_tx_busy goes high
            if (w_tx_busy)
              r_tx_was_busy <= 1;
            // TX complete when w_tx_busy seen high then goes low
            if (r_tx_was_busy && !w_tx_busy) begin
              r_tx_pending  <= 0;
              r_tx_was_busy <= 0;
              r_bs_step     <= r_bs_step + 1;
            end
          end else begin
            // Start next character or finish
            case (r_bs_step)
              2'd0: begin
                r_tx_data    <= 8'h08;  // BS
                r_tx_start   <= 1;
                r_tx_pending <= 1;
              end
              2'd1: begin
                r_tx_data    <= 8'h20;  // Space
                r_tx_start   <= 1;
                r_tx_pending <= 1;
              end
              2'd2: begin
                r_tx_data    <= 8'h08;  // BS
                r_tx_start   <= 1;
                r_tx_pending <= 1;
              end
              2'd3: begin
                // All three chars sent
                r_state   <= IDLE;
                r_bs_step <= 2'd0;
              end
            endcase
          end
        end

        default: r_state <= IDLE;
      endcase
    end
  end

  // LED shows TX activity
  assign o_LED_1 = w_tx_busy;

endmodule
