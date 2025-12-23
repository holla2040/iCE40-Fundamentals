// UART Transmitter Module
// 8N1 format: 8 data bits, no parity, 1 stop bit

module uart_tx #(
    parameter CLK_FREQ = 12_000_000,  // 12 MHz clock
    parameter BAUD     = 115200       // Baud rate
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,        // Byte to transmit
    input  wire       tx_start,       // Pulse high to start transmission
    output reg        tx_out,         // Serial output (directly to pin)
    output reg        tx_busy         // High while transmitting
);

    // Calculate clocks per bit
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD;

    // State machine states
    localparam IDLE      = 3'd0;
    localparam START_BIT = 3'd1;
    localparam DATA_BITS = 3'd2;
    localparam STOP_BIT  = 3'd3;

    reg [2:0]  state;
    reg [15:0] clk_count;      // Clock counter for baud timing
    reg [2:0]  bit_index;      // Which bit we're sending (0-7)
    reg [7:0]  tx_shift;       // Shift register for data

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx_out    <= 1'b1;     // Idle high
            tx_busy   <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
            tx_shift  <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_out    <= 1'b1;  // Line idle high
                    tx_busy   <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;

                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_busy  <= 1'b1;
                        state    <= START_BIT;
                    end
                end

                START_BIT: begin
                    tx_out <= 1'b0;  // Start bit is low

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    tx_out <= tx_shift[0];  // LSB first

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        tx_shift  <= tx_shift >> 1;

                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    tx_out <= 1'b1;  // Stop bit is high

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
