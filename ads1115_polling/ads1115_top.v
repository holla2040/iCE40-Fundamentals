// ADS1115 I2C ADC Top Module (Polling Version)
// Reads ADC via polling, outputs hex values via UART

module ads1115_top (
  input  wire i_Clk,

  // I2C (directly to PMOD)
  output wire io_I2C_SCL,
  output wire io_I2C_SDA,
  output wire o_ADDR,

  // UART
  output wire o_UART_TX,

  // Status LEDs
  output wire o_LED_1,
  output wire o_LED_2,
  output wire o_LED_3,
  output wire o_LED_4
);

  // Parameters
  localparam CLK_FREQ = 25_000_000;
  localparam I2C_FREQ = 100_000;
  localparam BAUD     = 115200;

  // Reset generator (simple power-on reset)
  reg [7:0] rst_cnt = 0;
  wire rst = !rst_cnt[7];
  always @(posedge i_Clk)
    if (!rst_cnt[7])
      rst_cnt <= rst_cnt + 1;

  // ADC signals
  wire [15:0] adc_data;
  wire        adc_valid;
  wire        adc_error;
  wire        scl_out;
  wire        sda_out;

  // SDA is directly driven (iCE40 pins are push-pull by default)
  // For open-drain: use SB_IO with PIN_TYPE=6'b1010_01
  wire sda_in;

  // Use iCE40 open-drain for SDA
  SB_IO #(
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b1)
  ) sda_io (
    .PACKAGE_PIN(io_I2C_SDA),
    .OUTPUT_ENABLE(!sda_out),  // Drive low when sda_out=0
    .D_OUT_0(1'b0),
    .D_IN_0(sda_in)
  );

  // SCL also open-drain for clock stretching support
  SB_IO #(
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b1)
  ) scl_io (
    .PACKAGE_PIN(io_I2C_SCL),
    .OUTPUT_ENABLE(!scl_out),  // Drive low when scl_out=0
    .D_OUT_0(1'b0)
  );

  // ADDR pin directly controls ADS1115 address
  // Low = 0x48, High = 0x49
  assign o_ADDR = 1'b0;

  // ADS1115 driver
  ads1115 #(
    .CLK_FREQ(CLK_FREQ),
    .I2C_FREQ(I2C_FREQ)
  ) adc (
    .clk(i_Clk),
    .rst(rst),
    .o_data(adc_data),
    .o_valid(adc_valid),
    .o_error(adc_error),
    .o_scl(scl_out),
    .o_sda(sda_out),
    .i_sda(sda_in)
  );

  // UART transmitter
  reg  [7:0] tx_data;
  reg        tx_start;
  wire       tx_busy;

  uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD(BAUD)
  ) uart (
    .clk(i_Clk),
    .rst(rst),
    .tx_data(tx_data),
    .tx_start(tx_start),
    .tx_out(o_UART_TX),
    .tx_busy(tx_busy)
  );

  // Hex to ASCII converters
  wire [7:0] hex0, hex1, hex2, hex3;
  hex_to_ascii h0 (.i_hex(adc_data[3:0]),   .o_ascii(hex0));
  hex_to_ascii h1 (.i_hex(adc_data[7:4]),   .o_ascii(hex1));
  hex_to_ascii h2 (.i_hex(adc_data[11:8]),  .o_ascii(hex2));
  hex_to_ascii h3 (.i_hex(adc_data[15:12]), .o_ascii(hex3));

  // UART output state machine
  // Format: "XXXX\r\n" (4 hex digits + CR + LF) or "E\r\n" on error
  localparam TX_IDLE  = 3'd0;
  localparam TX_HEX3  = 3'd1;
  localparam TX_HEX2  = 3'd2;
  localparam TX_HEX1  = 3'd3;
  localparam TX_HEX0  = 3'd4;
  localparam TX_CR    = 3'd5;
  localparam TX_LF    = 3'd6;
  localparam TX_ERR_E = 3'd7;

  reg [2:0] tx_state;
  reg [15:0] tx_adc_data;
  reg error_sent;

  always @(posedge i_Clk) begin
    if (rst) begin
      tx_state    <= TX_IDLE;
      tx_start    <= 0;
      tx_data     <= 0;
      tx_adc_data <= 0;
      error_sent  <= 0;
    end else begin
      tx_start <= 0;

      case (tx_state)
        TX_IDLE: begin
          if (adc_error && !error_sent) begin
            tx_state <= TX_ERR_E;
          end else if (adc_valid) begin
            tx_adc_data <= adc_data;
            tx_state    <= TX_HEX3;
          end
        end

        TX_HEX3: begin
          if (!tx_busy && !tx_start) begin
            tx_data  <= hex3;
            tx_start <= 1;
            tx_state <= TX_HEX2;
          end
        end

        TX_HEX2: begin
          if (!tx_busy && !tx_start) begin
            tx_data  <= hex2;
            tx_start <= 1;
            tx_state <= TX_HEX1;
          end
        end

        TX_HEX1: begin
          if (!tx_busy && !tx_start) begin
            tx_data  <= hex1;
            tx_start <= 1;
            tx_state <= TX_HEX0;
          end
        end

        TX_HEX0: begin
          if (!tx_busy && !tx_start) begin
            tx_data  <= hex0;
            tx_start <= 1;
            tx_state <= TX_CR;
          end
        end

        TX_CR: begin
          if (!tx_busy && !tx_start) begin
            tx_data  <= 8'h0D;  // CR
            tx_start <= 1;
            tx_state <= TX_LF;
          end
        end

        TX_LF: begin
          if (!tx_busy && !tx_start) begin
            tx_data  <= 8'h0A;  // LF
            tx_start <= 1;
            tx_state <= TX_IDLE;
          end
        end

        TX_ERR_E: begin
          if (!tx_busy && !tx_start) begin
            tx_data    <= "E";
            tx_start   <= 1;
            error_sent <= 1;
            tx_state   <= TX_CR;
          end
        end

        default: tx_state <= TX_IDLE;
      endcase
    end
  end

  // Status LEDs
  // Error: all LEDs on
  // Normal: LED1 blinks on reading, LED2-4 show upper bits
  reg [23:0] led_cnt;
  always @(posedge i_Clk)
    if (rst)
      led_cnt <= 0;
    else if (adc_valid)
      led_cnt <= 24'hFFFFFF;
    else if (led_cnt > 0)
      led_cnt <= led_cnt - 1;

  // LED1: blinks on each reading
  // LED2-4: upper bits of ADC value (shows magnitude)
  assign o_LED_1 = adc_error ? 1'b1 : led_cnt[23];
  assign o_LED_2 = adc_error ? 1'b1 : adc_data[15];
  assign o_LED_3 = adc_error ? 1'b1 : adc_data[14];
  assign o_LED_4 = adc_error ? 1'b1 : adc_data[13];

endmodule
