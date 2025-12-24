// DAC Baby Step
// Target: iCE40 HX1K
// DAC: DAC121S101 (12-bit, SPI)
// - 200 points, pre-filled ramp 0 to 4095
// - Pin 55 rising edge starts sweep

module top (
  input  wire i_Clk,            // 25 MHz clock

  // Trigger input
  input  wire i_Switch_1,       // Rising edge starts sweep

  // DAC SPI Master (to DAC121S101) - PMOD connector
  output wire io_PMOD_1,        // CS_n
  output wire io_PMOD_2,        // SCLK
  output wire io_PMOD_3,        // MOSI

  // Status LEDs
  output wire o_LED_1,          // Busy
  output wire o_LED_2           // Done
);

  // Reset generator
  reg [7:0] r_reset_cnt = 8'd0;
  wire w_rst_n = r_reset_cnt[7];

  always @(posedge i_Clk) begin
    if (!r_reset_cnt[7])
      r_reset_cnt <= r_reset_cnt + 1;
  end

  // Trigger edge detect
  reg [2:0] r_trigger_sync;
  always @(posedge i_Clk) begin
    r_trigger_sync <= {r_trigger_sync[1:0], i_Switch_1};
  end
  wire w_trigger_rise = (r_trigger_sync[2:1] == 2'b01);

  // Sweep control
  wire w_busy, w_done;
  wire w_sweep_start = w_trigger_rise && !w_busy;
  wire w_dac_start;
  wire [11:0] w_dac_data;
  wire w_dac_done;

  // Map to LED outputs
  assign o_LED_1 = w_busy;
  assign o_LED_2 = w_done;

  // DAC Sweep Controller
  dac_sweep u_sweep (
    .i_clk      (i_Clk),
    .i_rst_n    (w_rst_n),
    .i_start    (w_sweep_start),
    .o_busy     (w_busy),
    .o_done     (w_done),
    .o_dac_start(w_dac_start),
    .o_dac_data (w_dac_data),
    .i_dac_done (w_dac_done)
  );

  // Internal SPI signals
  wire w_dac_cs_n, w_dac_sclk, w_dac_mosi;
  assign io_PMOD_1 = w_dac_cs_n;
  assign io_PMOD_2 = w_dac_sclk;
  assign io_PMOD_3 = w_dac_mosi;

  // DAC SPI Master
  dac_spi u_dac (
    .i_clk      (i_Clk),
    .i_rst_n    (w_rst_n),
    .i_start    (w_dac_start),
    .i_data     (w_dac_data),
    .o_done     (w_dac_done),
    .o_dac_cs_n (w_dac_cs_n),
    .o_dac_sclk (w_dac_sclk),
    .o_dac_mosi (w_dac_mosi)
  );

endmodule


// ============================================
// DAC Sweep Controller with Pre-filled Ramp
// ============================================
module dac_sweep #(
  parameter NUM_POINTS = 200
)(
  input  wire        i_clk,
  input  wire        i_rst_n,

  input  wire        i_start,
  output reg         o_busy,
  output reg         o_done,

  output reg         o_dac_start,
  output reg  [11:0] o_dac_data,
  input  wire        i_dac_done
);

  // State machine
  localparam IDLE     = 2'd0;
  localparam LOAD     = 2'd1;
  localparam SEND_DAC = 2'd2;
  localparam WAIT_DAC = 2'd3;

  reg [1:0] r_state;
  reg [7:0] r_point_index;

  // Pre-filled DAC ramp memory
  // 0 to 4095 across 200 points
  reg [11:0] r_dac_memory [0:NUM_POINTS-1];
  reg [11:0] r_dac_mem_rd_data;

  // Initialize memory from file
  initial begin
    $readmemh("ramp.mem", r_dac_memory);
  end

  // Memory read
  always @(posedge i_clk) begin
    r_dac_mem_rd_data <= r_dac_memory[r_point_index];
  end

  // State machine (synchronous reset)
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      r_state       <= IDLE;
      o_busy        <= 1'b0;
      o_done        <= 1'b0;
      o_dac_start   <= 1'b0;
      o_dac_data    <= 12'd0;
      r_point_index <= 8'd0;
    end else begin
      o_dac_start <= 1'b0;
      o_done      <= 1'b0;

      case (r_state)
        IDLE: begin
          o_busy <= 1'b0;
          if (i_start) begin
            o_busy        <= 1'b1;
            r_point_index <= 8'd0;
            r_state       <= LOAD;
          end
        end

        LOAD: begin
          // Wait one cycle for memory read
          r_state <= SEND_DAC;
        end

        SEND_DAC: begin
          o_dac_data  <= r_dac_mem_rd_data;
          o_dac_start <= 1'b1;
          r_state     <= WAIT_DAC;
        end

        WAIT_DAC: begin
          if (i_dac_done) begin
            if (r_point_index == (NUM_POINTS - 1)) begin
              o_done  <= 1'b1;
              r_state <= IDLE;
            end else begin
              r_point_index <= r_point_index + 1;
              r_state       <= LOAD;
            end
          end
        end

        default: r_state <= IDLE;
      endcase
    end
  end

endmodule


// ============================================
// DAC SPI Master (DAC121S101)
// ============================================
// DAC121S101 Protocol:
// - 16-bit frame: [PD1][PD0][D11:D0][X][X]
// - PD1=0, PD0=0 for normal operation
// - MSB first, data latched on falling edge of SCLK
// - Max SCLK = 30 MHz

module dac_spi #(
  parameter CLK_DIV = 2  // 12 MHz / 2 = 6 MHz SCLK
)(
  input  wire        i_clk,
  input  wire        i_rst_n,

  input  wire        i_start,
  input  wire [11:0] i_data,
  output reg         o_done,

  output reg         o_dac_cs_n,
  output reg         o_dac_sclk,
  output reg         o_dac_mosi
);

  localparam IDLE  = 2'd0;
  localparam SHIFT = 2'd1;
  localparam DONE  = 2'd2;

  reg [1:0]  r_state;
  reg [4:0]  r_bit_cnt;
  reg [15:0] r_shift_reg;
  reg [3:0]  r_clk_cnt;

  // State machine (synchronous reset)
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      r_state     <= IDLE;
      o_dac_cs_n  <= 1'b1;
      o_dac_sclk  <= 1'b0;
      o_dac_mosi  <= 1'b0;
      o_done      <= 1'b0;
      r_bit_cnt   <= 5'd0;
      r_shift_reg <= 16'd0;
      r_clk_cnt   <= 4'd0;
    end else begin
      o_done <= 1'b0;

      case (r_state)
        IDLE: begin
          o_dac_cs_n <= 1'b1;
          o_dac_sclk <= 1'b0;
          if (i_start) begin
            // DAC121S101 frame: [PD1][PD0][D11:D0][X][X]
            r_shift_reg <= {2'b00, i_data, 2'b00};
            r_bit_cnt   <= 5'd16;
            o_dac_cs_n  <= 1'b0;
            o_dac_mosi  <= 1'b0;
            r_state     <= SHIFT;
          end
        end

        SHIFT: begin
          r_clk_cnt <= r_clk_cnt + 1;
          if (r_clk_cnt == CLK_DIV - 1) begin
            r_clk_cnt  <= 4'd0;
            o_dac_sclk <= ~o_dac_sclk;

            // Shift on falling edge
            if (o_dac_sclk) begin
              o_dac_mosi  <= r_shift_reg[15];
              r_shift_reg <= {r_shift_reg[14:0], 1'b0};
              r_bit_cnt   <= r_bit_cnt - 1;

              if (r_bit_cnt == 1) begin
                r_state <= DONE;
              end
            end
          end
        end

        DONE: begin
          o_dac_cs_n <= 1'b1;
          o_dac_sclk <= 1'b0;
          o_done     <= 1'b1;
          r_state    <= IDLE;
        end

        default: r_state <= IDLE;
      endcase
    end
  end

endmodule
