// ADS1115 16-bit I2C ADC Driver (Interrupt Version)
// Continuous conversion mode on AIN0, 860 SPS, gain=1 (±4.096V)
// Uses ALERT/RDY pin for conversion ready signal

module ads1115 #(
  parameter CLK_FREQ = 25_000_000,
  parameter I2C_FREQ = 100_000
)(
  input  wire        i_clk,
  input  wire        i_rst,

  // Data output
  output reg  [15:0] o_data,       // ADC reading (signed)
  output reg         o_valid,      // Data valid pulse
  output reg         o_error,      // I2C error (no ACK)

  // ALERT/RDY input
  input  wire        i_alert,      // Conversion ready (active low)

  // I2C interface
  output wire        o_scl,
  output wire        o_sda,
  input  wire        i_sda
);

  // ADS1115 I2C address (ADDR pin to GND)
  localparam ADDR = 7'h48;

  // Register addresses
  localparam REG_CONV   = 8'h00;
  localparam REG_CONFIG = 8'h01;
  localparam REG_LO     = 8'h02;
  localparam REG_HI     = 8'h03;

  // Config register value:
  // OS=1, MUX=100 (AIN0), PGA=001 (±4.096V, gain=1), MODE=0 (continuous)
  // DR=111 (860 SPS), COMP_MODE=0, COMP_POL=0, COMP_LAT=0, COMP_QUE=00
  localparam CONFIG_MSB = 8'hC2;
  localparam CONFIG_LSB = 8'hE0;  // COMP_QUE=00 enables comparator

  // For ALERT/RDY to work as data ready:
  // Hi_thresh = 0x8000, Lo_thresh = 0x7FFF
  localparam HI_THRESH_MSB = 8'h80;
  localparam HI_THRESH_LSB = 8'h00;
  localparam LO_THRESH_MSB = 8'h7F;
  localparam LO_THRESH_LSB = 8'hFF;

  // States
  localparam S_INIT           = 4'd0;
  localparam S_WRITE_CONFIG   = 4'd1;
  localparam S_WRITE_LO       = 4'd2;
  localparam S_WRITE_HI       = 4'd3;
  localparam S_WAIT_ALERT     = 4'd4;
  localparam S_READ_START     = 4'd5;
  localparam S_READ_RESTART   = 4'd6;
  localparam S_ERROR          = 4'd7;

  reg [3:0] r_state;
  reg [2:0] r_step;
  reg [15:0] r_read_data;
  reg r_alert_prev;

  // I2C master signals
  reg        r_i2c_start;
  reg        r_i2c_stop;
  reg  [6:0] r_i2c_addr;
  reg        r_i2c_rw;
  reg  [7:0] r_i2c_wdata;
  reg        r_i2c_wvalid;
  reg        r_i2c_rready;
  reg        r_i2c_ack_send;

  wire [7:0] w_i2c_rdata;
  wire       w_i2c_rvalid;
  wire       w_i2c_wready;
  wire       w_i2c_ack_recv;
  wire       w_i2c_busy;
  wire       w_i2c_done;

  i2c_master #(
    .CLK_FREQ(CLK_FREQ),
    .I2C_FREQ(I2C_FREQ)
  ) i2c (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_addr(r_i2c_addr),
    .i_rw(r_i2c_rw),
    .i_start(r_i2c_start),
    .i_wdata(r_i2c_wdata),
    .i_wvalid(r_i2c_wvalid),
    .i_rready(r_i2c_rready),
    .i_stop(r_i2c_stop),
    .i_ack_send(r_i2c_ack_send),
    .o_rdata(w_i2c_rdata),
    .o_rvalid(w_i2c_rvalid),
    .o_wready(w_i2c_wready),
    .o_ack_recv(w_i2c_ack_recv),
    .o_busy(w_i2c_busy),
    .o_done(w_i2c_done),
    .o_scl(o_scl),
    .o_sda(o_sda),
    .i_sda(i_sda)
  );

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_state        <= S_INIT;
      r_step         <= 0;
      o_data         <= 0;
      o_valid        <= 0;
      o_error        <= 0;
      r_read_data    <= 0;
      r_alert_prev   <= 1;
      r_i2c_start    <= 0;
      r_i2c_stop     <= 0;
      r_i2c_addr     <= 0;
      r_i2c_rw       <= 0;
      r_i2c_wdata    <= 0;
      r_i2c_wvalid   <= 0;
      r_i2c_rready   <= 0;
      r_i2c_ack_send <= 0;
    end else begin
      // Default: clear pulses
      r_i2c_start  <= 0;
      r_i2c_stop   <= 0;
      r_i2c_wvalid <= 0;
      r_i2c_rready <= 0;
      o_valid      <= 0;

      // Track alert edge
      r_alert_prev <= i_alert;

      case (r_state)
        S_INIT: begin
          r_step  <= 0;
          r_state <= S_WRITE_CONFIG;
        end

        S_WRITE_CONFIG: begin
          case (r_step)
            0: begin
              r_i2c_addr  <= ADDR;
              r_i2c_rw    <= 0;  // Write
              r_i2c_start <= 1;
              r_step      <= 1;
            end
            1: if (w_i2c_done) begin
              if (w_i2c_ack_recv) begin
                // NACK - device not found
                r_i2c_stop <= 1;
                r_state    <= S_ERROR;
              end else begin
                r_i2c_wdata  <= REG_CONFIG;
                r_i2c_wvalid <= 1;
                r_step       <= 2;
              end
            end
            2: if (w_i2c_done) begin
              r_i2c_wdata  <= CONFIG_MSB;
              r_i2c_wvalid <= 1;
              r_step       <= 3;
            end
            3: if (w_i2c_done) begin
              r_i2c_wdata  <= CONFIG_LSB;
              r_i2c_wvalid <= 1;
              r_step       <= 4;
            end
            4: if (w_i2c_done) begin
              r_i2c_stop <= 1;
              r_step     <= 5;
            end
            5: if (w_i2c_done) begin
              r_step  <= 0;
              r_state <= S_WRITE_LO;
            end
            default: r_step <= 0;
          endcase
        end

        S_WRITE_LO: begin
          case (r_step)
            0: begin
              r_i2c_addr  <= ADDR;
              r_i2c_rw    <= 0;
              r_i2c_start <= 1;
              r_step      <= 1;
            end
            1: if (w_i2c_done) begin
              r_i2c_wdata  <= REG_LO;
              r_i2c_wvalid <= 1;
              r_step       <= 2;
            end
            2: if (w_i2c_done) begin
              r_i2c_wdata  <= LO_THRESH_MSB;
              r_i2c_wvalid <= 1;
              r_step       <= 3;
            end
            3: if (w_i2c_done) begin
              r_i2c_wdata  <= LO_THRESH_LSB;
              r_i2c_wvalid <= 1;
              r_step       <= 4;
            end
            4: if (w_i2c_done) begin
              r_i2c_stop <= 1;
              r_step     <= 5;
            end
            5: if (w_i2c_done) begin
              r_step  <= 0;
              r_state <= S_WRITE_HI;
            end
            default: r_step <= 0;
          endcase
        end

        S_WRITE_HI: begin
          case (r_step)
            0: begin
              r_i2c_addr  <= ADDR;
              r_i2c_rw    <= 0;
              r_i2c_start <= 1;
              r_step      <= 1;
            end
            1: if (w_i2c_done) begin
              r_i2c_wdata  <= REG_HI;
              r_i2c_wvalid <= 1;
              r_step       <= 2;
            end
            2: if (w_i2c_done) begin
              r_i2c_wdata  <= HI_THRESH_MSB;
              r_i2c_wvalid <= 1;
              r_step       <= 3;
            end
            3: if (w_i2c_done) begin
              r_i2c_wdata  <= HI_THRESH_LSB;
              r_i2c_wvalid <= 1;
              r_step       <= 4;
            end
            4: if (w_i2c_done) begin
              r_i2c_stop <= 1;
              r_step     <= 5;
            end
            5: if (w_i2c_done) begin
              r_step  <= 0;
              r_state <= S_WAIT_ALERT;
            end
            default: r_step <= 0;
          endcase
        end

        S_WAIT_ALERT: begin
          // Wait for falling edge on ALERT (conversion ready)
          if (r_alert_prev && !i_alert) begin
            r_state <= S_READ_START;
          end
        end

        S_READ_START: begin
          case (r_step)
            0: begin
              r_i2c_addr  <= ADDR;
              r_i2c_rw    <= 0;  // Write to set pointer
              r_i2c_start <= 1;
              r_step      <= 1;
            end
            1: if (w_i2c_done) begin
              r_i2c_wdata  <= REG_CONV;
              r_i2c_wvalid <= 1;
              r_step       <= 2;
            end
            2: if (w_i2c_done) begin
              r_step  <= 0;
              r_state <= S_READ_RESTART;
            end
            default: r_step <= 0;
          endcase
        end

        S_READ_RESTART: begin
          case (r_step)
            0: begin
              r_i2c_addr  <= ADDR;
              r_i2c_rw    <= 1;  // Read
              r_i2c_start <= 1;  // Repeated start
              r_step      <= 1;
            end
            1: begin
              // Keep rready high until we get first byte
              r_i2c_rready   <= 1;
              r_i2c_ack_send <= 0;  // ACK after first byte
              if (w_i2c_rvalid) begin
                r_read_data[15:8] <= w_i2c_rdata;
                r_step            <= 2;
              end
            end
            2: begin
              // Keep rready high until we get second byte
              r_i2c_rready   <= 1;
              r_i2c_ack_send <= 1;  // NACK after second byte
              if (w_i2c_rvalid) begin
                r_read_data[7:0] <= w_i2c_rdata;
                r_i2c_stop       <= 1;
                r_step           <= 3;
              end
            end
            3: if (w_i2c_done) begin
              o_data  <= r_read_data;
              o_valid <= 1;
              r_step  <= 0;
              r_state <= S_WAIT_ALERT;
            end
            default: r_step <= 0;
          endcase
        end

        S_ERROR: begin
          // Wait for stop to complete, then signal error
          if (w_i2c_done || !w_i2c_busy) begin
            o_error <= 1;
            // Stay in error state (requires reset to retry)
          end
        end

        default: r_state <= S_INIT;
      endcase
    end
  end

endmodule
