// UART Receiver Module
// 8N1 format: 8 data bits, no parity, 1 stop bit

module uart_rx #(
  parameter CLK_FREQ = 25_000_000,
  parameter BAUD     = 115200
)(
  input  wire       clk,
  input  wire       rst,
  input  wire       rx_in,
  output reg  [7:0] rx_data,
  output reg        rx_valid
);

  localparam CLKS_PER_BIT = CLK_FREQ / BAUD;

  localparam IDLE      = 3'd0;
  localparam START_BIT = 3'd1;
  localparam DATA_BITS = 3'd2;
  localparam STOP_BIT  = 3'd3;

  reg [2:0]  state;
  reg [15:0] clk_count;
  reg [2:0]  bit_index;
  reg [7:0]  rx_shift;

  // Synchronize rx_in to avoid metastability
  reg [1:0] rx_sync;
  always @(posedge clk) begin
    rx_sync <= {rx_sync[0], rx_in};
  end
  wire rx_bit = rx_sync[1];

  always @(posedge clk) begin
    if (rst) begin
      state     <= IDLE;
      clk_count <= 0;
      bit_index <= 0;
      rx_shift  <= 0;
      rx_data   <= 0;
      rx_valid  <= 0;
    end else begin
      rx_valid <= 0;

      case (state)
        IDLE: begin
          clk_count <= 0;
          bit_index <= 0;
          // Detect start bit (falling edge to low)
          if (rx_bit == 0) begin
            state <= START_BIT;
          end
        end

        START_BIT: begin
          // Sample at middle of start bit
          if (clk_count < (CLKS_PER_BIT - 1) / 2) begin
            clk_count <= clk_count + 1;
          end else begin
            clk_count <= 0;
            // Verify still low (valid start bit)
            if (rx_bit == 0) begin
              state <= DATA_BITS;
            end else begin
              state <= IDLE;
            end
          end
        end

        DATA_BITS: begin
          if (clk_count < CLKS_PER_BIT - 1) begin
            clk_count <= clk_count + 1;
          end else begin
            clk_count <= 0;
            rx_shift  <= {rx_bit, rx_shift[7:1]};  // LSB first

            if (bit_index < 7) begin
              bit_index <= bit_index + 1;
            end else begin
              bit_index <= 0;
              state     <= STOP_BIT;
            end
          end
        end

        STOP_BIT: begin
          if (clk_count < CLKS_PER_BIT - 1) begin
            clk_count <= clk_count + 1;
          end else begin
            clk_count <= 0;
            // Output data (stop bit should be high)
            if (rx_bit == 1) begin
              rx_data  <= rx_shift;
              rx_valid <= 1;
            end
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
