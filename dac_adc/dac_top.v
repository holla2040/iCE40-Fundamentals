// DAC Baby Step
// Target: iCE40 HX1K
// DAC: DAC121S101 (12-bit, SPI)
// - 200 points, pre-filled ramp 0 to 4095
// - Pin 55 rising edge starts sweep

module top (
    input  wire clk,              // 12 MHz clock
    
    // Trigger input
    input  wire trigger_in,       // Pin 55 - rising edge starts sweep
    
    // DAC SPI Master (to DAC121S101)
    output wire dac_cs_n,
    output wire dac_sclk,
    output wire dac_mosi,
    
    // Status
    output wire busy,
    output wire done
);

    // Reset generator
    reg [7:0] reset_cnt = 8'd0;
    wire rst_n = reset_cnt[7];
    
    always @(posedge clk) begin
        if (!reset_cnt[7])
            reset_cnt <= reset_cnt + 1;
    end

    // Trigger edge detect
    reg [2:0] trigger_sync;
    always @(posedge clk) begin
        trigger_sync <= {trigger_sync[1:0], trigger_in};
    end
    wire trigger_rise = (trigger_sync[2:1] == 2'b01);

    // Sweep control
    wire sweep_start = trigger_rise && !busy;
    wire dac_start;
    wire [11:0] dac_data;
    wire dac_done;

    // DAC Sweep Controller
    dac_sweep u_sweep (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (sweep_start),
        .busy     (busy),
        .done     (done),
        .dac_start(dac_start),
        .dac_data (dac_data),
        .dac_done (dac_done)
    );

    // DAC SPI Master
    dac_spi u_dac (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (dac_start),
        .data     (dac_data),
        .done     (dac_done),
        .dac_cs_n (dac_cs_n),
        .dac_sclk (dac_sclk),
        .dac_mosi (dac_mosi)
    );

endmodule


// ============================================
// DAC Sweep Controller with Pre-filled Ramp
// ============================================
module dac_sweep #(
    parameter NUM_POINTS = 200
)(
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire        start,
    output reg         busy,
    output reg         done,
    
    output reg         dac_start,
    output reg  [11:0] dac_data,
    input  wire        dac_done
);

    // State machine
    localparam IDLE     = 2'd0;
    localparam LOAD     = 2'd1;
    localparam SEND_DAC = 2'd2;
    localparam WAIT_DAC = 2'd3;
    
    reg [1:0] state;
    reg [7:0] point_index;

    // Pre-filled DAC ramp memory
    // 0 to 4095 across 200 points
    reg [11:0] dac_memory [0:NUM_POINTS-1];
    reg [11:0] dac_mem_rd_data;
    
    // Initialize memory from file
    initial begin
        $readmemh("ramp.mem", dac_memory);
    end
    
    // Memory read
    always @(posedge clk) begin
        dac_mem_rd_data <= dac_memory[point_index];
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            busy        <= 1'b0;
            done        <= 1'b0;
            dac_start   <= 1'b0;
            dac_data    <= 12'd0;
            point_index <= 8'd0;
        end else begin
            dac_start <= 1'b0;
            done      <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy        <= 1'b1;
                        point_index <= 8'd0;
                        state       <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Wait one cycle for memory read
                    state <= SEND_DAC;
                end
                
                SEND_DAC: begin
                    dac_data  <= dac_mem_rd_data;
                    dac_start <= 1'b1;
                    state     <= WAIT_DAC;
                end
                
                WAIT_DAC: begin
                    if (dac_done) begin
                        if (point_index == (NUM_POINTS - 1)) begin
                            done  <= 1'b1;
                            state <= IDLE;
                        end else begin
                            point_index <= point_index + 1;
                            state       <= LOAD;
                        end
                    end
                end
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
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire        start,
    input  wire [11:0] data,
    output reg         done,
    
    output reg         dac_cs_n,
    output reg         dac_sclk,
    output reg         dac_mosi
);

    localparam IDLE  = 2'd0;
    localparam SHIFT = 2'd1;
    localparam DONE  = 2'd2;
    
    reg [1:0]  state;
    reg [4:0]  bit_cnt;
    reg [15:0] shift_reg;
    reg [3:0]  clk_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            dac_cs_n  <= 1'b1;
            dac_sclk  <= 1'b0;
            dac_mosi  <= 1'b0;
            done      <= 1'b0;
            bit_cnt   <= 5'd0;
            shift_reg <= 16'd0;
            clk_cnt   <= 4'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    dac_cs_n <= 1'b1;
                    dac_sclk <= 1'b0;
                    if (start) begin
                        // DAC121S101 frame: [PD1][PD0][D11:D0][X][X]
                        shift_reg <= {2'b00, data, 2'b00};
                        bit_cnt   <= 5'd16;
                        dac_cs_n  <= 1'b0;
                        dac_mosi  <= 1'b0;
                        state     <= SHIFT;
                    end
                end
                
                SHIFT: begin
                    clk_cnt <= clk_cnt + 1;
                    if (clk_cnt == CLK_DIV - 1) begin
                        clk_cnt  <= 4'd0;
                        dac_sclk <= ~dac_sclk;
                        
                        // Shift on falling edge
                        if (dac_sclk) begin
                            dac_mosi  <= shift_reg[15];
                            shift_reg <= {shift_reg[14:0], 1'b0};
                            bit_cnt   <= bit_cnt - 1;
                            
                            if (bit_cnt == 1) begin
                                state <= DONE;
                            end
                        end
                    end
                end
                
                DONE: begin
                    dac_cs_n <= 1'b1;
                    dac_sclk <= 1'b0;
                    done     <= 1'b1;
                    state    <= IDLE;
                end
            endcase
        end
    end

endmodule
