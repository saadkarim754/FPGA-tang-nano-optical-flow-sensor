//============================================================================
// I2C/SCCB Master for SCCB Camera Protocol
// Sends: [Start] -> [Slave Addr] -> [Reg Addr] -> [Data] -> [Stop]
// Clock: Divider based on sys_clk (e.g., 27MHz -> ~100kHz I2C)
//============================================================================
module i2c_master #(
    parameter CLK_FREQ = 27000000,
    parameter I2C_FREQ = 100000
) (
    input  wire        clk,
    input  wire        rst_n,
    
    // Command interface
    input  wire        start,
    input  wire [6:0]  slave_addr,
    input  wire [7:0]  reg_addr,
    input  wire [7:0]  data,
    output reg         busy,
    output reg         ack_error, // 1 if NACK received
    
    // I2C physical lines
    inout  wire        sda,
    inout  wire        scl
);

    localparam CLK_DIV = (CLK_FREQ / I2C_FREQ) / 4; // 4 states per I2C clock cycle
    
    // State machine
    localparam IDLE      = 6'd0;
    localparam START1    = 6'd1;
    localparam START2    = 6'd2;
    localparam BITS      = 6'd3;
    localparam ACK       = 6'd4;
    localparam STOP1     = 6'd5;
    localparam STOP2     = 6'd6;
    localparam STOP3     = 6'd7;
    
    reg [5:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  sub_state;
    
    reg [23:0] shift_reg;
    reg [4:0]  bit_cnt;
    reg [1:0]  byte_idx; // 0=Addr, 1=Reg, 2=Data
    
    // SCL and SDA output control
    reg scl_out, sda_out;
    assign scl = scl_out ? 1'bz : 1'b0;
    assign sda = sda_out ? 1'bz : 1'b0;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            clk_cnt   <= 16'd0;
            scl_out   <= 1'b1;
            sda_out   <= 1'b1;
            busy      <= 1'b0;
            ack_error <= 1'b0;
            sub_state <= 3'd0;
        end else begin
            if (clk_cnt < CLK_DIV - 1) begin
                clk_cnt <= clk_cnt + 1'b1;
            end else begin
                clk_cnt <= 16'd0;
                
                case (state)
                    IDLE: begin
                        scl_out <= 1'b1;
                        sda_out <= 1'b1;
                        if (start && !busy) begin
                            busy      <= 1'b1;
                            ack_error <= 1'b0;
                            shift_reg <= {slave_addr, 1'b0, reg_addr, data}; // Addr+W, Reg, Data
                            byte_idx  <= 2'd0;
                            bit_cnt   <= 5'd7;
                            state     <= START1;
                        end else begin
                            busy <= 1'b0;
                        end
                    end
                    
                    START1: begin
                        sda_out <= 1'b0; // SDA falls while SCL is high
                        state   <= START2;
                    end
                    
                    START2: begin
                        scl_out <= 1'b0; // SCL falls
                        state   <= BITS;
                        sub_state <= 3'd0;
                    end
                    
                    BITS: begin
                        case (sub_state)
                            0: begin
                                // Shift out MSB
                                sda_out <= shift_reg[23];
                                shift_reg <= {shift_reg[22:0], 1'b0};
                                sub_state <= 1;
                            end
                            1: begin scl_out <= 1'b1; sub_state <= 2; end
                            2: begin sub_state <= 3; end
                            3: begin
                                scl_out <= 1'b0;
                                if (bit_cnt == 0) begin
                                    state <= ACK;
                                end else begin
                                    bit_cnt <= bit_cnt - 1'b1;
                                    sub_state <= 0;
                                end
                            end
                        endcase
                    end
                    
                    ACK: begin
                        case (sub_state)
                            0: begin
                                sda_out <= 1'b1; // Release SDA for slave ACK
                                sub_state <= 1;
                            end
                            1: begin scl_out <= 1'b1; sub_state <= 2; end
                            2: begin
                                // Sample ACK here (0=ACK, 1=NACK)
                                if (sda) ack_error <= 1'b1;
                                sub_state <= 3;
                            end
                            3: begin
                                scl_out <= 1'b0;
                                if (byte_idx == 2'd2) begin
                                    state <= STOP1; // Done with all 3 bytes
                                end else begin
                                    byte_idx  <= byte_idx + 1'b1;
                                    bit_cnt   <= 5'd7;
                                    state     <= BITS;
                                    sub_state <= 0;
                                end
                            end
                        endcase
                    end // ACK
                    
                    STOP1: begin
                        sda_out <= 1'b0;
                        state   <= STOP2;
                    end
                    
                    STOP2: begin
                        scl_out <= 1'b1;
                        state   <= STOP3;
                    end
                    
                    STOP3: begin
                        sda_out <= 1'b1;
                        state   <= IDLE;
                    end
                endcase
            end
        end
    end
endmodule
