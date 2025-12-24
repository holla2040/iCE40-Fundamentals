// Serial UART Demo for Nandland Go Board
// Sends "Hello from FPGA!" message repeatedly over USB serial
// Connect at 115200 baud, 8N1

module top (
  input  wire i_Clk,
  output wire o_UART_TX
);

  // Message to send: "Hello from FPGA!" + marker + CR + LF
  localparam MSG_LEN = 19;
  reg [7:0] r_message [0:15];  // Base message without marker/CR/LF
  initial begin
    r_message[0]  = "H";
    r_message[1]  = "e";
    r_message[2]  = "l";
    r_message[3]  = "l";
    r_message[4]  = "o";
    r_message[5]  = " ";
    r_message[6]  = "f";
    r_message[7]  = "r";
    r_message[8]  = "o";
    r_message[9]  = "m";
    r_message[10] = " ";
    r_message[11] = "F";
    r_message[12] = "P";
    r_message[13] = "G";
    r_message[14] = "A";
    r_message[15] = "!";
  end

  // Even/odd toggle: dot on even, dash on odd
  reg r_toggle = 0;

  // Reset generation (simple power-on reset)
  reg [3:0] r_rst_count = 4'hF;
  wire w_rst = r_rst_count != 0;
  always @(posedge i_Clk) begin
    if (r_rst_count != 0)
      r_rst_count <= r_rst_count - 1;
  end

  // UART transmitter signals
  reg  [7:0] r_tx_data;
  reg        r_tx_start;
  wire       w_tx_busy;

  // Instantiate UART transmitter
  uart_tx #(
    .CLK_FREQ(25_000_000),  // Nandland Go Board has 25 MHz clock
    .BAUD(115200)
  ) uart_inst (
    .i_clk(i_Clk),
    .i_rst(w_rst),
    .i_tx_data(r_tx_data),
    .i_tx_start(r_tx_start),
    .o_tx_out(o_UART_TX),
    .o_tx_busy(w_tx_busy)
  );

  // State machine for sending message
  localparam WAIT_DELAY = 3'd0;
  localparam LOAD_CHAR  = 3'd1;
  localparam SEND_CHAR  = 3'd2;
  localparam WAIT_DONE  = 3'd3;

  reg [2:0]  r_state = WAIT_DELAY;
  reg [4:0]  r_char_index = 0;
  reg [24:0] r_delay_count = 0;

  // Delay between messages: ~1 second at 25 MHz
  localparam DELAY_1SEC = 25'd25_000_000;

  always @(posedge i_Clk) begin
    if (w_rst) begin
      r_state       <= WAIT_DELAY;
      r_char_index  <= 0;
      r_delay_count <= 0;
      r_tx_start    <= 0;
      r_tx_data     <= 0;
      r_toggle      <= 0;
    end else begin
      r_tx_start <= 0;  // Default: no start pulse

      case (r_state)
        WAIT_DELAY: begin
          if (r_delay_count < DELAY_1SEC) begin
            r_delay_count <= r_delay_count + 1;
          end else begin
            r_delay_count <= 0;
            r_char_index  <= 0;
            r_state       <= LOAD_CHAR;
          end
        end

        LOAD_CHAR: begin
          if (r_char_index < 16) begin
            r_tx_data <= r_message[r_char_index];
            r_state   <= SEND_CHAR;
          end else if (r_char_index == 16) begin
            r_tx_data <= r_toggle ? "-" : ".";
            r_state   <= SEND_CHAR;
          end else if (r_char_index == 17) begin
            r_tx_data <= 8'h0D;  // CR
            r_state   <= SEND_CHAR;
          end else if (r_char_index == 18) begin
            r_tx_data <= 8'h0A;  // LF
            r_state   <= SEND_CHAR;
          end else begin
            r_toggle <= ~r_toggle;
            r_state  <= WAIT_DELAY;
          end
        end

        SEND_CHAR: begin
          if (!w_tx_busy) begin
            r_tx_start <= 1;
            r_state    <= WAIT_DONE;
          end
        end

        WAIT_DONE: begin
          if (w_tx_busy) begin
            // Transmission started, wait for it to complete
          end else if (!r_tx_start) begin
            // Transmission complete
            r_char_index <= r_char_index + 1;
            r_state      <= LOAD_CHAR;
          end
        end

        default: r_state <= WAIT_DELAY;
      endcase
    end
  end

endmodule
