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
  reg [7:0] reset_cnt = 8'd0;
  wire rst_n = reset_cnt[7];

  always @(posedge i_Clk) begin
    if (!reset_cnt[7])
      reset_cnt <= reset_cnt + 1;
  end

  // Trigger edge detect
  reg [2:0] trigger_sync;
  always @(posedge i_Clk) begin
    trigger_sync <= {trigger_sync[1:0], i_Switch_3};
  end
  wire trigger_rise = (trigger_sync[2:1] == 2'b01);

  // Sweep control
  wire busy, done;
  wire sweep_start = trigger_rise && !busy;
  wire adc_start;
  wire [11:0] adc_data;
  wire adc_done;

  // Map to LED outputs
  assign o_LED_3 = busy;
  assign o_LED_4 = done;

  // ADC Sweep Controller
  adc_sweep u_sweep (
    .clk      (i_Clk),
    .rst_n    (rst_n),
    .start    (sweep_start),
    .busy     (busy),
    .done     (done),
    .adc_start(adc_start),
    .adc_data (adc_data),
    .adc_done (adc_done)
  );

  // Internal SPI signals
  wire adc_cs_n, adc_sclk;
  assign io_PMOD_7 = adc_cs_n;
  assign io_PMOD_8 = adc_sclk;

  // ADC SPI Master
  adc_spi u_adc (
    .clk      (i_Clk),
    .rst_n    (rst_n),
    .start    (adc_start),
    .data     (adc_data),
    .done     (adc_done),
    .adc_cs_n (adc_cs_n),
    .adc_sclk (adc_sclk),
    .adc_miso (io_PMOD_9)
  );

endmodule


// ============================================
// ADC Sweep Controller
// ============================================
module adc_sweep #(
  parameter NUM_POINTS = 200
)(
  input  wire        clk,
  input  wire        rst_n,
  
  input  wire        start,
  output reg         busy,
  output reg         done,
  
  output reg         adc_start,
  input  wire [11:0] adc_data,
  input  wire        adc_done
);

  // State machine
  localparam IDLE     = 2'd0;
  localparam READ_ADC = 2'd1;
  localparam WAIT_ADC = 2'd2;
  localparam STORE    = 2'd3;
  
  reg [1:0] state;
  reg [7:0] point_index;

  // ADC result memory (200 x 12-bit)
  reg [11:0] adc_memory [0:NUM_POINTS-1];
  
  // Memory write
  reg mem_wr_en;
  reg [11:0] captured_data;
  
  always @(posedge clk) begin
    if (mem_wr_en)
      adc_memory[point_index] <= captured_data;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      busy          <= 1'b0;
      done          <= 1'b0;
      adc_start     <= 1'b0;
      point_index   <= 8'd0;
      mem_wr_en     <= 1'b0;
      captured_data <= 12'd0;
    end else begin
      adc_start <= 1'b0;
      done      <= 1'b0;
      mem_wr_en <= 1'b0;
      
      case (state)
        IDLE: begin
          busy <= 1'b0;
          if (start) begin
            busy        <= 1'b1;
            point_index <= 8'd0;
            state       <= READ_ADC;
          end
        end
        
        READ_ADC: begin
          adc_start <= 1'b1;
          state     <= WAIT_ADC;
        end
        
        WAIT_ADC: begin
          if (adc_done) begin
            captured_data <= adc_data;
            state         <= STORE;
          end
        end
        
        STORE: begin
          mem_wr_en <= 1'b1;
          
          if (point_index == (NUM_POINTS - 1)) begin
            done  <= 1'b1;
            state <= IDLE;
          end else begin
            point_index <= point_index + 1;
            state       <= READ_ADC;
          end
        end
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
  input  wire        clk,
  input  wire        rst_n,
  
  input  wire        start,
  output reg  [11:0] data,
  output reg         done,
  
  output reg         adc_cs_n,
  output reg         adc_sclk,
  input  wire        adc_miso
);

  localparam IDLE  = 2'd0;
  localparam SHIFT = 2'd1;
  localparam DONE  = 2'd2;
  
  reg [1:0]  state;
  reg [4:0]  bit_cnt;
  reg [15:0] shift_reg;
  reg [3:0]  clk_cnt;

  // Synchronize MISO
  reg [1:0] miso_sync;
  always @(posedge clk) begin
    miso_sync <= {miso_sync[0], adc_miso};
  end
  wire miso_in = miso_sync[1];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      adc_cs_n  <= 1'b1;
      adc_sclk  <= 1'b0;
      data      <= 12'd0;
      done      <= 1'b0;
      bit_cnt   <= 5'd0;
      shift_reg <= 16'd0;
      clk_cnt   <= 4'd0;
    end else begin
      done <= 1'b0;
      
      case (state)
        IDLE: begin
          adc_cs_n <= 1'b1;
          adc_sclk <= 1'b0;
          if (start) begin
            shift_reg <= 16'd0;
            bit_cnt   <= 5'd16;
            adc_cs_n  <= 1'b0;
            clk_cnt   <= 4'd0;
            state     <= SHIFT;
          end
        end
        
        SHIFT: begin
          clk_cnt <= clk_cnt + 1;
          if (clk_cnt == CLK_DIV - 1) begin
            clk_cnt  <= 4'd0;
            adc_sclk <= ~adc_sclk;
            
            // Sample on rising edge
            if (!adc_sclk) begin
              shift_reg <= {shift_reg[14:0], miso_in};
              bit_cnt   <= bit_cnt - 1;
              
              if (bit_cnt == 1) begin
                state <= DONE;
              end
            end
          end
        end
        
        DONE: begin
          adc_cs_n <= 1'b1;
          adc_sclk <= 1'b0;
          // AD7476A format: [0][0][0][0][D11:D0]
          data     <= shift_reg[11:0];
          done     <= 1'b1;
          state    <= IDLE;
        end
      endcase
    end
  end

endmodule
