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
  reg [3:0] rst_count = 4'hF;
  wire rst = rst_count != 0;
  always @(posedge i_Clk) begin
    if (rst_count != 0)
      rst_count <= rst_count - 1;
  end

  // UART RX signals
  wire [7:0] rx_data;
  wire       rx_valid;

  // Swap case: lowercase -> uppercase, uppercase -> lowercase
  wire is_lower = (rx_data >= "a") && (rx_data <= "z");
  wire is_upper = (rx_data >= "A") && (rx_data <= "Z");
  wire [7:0] rx_swapped = is_lower ? (rx_data - 8'h20) :
                          is_upper ? (rx_data + 8'h20) : rx_data;

  // UART TX signals
  reg  [7:0] tx_data;
  reg        tx_start;
  wire       tx_busy;

  // UART Receiver
  uart_rx #(
    .CLK_FREQ(25_000_000),
    .BAUD(115200)
  ) rx_inst (
    .clk(i_Clk),
    .rst(rst),
    .rx_in(i_UART_RX),
    .rx_data(rx_data),
    .rx_valid(rx_valid)
  );

  // UART Transmitter
  uart_tx #(
    .CLK_FREQ(25_000_000),
    .BAUD(115200)
  ) tx_inst (
    .clk(i_Clk),
    .rst(rst),
    .tx_data(tx_data),
    .tx_start(tx_start),
    .tx_out(o_UART_TX),
    .tx_busy(tx_busy)
  );

  // Detect special characters
  wire is_backspace = (rx_data == 8'h08) || (rx_data == 8'h7F);  // BS or DEL
  wire is_cr = (rx_data == 8'h0D);

  // Echo state machine
  localparam IDLE    = 3'd0;
  localparam WAIT_TX = 3'd1;
  localparam SENDING = 3'd2;
  localparam SEND_LF = 3'd3;  // Send LF after CR
  localparam SEND_BS = 3'd4;  // Backspace sequence: BS, Space, BS

  reg [2:0] state = IDLE;
  reg [7:0] echo_data;
  reg       need_lf;     // Flag: need to send LF after current char
  reg [1:0] bs_step;     // Backspace sequence step (0=BS, 1=Space, 2=BS)
  reg       tx_pending;  // TX initiated, waiting for completion
  reg       tx_was_busy; // tx_busy has been seen high since tx_start

  always @(posedge i_Clk) begin
    if (rst) begin
      state       <= IDLE;
      tx_start    <= 0;
      tx_data     <= 0;
      echo_data   <= 0;
      need_lf     <= 0;
      bs_step     <= 0;
      tx_pending  <= 0;
      tx_was_busy <= 0;
    end else begin
      tx_start <= 0;

      case (state)
        IDLE: begin
          if (rx_valid) begin
            if (is_backspace) begin
              bs_step <= 0;
              state   <= SEND_BS;
            end else begin
              echo_data <= rx_swapped;
              need_lf   <= is_cr;
              state     <= WAIT_TX;
            end
          end
        end

        WAIT_TX: begin
          if (!tx_busy) begin
            tx_data  <= echo_data;
            tx_start <= 1;
            state    <= SENDING;
          end
        end

        SENDING: begin
          if (tx_busy) begin
            // TX started, wait for completion
          end else begin
            if (need_lf) begin
              state <= SEND_LF;
            end else begin
              state <= IDLE;
            end
          end
        end

        SEND_LF: begin
          if (!tx_busy) begin
            tx_data  <= 8'h0A;  // LF
            tx_start <= 1;
            need_lf  <= 0;
            state    <= SENDING;
          end
        end

        SEND_BS: begin
          if (tx_pending) begin
            // Track when tx_busy goes high
            if (tx_busy)
              tx_was_busy <= 1;
            // TX complete when tx_busy seen high then goes low
            if (tx_was_busy && !tx_busy) begin
              tx_pending  <= 0;
              tx_was_busy <= 0;
              bs_step     <= bs_step + 1;
            end
          end else begin
            // Start next character or finish
            case (bs_step)
              2'd0: begin
                tx_data    <= 8'h08;  // BS
                tx_start   <= 1;
                tx_pending <= 1;
              end
              2'd1: begin
                tx_data    <= 8'h20;  // Space
                tx_start   <= 1;
                tx_pending <= 1;
              end
              2'd2: begin
                tx_data    <= 8'h08;  // BS
                tx_start   <= 1;
                tx_pending <= 1;
              end
              2'd3: begin
                // All three chars sent
                state   <= IDLE;
                bs_step <= 2'd0;
              end
            endcase
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // LED shows TX activity
  assign o_LED_1 = tx_busy;

endmodule
