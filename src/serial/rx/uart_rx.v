// UART Receiver Module
// 8N1 format: 8 data bits, no parity, 1 stop bit

module uart_rx #(
  parameter CLK_FREQ = 25_000_000,
  parameter BAUD     = 115200
)(
  input  wire       i_clk,
  input  wire       i_rst,
  input  wire       i_rx_in,
  output reg  [7:0] o_rx_data,
  output reg        o_rx_valid
);

  localparam CLKS_PER_BIT = CLK_FREQ / BAUD;

  localparam IDLE      = 3'd0;
  localparam START_BIT = 3'd1;
  localparam DATA_BITS = 3'd2;
  localparam STOP_BIT  = 3'd3;

  reg [2:0]  r_state;
  reg [15:0] r_clk_count;
  reg [2:0]  r_bit_index;
  reg [7:0]  r_rx_shift;

  // Synchronize i_rx_in to avoid metastability
  reg [1:0] r_rx_sync;
  always @(posedge i_clk) begin
    r_rx_sync <= {r_rx_sync[0], i_rx_in};
  end
  wire w_rx_bit = r_rx_sync[1];

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_state     <= IDLE;
      r_clk_count <= 0;
      r_bit_index <= 0;
      r_rx_shift  <= 0;
      o_rx_data   <= 0;
      o_rx_valid  <= 0;
    end else begin
      o_rx_valid <= 0;

      case (r_state)
        IDLE: begin
          r_clk_count <= 0;
          r_bit_index <= 0;
          // Detect start bit (falling edge to low)
          if (w_rx_bit == 0) begin
            r_state <= START_BIT;
          end
        end

        START_BIT: begin
          // Sample at middle of start bit
          if (r_clk_count < (CLKS_PER_BIT - 1) / 2) begin
            r_clk_count <= r_clk_count + 1;
          end else begin
            r_clk_count <= 0;
            // Verify still low (valid start bit)
            if (w_rx_bit == 0) begin
              r_state <= DATA_BITS;
            end else begin
              r_state <= IDLE;
            end
          end
        end

        DATA_BITS: begin
          if (r_clk_count < CLKS_PER_BIT - 1) begin
            r_clk_count <= r_clk_count + 1;
          end else begin
            r_clk_count <= 0;
            r_rx_shift  <= {w_rx_bit, r_rx_shift[7:1]};  // LSB first

            if (r_bit_index < 7) begin
              r_bit_index <= r_bit_index + 1;
            end else begin
              r_bit_index <= 0;
              r_state     <= STOP_BIT;
            end
          end
        end

        STOP_BIT: begin
          if (r_clk_count < CLKS_PER_BIT - 1) begin
            r_clk_count <= r_clk_count + 1;
          end else begin
            r_clk_count <= 0;
            // Output data (stop bit should be high)
            if (w_rx_bit == 1) begin
              o_rx_data  <= r_rx_shift;
              o_rx_valid <= 1;
            end
            r_state <= IDLE;
          end
        end

        default: r_state <= IDLE;
      endcase
    end
  end

endmodule
