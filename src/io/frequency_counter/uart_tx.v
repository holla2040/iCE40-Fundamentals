// UART Transmitter Module
// 8N1 format: 8 data bits, no parity, 1 stop bit

module uart_tx #(
  parameter CLK_FREQ = 12_000_000,  // 12 MHz clock
  parameter BAUD     = 115200       // Baud rate
)(
  input  wire       i_clk,
  input  wire       i_rst,
  input  wire [7:0] i_tx_data,       // Byte to transmit
  input  wire       i_tx_start,      // Pulse high to start transmission
  output reg        o_tx_out,        // Serial output (directly to pin)
  output reg        o_tx_busy        // High while transmitting
);

  // Calculate clocks per bit
  localparam CLKS_PER_BIT = CLK_FREQ / BAUD;

  // State machine states
  localparam IDLE      = 3'd0;
  localparam START_BIT = 3'd1;
  localparam DATA_BITS = 3'd2;
  localparam STOP_BIT  = 3'd3;

  reg [2:0]  r_state;
  reg [15:0] r_clk_count;      // Clock counter for baud timing
  reg [2:0]  r_bit_index;      // Which bit we're sending (0-7)
  reg [7:0]  r_tx_shift;       // Shift register for data

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_state     <= IDLE;
      o_tx_out    <= 1'b1;     // Idle high
      o_tx_busy   <= 1'b0;
      r_clk_count <= 0;
      r_bit_index <= 0;
      r_tx_shift  <= 0;
    end else begin
      case (r_state)
        IDLE: begin
          o_tx_out    <= 1'b1;  // Line idle high
          o_tx_busy   <= 1'b0;
          r_clk_count <= 0;
          r_bit_index <= 0;

          if (i_tx_start) begin
            r_tx_shift <= i_tx_data;
            o_tx_busy  <= 1'b1;
            r_state    <= START_BIT;
          end
        end

        START_BIT: begin
          o_tx_out <= 1'b0;  // Start bit is low

          if (r_clk_count < CLKS_PER_BIT - 1) begin
            r_clk_count <= r_clk_count + 1;
          end else begin
            r_clk_count <= 0;
            r_state     <= DATA_BITS;
          end
        end

        DATA_BITS: begin
          o_tx_out <= r_tx_shift[0];  // LSB first

          if (r_clk_count < CLKS_PER_BIT - 1) begin
            r_clk_count <= r_clk_count + 1;
          end else begin
            r_clk_count <= 0;
            r_tx_shift  <= r_tx_shift >> 1;

            if (r_bit_index < 7) begin
              r_bit_index <= r_bit_index + 1;
            end else begin
              r_bit_index <= 0;
              r_state     <= STOP_BIT;
            end
          end
        end

        STOP_BIT: begin
          o_tx_out <= 1'b1;  // Stop bit is high

          if (r_clk_count < CLKS_PER_BIT - 1) begin
            r_clk_count <= r_clk_count + 1;
          end else begin
            r_clk_count <= 0;
            r_state     <= IDLE;
          end
        end

        default: r_state <= IDLE;
      endcase
    end
  end

endmodule
