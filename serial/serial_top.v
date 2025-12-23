// Serial UART Demo for Nandland Go Board
// Sends "Hello from FPGA!" message repeatedly over USB serial
// Connect at 115200 baud, 8N1

module top (
    input  wire i_Clk,
    output wire o_UART_TX,
    output wire o_LED_1,
    output wire o_LED_2,
    output wire o_LED_3,
    output wire o_LED_4
);

    // Message to send (including CR+LF)
    localparam MSG_LEN = 18;
    reg [7:0] message [0:MSG_LEN-1];
    initial begin
        message[0]  = "H";
        message[1]  = "e";
        message[2]  = "l";
        message[3]  = "l";
        message[4]  = "o";
        message[5]  = " ";
        message[6]  = "f";
        message[7]  = "r";
        message[8]  = "o";
        message[9]  = "m";
        message[10] = " ";
        message[11] = "F";
        message[12] = "P";
        message[13] = "G";
        message[14] = "A";
        message[15] = "!";
        message[16] = 8'h0D;  // CR
        message[17] = 8'h0A;  // LF
    end

    // Reset generation (simple power-on reset)
    reg [3:0] rst_count = 4'hF;
    wire rst = rst_count != 0;
    always @(posedge i_Clk) begin
        if (rst_count != 0)
            rst_count <= rst_count - 1;
    end

    // UART transmitter signals
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    // Instantiate UART transmitter
    uart_tx #(
        .CLK_FREQ(25_000_000),  // Nandland Go Board has 25 MHz clock
        .BAUD(115200)
    ) uart_inst (
        .clk(i_Clk),
        .rst(rst),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_out(o_UART_TX),
        .tx_busy(tx_busy)
    );

    // State machine for sending message
    localparam WAIT_DELAY = 3'd0;
    localparam LOAD_CHAR  = 3'd1;
    localparam SEND_CHAR  = 3'd2;
    localparam WAIT_DONE  = 3'd3;

    reg [2:0]  state = WAIT_DELAY;
    reg [4:0]  char_index = 0;
    reg [24:0] delay_count = 0;
    reg [7:0]  send_count = 0;  // Count messages sent

    // Delay between messages: ~1 second at 25 MHz
    localparam DELAY_1SEC = 25'd25_000_000;

    always @(posedge i_Clk) begin
        if (rst) begin
            state       <= WAIT_DELAY;
            char_index  <= 0;
            delay_count <= 0;
            tx_start    <= 0;
            tx_data     <= 0;
            send_count  <= 0;
        end else begin
            tx_start <= 0;  // Default: no start pulse

            case (state)
                WAIT_DELAY: begin
                    if (delay_count < DELAY_1SEC) begin
                        delay_count <= delay_count + 1;
                    end else begin
                        delay_count <= 0;
                        char_index  <= 0;
                        state       <= LOAD_CHAR;
                    end
                end

                LOAD_CHAR: begin
                    if (char_index < MSG_LEN) begin
                        tx_data <= message[char_index];
                        state   <= SEND_CHAR;
                    end else begin
                        send_count <= send_count + 1;
                        state      <= WAIT_DELAY;
                    end
                end

                SEND_CHAR: begin
                    if (!tx_busy) begin
                        tx_start <= 1;
                        state    <= WAIT_DONE;
                    end
                end

                WAIT_DONE: begin
                    if (tx_busy) begin
                        // Transmission started, wait for it to complete
                    end else if (!tx_start) begin
                        // Transmission complete
                        char_index <= char_index + 1;
                        state      <= LOAD_CHAR;
                    end
                end

                default: state <= WAIT_DELAY;
            endcase
        end
    end

    // LED output: show message count on LEDs (binary)
    assign o_LED_1 = send_count[0];
    assign o_LED_2 = send_count[1];
    assign o_LED_3 = send_count[2];
    assign o_LED_4 = send_count[3];

endmodule
