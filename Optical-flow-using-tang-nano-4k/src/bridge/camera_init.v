//============================================================================
// OV2640 Camera Automatic Initializer
// Powers up the camera and streams the configuration sequence over I2C
//============================================================================
module camera_init (
    input  wire        clk,
    input  wire        rst_n,
    
    // I2C to OV2640
    inout  wire        sda,
    inout  wire        scl,
    
    // Status
    output reg         init_done
);

    wire i2c_busy;
    wire i2c_ack_err;
    reg  i2c_start;
    reg  [7:0] i2c_reg;
    reg  [7:0] i2c_data;

    i2c_master u_i2c (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (i2c_start),
        .slave_addr(7'h30),  // OV2640 writes to 0x60 (which is 0x30 shifted left by 1)
        .reg_addr  (i2c_reg),
        .data      (i2c_data),
        .busy      (i2c_busy),
        .ack_error (i2c_ack_err),
        .sda       (sda),
        .scl       (scl)
    );

    // Boot Delay counter (~100ms delay to let camera wake up before config)
    reg [23:0] delay_cnt;
    wire delay_done = (delay_cnt == 24'd2_700_000);

    // ROM Configuration sequence based on ov2640_init_regs
    reg [15:0] rom_data;
    reg [5:0]  rom_addr;
    
    always @(*) begin
        case (rom_addr)
            0: rom_data = 16'hFF01; // REG_BANK_SEL, BANK_SENSOR
            1: rom_data = 16'h1280; // REG_COM7, Reset all
            2: rom_data = 16'hFF01; // REG_BANK_SEL, BANK_SENSOR
            3: rom_data = 16'h1101; // REG_CLKRC
            4: rom_data = 16'h1200; // REG_COM7
            5: rom_data = 16'h030A; // REG_COM1
            6: rom_data = 16'h1711; // REG_HSTART
            7: rom_data = 16'h1843; // REG_HSTOP
            8: rom_data = 16'h1900; // REG_VSTART
            9: rom_data = 16'h1A25; // REG_VSTOP
            10: rom_data = 16'h3209;
            11: rom_data = 16'h37C0;
            12: rom_data = 16'h29A0;
            13: rom_data = 16'h330B;
            14: rom_data = 16'h2000;
            15: rom_data = 16'h227F;
            16: rom_data = 16'h362C;
            17: rom_data = 16'h37C0;
            18: rom_data = 16'h2CFF;
            19: rom_data = 16'h1500; // REG_COM10 VSYNC polarity
            
            // QVGA RGB565 Phase
            20: rom_data = 16'hFF00; // REG_BANK_SEL, BANK_DSP
            21: rom_data = 16'hE004; // REG_RESET
            22: rom_data = 16'hDA09; // REG_IMAGE_MODE (RGB565)
            23: rom_data = 16'hD703; 
            24: rom_data = 16'hE177;
            25: rom_data = 16'hE51F;
            26: rom_data = 16'hDD7F;
            27: rom_data = 16'hC028; // HSIZE
            28: rom_data = 16'hC11E; // VSIZE
            29: rom_data = 16'h8C00;
            30: rom_data = 16'h863D; // REG_CTRL2
            31: rom_data = 16'h8700; // REG_CTRL3
            32: rom_data = 16'h5A28; // REG_ZMOW
            33: rom_data = 16'h5B1E; // REG_ZMOH
            34: rom_data = 16'h5C00; // REG_ZMHH
            35: rom_data = 16'hC200; // REG_CTRL0
            36: rom_data = 16'hE000; // REG_RESET release
            default: rom_data = 16'hFFFF; // END MARKER
        endcase
    end

    // Init State Machine
    localparam S_IDLE  = 0;
    localparam S_DELAY = 1;
    localparam S_READ  = 2;
    localparam S_SEND  = 3;
    localparam S_WAIT  = 4;
    localparam S_DONE  = 5;

    reg [2:0] state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_DELAY;
            init_done <= 1'b0;
            delay_cnt <= 24'd0;
            rom_addr  <= 6'd0;
            i2c_start <= 1'b0;
        end else begin
            case (state)
                S_DELAY: begin
                    if (delay_done) begin
                        state <= S_READ;
                    end else begin
                        delay_cnt <= delay_cnt + 1'b1;
                    end
                end
                
                S_READ: begin
                    if (rom_data == 16'hFFFF) begin
                        state <= S_DONE;
                    end else begin
                        i2c_reg  <= rom_data[15:8];
                        i2c_data <= rom_data[7:0];
                        state    <= S_SEND;
                    end
                end
                
                S_SEND: begin
                    i2c_start <= 1'b1;
                    state     <= S_WAIT;
                end
                
                S_WAIT: begin
                    i2c_start <= 1'b0;
                    if (!i2c_busy && !i2c_start) begin
                        // Software reset requires a tiny delay before sending next command
                        // but 100kHz I2C bus is usually slow enough. Add simple increment.
                        rom_addr <= rom_addr + 1'b1;
                        state    <= S_READ;
                        
                        // Small extra delay if we just sent software reset (index 1)
                        if (rom_addr == 6'd1) begin
                            state <= S_DELAY;
                            delay_cnt <= 24'd0; // Wait another 100ms for camera to reboot
                        end
                    end
                end
                
                S_DONE: begin
                    init_done <= 1'b1;
                end
            endcase
        end
    end
endmodule
