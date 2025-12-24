// ADC Baby Step
// Target: iCE40 HX1K
// ADC: AD7476A (12-bit, SPI)
// - Trigger on pin 54 rising edge
// - Read ADC 200 times
// - Store results in memory

module top (
  input  wire i_Clk,            // 25 MHz clock

  // Trigger input
  input  wire i_Switch_3,       // Rising edge starts sweep

  // ADC SPI Master (to AD7476A) - PMOD connector
  output wire io_PMOD_7,        // CS_n
  output wire io_PMOD_8,        // SCLK
  input  wire io_PMOD_9,        // MISO

  // Status LEDs
  output wire o_LED_3,          // Busy
  output wire o_LED_4           // Done
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
    r_trigger_sync <= {r_trigger_sync[1:0], i_Switch_3};
  end
  wire w_trigger_rise = (r_trigger_sync[2:1] == 2'b01);

  // Sweep control
  wire w_busy, w_done;
  wire w_sweep_start = w_trigger_rise && !w_busy;
  wire w_adc_start;
  wire [11:0] w_adc_data;
  wire w_adc_done;

  // Map to LED outputs
  assign o_LED_3 = w_busy;
  assign o_LED_4 = w_done;

  // ADC Sweep Controller
  adc_sweep u_sweep (
    .i_clk      (i_Clk),
    .i_rst_n    (w_rst_n),
    .i_start    (w_sweep_start),
    .o_busy     (w_busy),
    .o_done     (w_done),
    .o_adc_start(w_adc_start),
    .i_adc_data (w_adc_data),
    .i_adc_done (w_adc_done)
  );

  // Internal SPI signals
  wire w_adc_cs_n, w_adc_sclk;
  assign io_PMOD_7 = w_adc_cs_n;
  assign io_PMOD_8 = w_adc_sclk;

  // ADC SPI Master
  adc_spi u_adc (
    .i_clk      (i_Clk),
    .i_rst_n    (w_rst_n),
    .i_start    (w_adc_start),
    .o_data     (w_adc_data),
    .o_done     (w_adc_done),
    .o_adc_cs_n (w_adc_cs_n),
    .o_adc_sclk (w_adc_sclk),
    .i_adc_miso (io_PMOD_9)
  );

endmodule


// ============================================
// ADC Sweep Controller
// ============================================
module adc_sweep #(
  parameter NUM_POINTS = 200
)(
  input  wire        i_clk,
  input  wire        i_rst_n,

  input  wire        i_start,
  output reg         o_busy,
  output reg         o_done,

  output reg         o_adc_start,
  input  wire [11:0] i_adc_data,
  input  wire        i_adc_done
);

  // State machine
  localparam IDLE     = 2'd0;
  localparam READ_ADC = 2'd1;
  localparam WAIT_ADC = 2'd2;
  localparam STORE    = 2'd3;

  reg [1:0] r_state;
  reg [7:0] r_point_index;

  // ADC result memory (200 x 12-bit)
  reg [11:0] r_adc_memory [0:NUM_POINTS-1];

  // Memory write
  reg r_mem_wr_en;
  reg [11:0] r_captured_data;

  always @(posedge i_clk) begin
    if (r_mem_wr_en)
      r_adc_memory[r_point_index] <= r_captured_data;
  end

  // State machine (synchronous reset)
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      r_state         <= IDLE;
      o_busy          <= 1'b0;
      o_done          <= 1'b0;
      o_adc_start     <= 1'b0;
      r_point_index   <= 8'd0;
      r_mem_wr_en     <= 1'b0;
      r_captured_data <= 12'd0;
    end else begin
      o_adc_start <= 1'b0;
      o_done      <= 1'b0;
      r_mem_wr_en <= 1'b0;

      case (r_state)
        IDLE: begin
          o_busy <= 1'b0;
          if (i_start) begin
            o_busy        <= 1'b1;
            r_point_index <= 8'd0;
            r_state       <= READ_ADC;
          end
        end

        READ_ADC: begin
          o_adc_start <= 1'b1;
          r_state     <= WAIT_ADC;
        end

        WAIT_ADC: begin
          if (i_adc_done) begin
            r_captured_data <= i_adc_data;
            r_state         <= STORE;
          end
        end

        STORE: begin
          r_mem_wr_en <= 1'b1;

          if (r_point_index == (NUM_POINTS - 1)) begin
            o_done  <= 1'b1;
            r_state <= IDLE;
          end else begin
            r_point_index <= r_point_index + 1;
            r_state       <= READ_ADC;
          end
        end

        default: r_state <= IDLE;
      endcase
    end
  end

endmodule


// ============================================
// ADC SPI Master (AD7476A)
// ============================================
// AD7476A Protocol:
// - CS falling edge starts conversion
// - 16 SCLK cycles total
// - Data format: 4 leading zeros + 12-bit data
// - Data valid on SCLK falling edge (sample on rising)
// - Max SCLK = 20 MHz

module adc_spi #(
  parameter CLK_DIV = 2  // 12 MHz / 2 = 6 MHz SCLK
)(
  input  wire        i_clk,
  input  wire        i_rst_n,

  input  wire        i_start,
  output reg  [11:0] o_data,
  output reg         o_done,

  output reg         o_adc_cs_n,
  output reg         o_adc_sclk,
  input  wire        i_adc_miso
);

  localparam IDLE  = 2'd0;
  localparam SHIFT = 2'd1;
  localparam DONE  = 2'd2;

  reg [1:0]  r_state;
  reg [4:0]  r_bit_cnt;
  reg [15:0] r_shift_reg;
  reg [3:0]  r_clk_cnt;

  // Synchronize MISO
  reg [1:0] r_miso_sync;
  always @(posedge i_clk) begin
    r_miso_sync <= {r_miso_sync[0], i_adc_miso};
  end
  wire w_miso_in = r_miso_sync[1];

  // State machine (synchronous reset)
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      r_state     <= IDLE;
      o_adc_cs_n  <= 1'b1;
      o_adc_sclk  <= 1'b0;
      o_data      <= 12'd0;
      o_done      <= 1'b0;
      r_bit_cnt   <= 5'd0;
      r_shift_reg <= 16'd0;
      r_clk_cnt   <= 4'd0;
    end else begin
      o_done <= 1'b0;

      case (r_state)
        IDLE: begin
          o_adc_cs_n <= 1'b1;
          o_adc_sclk <= 1'b0;
          if (i_start) begin
            r_shift_reg <= 16'd0;
            r_bit_cnt   <= 5'd16;
            o_adc_cs_n  <= 1'b0;
            r_clk_cnt   <= 4'd0;
            r_state     <= SHIFT;
          end
        end

        SHIFT: begin
          r_clk_cnt <= r_clk_cnt + 1;
          if (r_clk_cnt == CLK_DIV - 1) begin
            r_clk_cnt  <= 4'd0;
            o_adc_sclk <= ~o_adc_sclk;

            // Sample on rising edge
            if (!o_adc_sclk) begin
              r_shift_reg <= {r_shift_reg[14:0], w_miso_in};
              r_bit_cnt   <= r_bit_cnt - 1;

              if (r_bit_cnt == 1) begin
                r_state <= DONE;
              end
            end
          end
        end

        DONE: begin
          o_adc_cs_n <= 1'b1;
          o_adc_sclk <= 1'b0;
          // AD7476A format: [0][0][0][0][D11:D0]
          o_data     <= r_shift_reg[11:0];
          o_done     <= 1'b1;
          r_state    <= IDLE;
        end

        default: r_state <= IDLE;
      endcase
    end
  end

endmodule
