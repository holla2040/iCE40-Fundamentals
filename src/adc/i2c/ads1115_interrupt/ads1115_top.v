// ADS1115 I2C ADC Top Module (Interrupt Version)
// Uses ALERT/RDY pin for conversion ready, outputs hex values via UART

module ads1115_top (
  input  wire i_Clk,

  // I2C (directly to PMOD)
  inout  wire io_PMOD_4,        // SCL
  inout  wire io_PMOD_3,        // SDA
  input  wire io_PMOD_1,        // ALERT
  output wire io_PMOD_2,        // ADDR

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
  reg [7:0] r_rst_cnt = 0;
  wire w_rst = !r_rst_cnt[7];
  always @(posedge i_Clk)
    if (!r_rst_cnt[7])
      r_rst_cnt <= r_rst_cnt + 1;

  // ADC signals
  wire [15:0] w_adc_data;
  wire        w_adc_valid;
  wire        w_adc_error;
  wire        w_scl_out;
  wire        w_sda_out;

  // SDA is directly driven (iCE40 pins are push-pull by default)
  // For open-drain: use SB_IO with PIN_TYPE=6'b1010_01
  wire w_sda_in;

  // Use iCE40 open-drain for SDA
  SB_IO #(
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b1)
  ) sda_io (
    .PACKAGE_PIN(io_PMOD_3),
    .OUTPUT_ENABLE(!w_sda_out),  // Drive low when w_sda_out=0
    .D_OUT_0(1'b0),
    .D_IN_0(w_sda_in)
  );

  // SCL also open-drain for clock stretching support
  SB_IO #(
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b1)
  ) scl_io (
    .PACKAGE_PIN(io_PMOD_4),
    .OUTPUT_ENABLE(!w_scl_out),  // Drive low when w_scl_out=0
    .D_OUT_0(1'b0)
  );

  // ADDR pin directly controls ADS1115 address
  // Low = 0x48, High = 0x49
  assign io_PMOD_2 = 1'b0;

  // ADS1115 driver
  ads1115 #(
    .CLK_FREQ(CLK_FREQ),
    .I2C_FREQ(I2C_FREQ)
  ) adc (
    .i_clk(i_Clk),
    .i_rst(w_rst),
    .o_data(w_adc_data),
    .o_valid(w_adc_valid),
    .o_error(w_adc_error),
    .i_alert(io_PMOD_1),
    .o_scl(w_scl_out),
    .o_sda(w_sda_out),
    .i_sda(w_sda_in)
  );

  // UART transmitter
  reg  [7:0] r_tx_data;
  reg        r_tx_start;
  wire       w_tx_busy;

  uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD(BAUD)
  ) uart (
    .i_clk(i_Clk),
    .i_rst(w_rst),
    .i_tx_data(r_tx_data),
    .i_tx_start(r_tx_start),
    .o_tx_out(o_UART_TX),
    .o_tx_busy(w_tx_busy)
  );

  // Hex to ASCII converters
  wire [7:0] w_hex0, w_hex1, w_hex2, w_hex3;
  hex_to_ascii h0 (.i_hex(w_adc_data[3:0]),   .o_ascii(w_hex0));
  hex_to_ascii h1 (.i_hex(w_adc_data[7:4]),   .o_ascii(w_hex1));
  hex_to_ascii h2 (.i_hex(w_adc_data[11:8]),  .o_ascii(w_hex2));
  hex_to_ascii h3 (.i_hex(w_adc_data[15:12]), .o_ascii(w_hex3));

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

  reg [2:0] r_tx_state;
  reg [15:0] r_tx_adc_data;
  reg r_error_sent;

  always @(posedge i_Clk) begin
    if (w_rst) begin
      r_tx_state    <= TX_IDLE;
      r_tx_start    <= 0;
      r_tx_data     <= 0;
      r_tx_adc_data <= 0;
      r_error_sent  <= 0;
    end else begin
      r_tx_start <= 0;

      case (r_tx_state)
        TX_IDLE: begin
          if (w_adc_error && !r_error_sent) begin
            r_tx_state <= TX_ERR_E;
          end else if (w_adc_valid) begin
            r_tx_adc_data <= w_adc_data;
            r_tx_state    <= TX_HEX3;
          end
        end

        TX_HEX3: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data  <= w_hex3;
            r_tx_start <= 1;
            r_tx_state <= TX_HEX2;
          end
        end

        TX_HEX2: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data  <= w_hex2;
            r_tx_start <= 1;
            r_tx_state <= TX_HEX1;
          end
        end

        TX_HEX1: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data  <= w_hex1;
            r_tx_start <= 1;
            r_tx_state <= TX_HEX0;
          end
        end

        TX_HEX0: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data  <= w_hex0;
            r_tx_start <= 1;
            r_tx_state <= TX_CR;
          end
        end

        TX_CR: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data  <= 8'h0D;  // CR
            r_tx_start <= 1;
            r_tx_state <= TX_LF;
          end
        end

        TX_LF: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data  <= 8'h0A;  // LF
            r_tx_start <= 1;
            r_tx_state <= TX_IDLE;
          end
        end

        TX_ERR_E: begin
          if (!w_tx_busy && !r_tx_start) begin
            r_tx_data    <= "E";
            r_tx_start   <= 1;
            r_error_sent <= 1;
            r_tx_state   <= TX_CR;
          end
        end

        default: r_tx_state <= TX_IDLE;
      endcase
    end
  end

  // Status LEDs
  // Error: all LEDs on
  // Normal: LED1 blinks on reading, LED2-4 show upper bits
  reg [23:0] r_led_cnt;
  always @(posedge i_Clk)
    if (w_rst)
      r_led_cnt <= 0;
    else if (w_adc_valid)
      r_led_cnt <= 24'hFFFFFF;
    else if (r_led_cnt > 0)
      r_led_cnt <= r_led_cnt - 1;

  // LED1: blinks on each reading
  // LED2-4: bar graph (thresholds at 25%, 50%, 75% of 0-0x7FFF range)
  assign o_LED_1 = w_adc_error ? 1'b1 : r_led_cnt[23];
  assign o_LED_2 = w_adc_error ? 1'b1 : (w_adc_data >= 16'h2000);
  assign o_LED_3 = w_adc_error ? 1'b1 : (w_adc_data >= 16'h4000);
  assign o_LED_4 = w_adc_error ? 1'b1 : (w_adc_data >= 16'h6000);

endmodule
