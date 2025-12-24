// UART Transmitter Module
// 8N1 format: 8 data bits, no parity, 1 stop bit

module uart_tx #(
  parameter CLK_FREQ = 25_000_000,
  parameter BAUD     = 115200
)(
  input  wire       i_clk,
  input  wire       i_rst,
  input  wire [7:0] i_tx_data,
  input  wire       i_tx_start,
  output reg        o_tx_out,
  output reg        o_tx_busy
);

  localparam CLKS_PER_BIT = CLK_FREQ / BAUD;

  localparam IDLE      = 2'd0;
  localparam START_BIT = 2'd1;
  localparam DATA_BITS = 2'd2;
  localparam STOP_BIT  = 2'd3;

  reg [1:0]  r_state;
  reg [15:0] r_clk_count;
  reg [2:0]  r_bit_index;
  reg [7:0]  r_tx_shift;

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_state     <= IDLE;
      o_tx_out    <= 1'b1;
      o_tx_busy   <= 1'b0;
      r_clk_count <= 0;
      r_bit_index <= 0;
      r_tx_shift  <= 0;
    end else begin
      case (r_state)
        IDLE: begin
          o_tx_out    <= 1'b1;
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
          o_tx_out <= 1'b0;
          if (r_clk_count < CLKS_PER_BIT - 1) begin
            r_clk_count <= r_clk_count + 1;
          end else begin
            r_clk_count <= 0;
            r_state     <= DATA_BITS;
          end
        end

        DATA_BITS: begin
          o_tx_out <= r_tx_shift[0];
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
          o_tx_out <= 1'b1;
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
