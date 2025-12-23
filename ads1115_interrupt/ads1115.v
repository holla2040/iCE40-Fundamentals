// ADS1115 16-bit I2C ADC Driver (Interrupt Version)
// Continuous conversion mode on AIN0, 860 SPS, gain=1 (±4.096V)
// Uses ALERT/RDY pin for conversion ready signal

module ads1115 #(
  parameter CLK_FREQ = 25_000_000,
  parameter I2C_FREQ = 100_000
)(
  input  wire        clk,
  input  wire        rst,

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

  reg [3:0] state;
  reg [2:0] step;
  reg [15:0] read_data;
  reg alert_prev;

  // I2C master signals
  reg        i2c_start;
  reg        i2c_stop;
  reg  [6:0] i2c_addr;
  reg        i2c_rw;
  reg  [7:0] i2c_wdata;
  reg        i2c_wvalid;
  reg        i2c_rready;
  reg        i2c_ack_send;

  wire [7:0] i2c_rdata;
  wire       i2c_rvalid;
  wire       i2c_wready;
  wire       i2c_ack_recv;
  wire       i2c_busy;
  wire       i2c_done;

  i2c_master #(
    .CLK_FREQ(CLK_FREQ),
    .I2C_FREQ(I2C_FREQ)
  ) i2c (
    .clk(clk),
    .rst(rst),
    .i_addr(i2c_addr),
    .i_rw(i2c_rw),
    .i_start(i2c_start),
    .i_wdata(i2c_wdata),
    .i_wvalid(i2c_wvalid),
    .i_rready(i2c_rready),
    .i_stop(i2c_stop),
    .i_ack_send(i2c_ack_send),
    .o_rdata(i2c_rdata),
    .o_rvalid(i2c_rvalid),
    .o_wready(i2c_wready),
    .o_ack_recv(i2c_ack_recv),
    .o_busy(i2c_busy),
    .o_done(i2c_done),
    .o_scl(o_scl),
    .o_sda(o_sda),
    .i_sda(i_sda)
  );

  always @(posedge clk) begin
    if (rst) begin
      state       <= S_INIT;
      step        <= 0;
      o_data      <= 0;
      o_valid     <= 0;
      o_error     <= 0;
      read_data   <= 0;
      alert_prev  <= 1;
      i2c_start   <= 0;
      i2c_stop    <= 0;
      i2c_addr    <= 0;
      i2c_rw      <= 0;
      i2c_wdata   <= 0;
      i2c_wvalid  <= 0;
      i2c_rready  <= 0;
      i2c_ack_send<= 0;
    end else begin
      // Default: clear pulses
      i2c_start  <= 0;
      i2c_stop   <= 0;
      i2c_wvalid <= 0;
      i2c_rready <= 0;
      o_valid    <= 0;

      // Track alert edge
      alert_prev <= i_alert;

      case (state)
        S_INIT: begin
          step  <= 0;
          state <= S_WRITE_CONFIG;
        end

        S_WRITE_CONFIG: begin
          case (step)
            0: begin
              i2c_addr  <= ADDR;
              i2c_rw    <= 0;  // Write
              i2c_start <= 1;
              step      <= 1;
            end
            1: if (i2c_done) begin
              if (i2c_ack_recv) begin
                // NACK - device not found
                i2c_stop <= 1;
                state    <= S_ERROR;
              end else begin
                i2c_wdata  <= REG_CONFIG;
                i2c_wvalid <= 1;
                step       <= 2;
              end
            end
            2: if (i2c_done) begin
              i2c_wdata  <= CONFIG_MSB;
              i2c_wvalid <= 1;
              step       <= 3;
            end
            3: if (i2c_done) begin
              i2c_wdata  <= CONFIG_LSB;
              i2c_wvalid <= 1;
              step       <= 4;
            end
            4: if (i2c_done) begin
              i2c_stop <= 1;
              step     <= 5;
            end
            5: if (i2c_done) begin
              step  <= 0;
              state <= S_WRITE_LO;
            end
          endcase
        end

        S_WRITE_LO: begin
          case (step)
            0: begin
              i2c_addr  <= ADDR;
              i2c_rw    <= 0;
              i2c_start <= 1;
              step      <= 1;
            end
            1: if (i2c_done) begin
              i2c_wdata  <= REG_LO;
              i2c_wvalid <= 1;
              step       <= 2;
            end
            2: if (i2c_done) begin
              i2c_wdata  <= LO_THRESH_MSB;
              i2c_wvalid <= 1;
              step       <= 3;
            end
            3: if (i2c_done) begin
              i2c_wdata  <= LO_THRESH_LSB;
              i2c_wvalid <= 1;
              step       <= 4;
            end
            4: if (i2c_done) begin
              i2c_stop <= 1;
              step     <= 5;
            end
            5: if (i2c_done) begin
              step  <= 0;
              state <= S_WRITE_HI;
            end
          endcase
        end

        S_WRITE_HI: begin
          case (step)
            0: begin
              i2c_addr  <= ADDR;
              i2c_rw    <= 0;
              i2c_start <= 1;
              step      <= 1;
            end
            1: if (i2c_done) begin
              i2c_wdata  <= REG_HI;
              i2c_wvalid <= 1;
              step       <= 2;
            end
            2: if (i2c_done) begin
              i2c_wdata  <= HI_THRESH_MSB;
              i2c_wvalid <= 1;
              step       <= 3;
            end
            3: if (i2c_done) begin
              i2c_wdata  <= HI_THRESH_LSB;
              i2c_wvalid <= 1;
              step       <= 4;
            end
            4: if (i2c_done) begin
              i2c_stop <= 1;
              step     <= 5;
            end
            5: if (i2c_done) begin
              step  <= 0;
              state <= S_WAIT_ALERT;
            end
          endcase
        end

        S_WAIT_ALERT: begin
          // Wait for falling edge on ALERT (conversion ready)
          if (alert_prev && !i_alert) begin
            state <= S_READ_START;
          end
        end

        S_READ_START: begin
          case (step)
            0: begin
              i2c_addr  <= ADDR;
              i2c_rw    <= 0;  // Write to set pointer
              i2c_start <= 1;
              step      <= 1;
            end
            1: if (i2c_done) begin
              i2c_wdata  <= REG_CONV;
              i2c_wvalid <= 1;
              step       <= 2;
            end
            2: if (i2c_done) begin
              step  <= 0;
              state <= S_READ_RESTART;
            end
          endcase
        end

        S_READ_RESTART: begin
          case (step)
            0: begin
              i2c_addr  <= ADDR;
              i2c_rw    <= 1;  // Read
              i2c_start <= 1;  // Repeated start
              step      <= 1;
            end
            1: begin
              // Keep rready high until we get first byte
              i2c_rready   <= 1;
              i2c_ack_send <= 0;  // ACK after first byte
              if (i2c_rvalid) begin
                read_data[15:8] <= i2c_rdata;
                step            <= 2;
              end
            end
            2: begin
              // Keep rready high until we get second byte
              i2c_rready   <= 1;
              i2c_ack_send <= 1;  // NACK after second byte
              if (i2c_rvalid) begin
                read_data[7:0] <= i2c_rdata;
                i2c_stop      <= 1;
                step          <= 3;
              end
            end
            3: if (i2c_done) begin
              o_data  <= read_data;
              o_valid <= 1;
              step    <= 0;
              state   <= S_WAIT_ALERT;
            end
          endcase
        end

        S_ERROR: begin
          // Wait for stop to complete, then signal error
          if (i2c_done || !i2c_busy) begin
            o_error <= 1;
            // Stay in error state (requires reset to retry)
          end
        end

        default: state <= S_INIT;
      endcase
    end
  end

endmodule
