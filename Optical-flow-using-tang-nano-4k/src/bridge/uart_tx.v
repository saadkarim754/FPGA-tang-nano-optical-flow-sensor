//============================================================================
// UART Transmitter (115200 Baud @ 27MHz)
// Simple 8-N-1 asynchronous transmitter
//============================================================================
module uart_tx #(
    parameter CLK_FREQ = 27000000,
    parameter BAUD_RATE = 115200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx_busy,
    output reg        tx_pin
);

    localparam BIT_TMR_MAX = CLK_FREQ / BAUD_RATE;
    
    // State machine
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;
    
    reg [1:0]  state;
    reg [15:0] timer;
    reg [2:0]  bit_idx;
    reg [7:0]  shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            tx_pin   <= 1'b1;
            tx_busy  <= 1'b0;
            timer    <= 16'd0;
            bit_idx  <= 3'd0;
            shift_reg<= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx_pin  <= 1'b1;
                    timer   <= 16'd0;
                    if (tx_start && !tx_busy) begin
                        tx_busy   <= 1'b1;
                        shift_reg <= tx_data;
                        state     <= START;
                    end else begin
                        tx_busy   <= 1'b0;
                    end
                end
                
                START: begin
                    tx_pin <= 1'b0;
                    if (timer == BIT_TMR_MAX - 1) begin
                        timer   <= 16'd0;
                        bit_idx <= 3'd0;
                        state   <= DATA;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end
                
                DATA: begin
                    tx_pin <= shift_reg[bit_idx];
                    if (timer == BIT_TMR_MAX - 1) begin
                        timer <= 16'd0;
                        if (bit_idx == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end
                
                STOP: begin
                    tx_pin <= 1'b1;
                    if (timer == BIT_TMR_MAX - 1) begin
                        state <= IDLE;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
