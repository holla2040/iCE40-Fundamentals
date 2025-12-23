// Serial UART RX Demo for Nandland Go Board
// Receives characters over USB serial at 115200 baud, 8N1
// Send '0' to turn off LED 1, '1' to turn on LED 1

module top (
  input  wire i_Clk,
  input  wire i_UART_RX,
  output reg  o_LED_1
);

  // Reset generation
  reg [3:0] rst_count = 4'hF;
  wire rst = rst_count != 0;
  always @(posedge i_Clk) begin
    if (rst_count != 0)
      rst_count <= rst_count - 1;
  end

  // UART receiver
  wire [7:0] rx_data;
  wire       rx_valid;

  uart_rx #(
    .CLK_FREQ(25_000_000),
    .BAUD(115200)
  ) uart_inst (
    .clk(i_Clk),
    .rst(rst),
    .rx_in(i_UART_RX),
    .rx_data(rx_data),
    .rx_valid(rx_valid)
  );

  // LED control: '0' = off, '1' = on
  always @(posedge i_Clk) begin
    if (rst) begin
      o_LED_1 <= 0;
    end else if (rx_valid) begin
      if (rx_data == "0")
        o_LED_1 <= 0;
      else if (rx_data == "1")
        o_LED_1 <= 1;
    end
  end

endmodule
