//============================================================================
// SCCB Master (I2C-compatible) for OV2640 Camera Configuration
// Supports 8-bit sub-address + 8-bit data writes
// SCCB device address for OV2640: 0x60 (write), 0x61 (read)
//============================================================================
module sccb_master (
    input  wire        clk,          // System clock
    input  wire        rst_n,        // Active-low reset
    
    // SCCB bus (directly to camera)
    output reg         scl,          // SCCB clock
    inout  wire        sda,          // SCCB data (open-drain)
    
    // Control interface
    input  wire        start,        // Pulse to start transaction
    input  wire [7:0]  dev_addr,     // Device address (0x60 for OV2640 write)
    input  wire [7:0]  reg_addr,     // Register address
    input  wire [7:0]  wr_data,      // Write data
    output reg         done,         // Transaction complete pulse
    output reg         busy          // Transaction in progress
);

    // Clock divider: ~100kHz SCCB clock from system clock
    // For 54MHz system clock: 54MHz / (4 * 100kHz) = 135
    parameter CLK_DIV = 135;
    
    reg [7:0] clk_cnt;
    reg       clk_en;  // Tick at 4x SCCB frequency (for quarter-cycle timing)
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 8'd0;
            clk_en  <= 1'b0;
        end else begin
            clk_en <= 1'b0;
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= 8'd0;
                clk_en  <= 1'b1;
            end else begin
                clk_cnt <= clk_cnt + 8'd1;
            end
        end
    end
    
    // SDA output control (open-drain: 0 = drive low, 1 = high-Z)
    reg sda_out;
    reg sda_oe;   // Output enable
    assign sda = sda_oe ? 1'bz : sda_out;
    
    // State machine
    localparam [4:0]
        S_IDLE       = 5'd0,
        S_START      = 5'd1,
        S_DEV_ADDR   = 5'd2,
        S_DEV_ACK    = 5'd3,
        S_REG_ADDR   = 5'd4,
        S_REG_ACK    = 5'd5,
        S_WR_DATA    = 5'd6,
        S_WR_ACK     = 5'd7,
        S_STOP_1     = 5'd8,
        S_STOP_2     = 5'd9,
        S_STOP_3     = 5'd10,
        S_DONE       = 5'd11;
    
    reg [4:0]  state;
    reg [1:0]  phase;     // Quarter-cycle phase (0-3)
    reg [2:0]  bit_cnt;   // Bit counter within byte (7 downto 0)
    reg [7:0]  shift_reg; // Shift register for current byte
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            phase     <= 2'd0;
            bit_cnt   <= 3'd7;
            shift_reg <= 8'd0;
            scl       <= 1'b1;
            sda_out   <= 1'b0;
            sda_oe    <= 1'b1;  // High-Z (release SDA)
            done      <= 1'b0;
            busy      <= 1'b0;
        end else begin
            done <= 1'b0;
            
            if (state == S_IDLE) begin
                scl    <= 1'b1;
                sda_oe <= 1'b1;  // Release SDA
                busy   <= 1'b0;
                
                if (start) begin
                    state     <= S_START;
                    phase     <= 2'd0;
                    busy      <= 1'b1;
                end
            end else if (clk_en) begin
                case (state)
                    //------------------------------------------------------
                    // START condition: SDA goes low while SCL is high
                    //------------------------------------------------------
                    S_START: begin
                        case (phase)
                            2'd0: begin sda_oe <= 1'b1; scl <= 1'b1; end  // SDA=H, SCL=H
                            2'd1: begin sda_oe <= 1'b0; sda_out <= 1'b0; end  // SDA=L (start)
                            2'd2: begin scl <= 1'b0; end                  // SCL=L
                            2'd3: begin
                                state     <= S_DEV_ADDR;
                                shift_reg <= dev_addr;
                                bit_cnt   <= 3'd7;
                                phase     <= 2'd0;
                            end
                        endcase
                        if (state == S_START) phase <= phase + 2'd1;
                    end
                    
                    //------------------------------------------------------
                    // Send byte (device addr / register addr / write data)
                    //------------------------------------------------------
                    S_DEV_ADDR, S_REG_ADDR, S_WR_DATA: begin
                        case (phase)
                            2'd0: begin
                                // Set SDA to current bit
                                sda_oe  <= 1'b0;
                                sda_out <= shift_reg[7];
                            end
                            2'd1: begin scl <= 1'b1; end  // SCL rising edge
                            2'd2: begin scl <= 1'b0; end  // SCL falling edge
                            2'd3: begin
                                shift_reg <= {shift_reg[6:0], 1'b0};
                                if (bit_cnt == 3'd0) begin
                                    // Move to ACK phase
                                    case (state)
                                        S_DEV_ADDR: state <= S_DEV_ACK;
                                        S_REG_ADDR: state <= S_REG_ACK;
                                        S_WR_DATA:  state <= S_WR_ACK;
                                        default:    state <= S_IDLE;
                                    endcase
                                    bit_cnt <= 3'd7;
                                end else begin
                                    bit_cnt <= bit_cnt - 3'd1;
                                end
                            end
                        endcase
                        phase <= phase + 2'd1;
                    end
                    
                    //------------------------------------------------------
                    // ACK cycle: release SDA, clock, ignore response (SCCB)
                    //------------------------------------------------------
                    S_DEV_ACK, S_REG_ACK, S_WR_ACK: begin
                        case (phase)
                            2'd0: begin sda_oe <= 1'b1; end  // Release SDA for ACK
                            2'd1: begin scl <= 1'b1; end     // SCL high
                            2'd2: begin scl <= 1'b0; end     // SCL low
                            2'd3: begin
                                case (state)
                                    S_DEV_ACK: begin
                                        state     <= S_REG_ADDR;
                                        shift_reg <= reg_addr;
                                        bit_cnt   <= 3'd7;
                                    end
                                    S_REG_ACK: begin
                                        state     <= S_WR_DATA;
                                        shift_reg <= wr_data;
                                        bit_cnt   <= 3'd7;
                                    end
                                    S_WR_ACK: begin
                                        state <= S_STOP_1;
                                    end
                                    default: state <= S_IDLE;
                                endcase
                            end
                        endcase
                        phase <= phase + 2'd1;
                    end
                    
                    //------------------------------------------------------
                    // STOP condition: SDA goes high while SCL is high
                    //------------------------------------------------------
                    S_STOP_1: begin
                        sda_oe  <= 1'b0;
                        sda_out <= 1'b0;  // SDA low
                        state   <= S_STOP_2;
                    end
                    S_STOP_2: begin
                        scl   <= 1'b1;    // SCL high
                        state <= S_STOP_3;
                    end
                    S_STOP_3: begin
                        sda_oe <= 1'b1;   // Release SDA (goes high = STOP)
                        state  <= S_DONE;
                    end
                    
                    S_DONE: begin
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end
                    
                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule
