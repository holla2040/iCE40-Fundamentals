// I2C Master Controller
// Supports single-byte read/write operations
// Open-drain compatible (directly drives low, releases for high)

module i2c_master #(
  parameter CLK_FREQ = 25_000_000,
  parameter I2C_FREQ = 100_000
)(
  input  wire       i_clk,
  input  wire       i_rst,

  // Command interface
  input  wire [6:0] i_addr,       // 7-bit device address
  input  wire       i_rw,         // 0=write, 1=read
  input  wire       i_start,      // Start transaction
  input  wire [7:0] i_wdata,      // Write data
  input  wire       i_wvalid,     // Write data valid
  input  wire       i_rready,     // Ready to accept read data
  input  wire       i_stop,       // Generate stop condition
  input  wire       i_ack_send,   // ACK to send on read (0=ACK, 1=NACK)

  // Status interface
  output reg  [7:0] o_rdata,      // Read data
  output reg        o_rvalid,     // Read data valid
  output reg        o_wready,     // Ready for write data
  output reg        o_ack_recv,   // ACK received (0=ACK, 1=NACK)
  output reg        o_busy,       // Transaction in progress
  output reg        o_done,       // Operation complete pulse

  // I2C lines (directly connect to FPGA pins)
  output reg        o_scl,        // SCL output (directly driven)
  output reg        o_sda,        // SDA output (directly driven)
  input  wire       i_sda         // SDA input (directly from pin)
);

  // Clock divider for I2C timing
  localparam CLKS_PER_BIT = CLK_FREQ / I2C_FREQ / 4;

  // States
  localparam S_IDLE       = 4'd0;
  localparam S_START      = 4'd1;
  localparam S_ADDR       = 4'd2;
  localparam S_ADDR_ACK   = 4'd3;
  localparam S_WRITE      = 4'd4;
  localparam S_WRITE_ACK  = 4'd5;
  localparam S_READ       = 4'd6;
  localparam S_READ_ACK   = 4'd7;
  localparam S_STOP       = 4'd8;
  localparam S_WAIT_CMD   = 4'd9;

  reg [3:0]  r_state;
  reg [15:0] r_clk_cnt;
  reg [1:0]  r_phase;       // 0-3 for SCL timing
  reg [2:0]  r_bit_cnt;
  reg [7:0]  r_shift_reg;
  reg [6:0]  r_addr_reg;
  reg        r_rw_reg;

  // Clock phase timing
  wire w_phase_tick = (r_clk_cnt == CLKS_PER_BIT - 1);

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_state     <= S_IDLE;
      r_clk_cnt   <= 0;
      r_phase     <= 0;
      r_bit_cnt   <= 0;
      r_shift_reg <= 0;
      r_addr_reg  <= 0;
      r_rw_reg    <= 0;
      o_scl       <= 1'b1;
      o_sda       <= 1'b1;
      o_rdata     <= 0;
      o_rvalid    <= 0;
      o_wready    <= 0;
      o_ack_recv  <= 1;
      o_busy      <= 0;
      o_done      <= 0;
    end else begin
      // Default pulse signals
      o_done   <= 0;
      o_rvalid <= 0;

      // Clock counter
      if (w_phase_tick)
        r_clk_cnt <= 0;
      else
        r_clk_cnt <= r_clk_cnt + 1;

      case (r_state)
        S_IDLE: begin
          o_scl     <= 1'b1;
          o_sda     <= 1'b1;
          o_busy    <= 0;
          o_wready  <= 0;
          r_phase   <= 0;
          r_clk_cnt <= 0;

          if (i_start) begin
            r_addr_reg <= i_addr;
            r_rw_reg   <= i_rw;
            o_busy     <= 1;
            r_state    <= S_START;
          end
        end

        S_START: begin
          // Start condition: SDA goes low while SCL is high
          if (w_phase_tick) begin
            r_phase <= r_phase + 1;
            case (r_phase)
              0: begin o_scl <= 1'b1; o_sda <= 1'b1; end
              1: begin o_scl <= 1'b1; o_sda <= 1'b0; end  // SDA falls
              2: begin o_scl <= 1'b0; o_sda <= 1'b0; end  // SCL falls
              3: begin
                // Load address + R/W bit
                r_shift_reg <= {r_addr_reg, r_rw_reg};
                r_bit_cnt   <= 7;
                r_state     <= S_ADDR;
              end
            endcase
          end
        end

        S_ADDR: begin
          // Send address byte
          if (w_phase_tick) begin
            r_phase <= r_phase + 1;
            case (r_phase)
              0: begin o_sda <= r_shift_reg[7]; end           // Set data
              1: begin o_scl <= 1'b1; end                     // SCL rise
              2: begin o_scl <= 1'b1; end                     // SCL high
              3: begin
                o_scl <= 1'b0;                                // SCL fall
                r_shift_reg <= {r_shift_reg[6:0], 1'b0};
                if (r_bit_cnt == 0)
                  r_state <= S_ADDR_ACK;
                else
                  r_bit_cnt <= r_bit_cnt - 1;
              end
            endcase
          end
        end

        S_ADDR_ACK: begin
          // Read ACK from slave
          if (w_phase_tick) begin
            r_phase <= r_phase + 1;
            case (r_phase)
              0: begin o_sda <= 1'b1; end                     // Release SDA
              1: begin o_scl <= 1'b1; end                     // SCL rise
              2: begin o_ack_recv <= i_sda; end               // Sample ACK
              3: begin
                o_scl   <= 1'b0;
                o_done  <= 1;
                r_state <= S_WAIT_CMD;
              end
            endcase
          end
        end

        S_WAIT_CMD: begin
          // Wait for next command
          o_wready <= !r_rw_reg;  // Ready for write data if write mode

          if (i_stop) begin
            r_state <= S_STOP;
          end else if (i_start) begin
            // Repeated start
            r_addr_reg <= i_addr;
            r_rw_reg   <= i_rw;
            r_phase    <= 0;
            r_state    <= S_START;
          end else if (!r_rw_reg && i_wvalid) begin
            // Write data
            r_shift_reg <= i_wdata;
            r_bit_cnt   <= 7;
            o_wready    <= 0;
            r_state     <= S_WRITE;
          end else if (r_rw_reg && i_rready) begin
            // Read data
            r_bit_cnt <= 7;
            r_state   <= S_READ;
          end
        end

        S_WRITE: begin
          // Send data byte
          if (w_phase_tick) begin
            r_phase <= r_phase + 1;
            case (r_phase)
              0: begin o_sda <= r_shift_reg[7]; end
              1: begin o_scl <= 1'b1; end
              2: begin o_scl <= 1'b1; end
              3: begin
                o_scl <= 1'b0;
                r_shift_reg <= {r_shift_reg[6:0], 1'b0};
                if (r_bit_cnt == 0)
                  r_state <= S_WRITE_ACK;
                else
                  r_bit_cnt <= r_bit_cnt - 1;
              end
            endcase
          end
        end

        S_WRITE_ACK: begin
          if (w_phase_tick) begin
            r_phase <= r_phase + 1;
            case (r_phase)
              0: begin o_sda <= 1'b1; end
              1: begin o_scl <= 1'b1; end
              2: begin o_ack_recv <= i_sda; end
              3: begin
                o_scl   <= 1'b0;
                o_done  <= 1;
                r_state <= S_WAIT_CMD;
              end
            endcase
          end
        end

        S_READ: begin
          // Read data byte
          if (w_phase_tick) begin
            r_phase <= r_phase + 1;
            case (r_phase)
              0: begin o_sda <= 1'b1; end                     // Release SDA
              1: begin o_scl <= 1'b1; end                     // SCL rise
              2: begin r_shift_reg <= {r_shift_reg[6:0], i_sda}; end  // Sample
              3: begin
                o_scl <= 1'b0;
                if (r_bit_cnt == 0) begin
                  o_rdata  <= {r_shift_reg[6:0], i_sda};
                  o_rvalid <= 1;
                  r_state  <= S_READ_ACK;
                end else begin
                  r_bit_cnt <= r_bit_cnt - 1;
                end
              end
            endcase
          end
        end

        S_READ_ACK: begin
          // Send ACK/NACK to slave
          if (w_phase_tick) begin
            r_phase <= r_phase + 1;
            case (r_phase)
              0: begin o_sda <= i_ack_send; end               // ACK=0, NACK=1
              1: begin o_scl <= 1'b1; end
              2: begin o_scl <= 1'b1; end
              3: begin
                o_scl   <= 1'b0;
                o_done  <= 1;
                r_state <= S_WAIT_CMD;
              end
            endcase
          end
        end

        S_STOP: begin
          // Stop condition: SDA goes high while SCL is high
          if (w_phase_tick) begin
            r_phase <= r_phase + 1;
            case (r_phase)
              0: begin o_sda <= 1'b0; end
              1: begin o_scl <= 1'b1; end
              2: begin o_sda <= 1'b1; end                     // SDA rises
              3: begin
                o_done  <= 1;
                r_state <= S_IDLE;
              end
            endcase
          end
        end

        default: r_state <= S_IDLE;
      endcase
    end
  end

endmodule
