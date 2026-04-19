//============================================================================
// FPGA Hardware Debugger (UART Text Sequencer)
// Prints basic boot messages natively over UART and asserts 'handover'
// when finished so the Cortex-M3 can take over the TX pin.
//============================================================================
module fpga_debugger (
    input  wire       clk,
    input  wire       rst_n,
    
    input  wire       cam_init_done,
    input  wire       first_frame_seen,
    
    output wire [7:0] uart_tx_data,
    output wire       uart_tx_start,
    input  wire       uart_tx_busy,
    
    input  wire       dvp_pclk,
    input  wire       dvp_vsync,
    
    output reg        handover_to_mcu
);

    // ASCII ROM Messages
    // Msg 0: "[FPGA] Booting...\r\n"
    // Msg 1: "[FPGA] OV2640 Configured!\r\n"
    // Msg 2: "[FPGA] Frame 1 OK! MCU Handover.\r\n"
    
    reg [7:0] char_rom [0:255];
    initial begin
        // Initialize memory with spaces/nulls
        // Msg 0 (Start idx 0)
        char_rom[0]  = "["; char_rom[1]  = "F"; char_rom[2]  = "P"; char_rom[3]  = "G"; 
        char_rom[4]  = "A"; char_rom[5]  = "]"; char_rom[6]  = " "; char_rom[7]  = "B";
        char_rom[8]  = "o"; char_rom[9]  = "o"; char_rom[10] = "t"; char_rom[11] = "i"; 
        char_rom[12] = "n"; char_rom[13] = "g"; char_rom[14] = "."; char_rom[15] = ".";
        char_rom[16] = "."; char_rom[17] = 8'h0D; char_rom[18] = 8'h0A; char_rom[19] = 0;
        
        // Msg 1 (Start idx 32)
        char_rom[32] = "["; char_rom[33] = "F"; char_rom[34] = "P"; char_rom[35] = "G";
        char_rom[36] = "A"; char_rom[37] = "]"; char_rom[38] = " "; char_rom[39] = "O";
        char_rom[40] = "V"; char_rom[41] = "2"; char_rom[42] = "6"; char_rom[43] = "4";
        char_rom[44] = "0"; char_rom[45] = " "; char_rom[46] = "O"; char_rom[47] = "K";
        char_rom[48] = "!"; char_rom[49] = 8'h0D; char_rom[50] = 8'h0A; char_rom[51] = 0;
        
        // Msg 2: PCLK ALIVE (Start idx 64)
        char_rom[64] = "["; char_rom[65] = "C"; char_rom[66] = "A"; char_rom[67] = "M";
        char_rom[68] = "]"; char_rom[69] = " "; char_rom[70] = "P"; char_rom[71] = "C";
        char_rom[72] = "L"; char_rom[73] = "K"; char_rom[74] = "&"; char_rom[75] = "V";
        char_rom[76] = "S"; char_rom[77] = "Y"; char_rom[78] = "N"; char_rom[79] = "C";
        char_rom[80] = " "; char_rom[81] = "A"; char_rom[82] = "L"; char_rom[83] = "I";
        char_rom[84] = "V"; char_rom[85] = "E"; char_rom[86] = 8'h0D; char_rom[87] = 8'h0A;
        char_rom[88] = 0;
        
        // Msg 3: TIMEOUT (Start idx 96)
        char_rom[96] = "["; char_rom[97] = "C"; char_rom[98] = "A"; char_rom[99] = "M";
        char_rom[100]= "]"; char_rom[101]= " "; char_rom[102]= "D"; char_rom[103]= "E";
        char_rom[104]= "A"; char_rom[105]= "D"; char_rom[106]= " "; char_rom[107]= "N";
        char_rom[108]= "O"; char_rom[109]= " "; char_rom[110]= "F"; char_rom[111]= "R";
        char_rom[112]= "A"; char_rom[113]= "M"; char_rom[114]= "E"; char_rom[115]= "S";
        char_rom[116]= 8'h0D; char_rom[117]= 8'h0A; char_rom[118]= 0;
        
        // Msg 4: MCU TAKEOVER (Start idx 128)
        char_rom[128] = "["; char_rom[129] = "F"; char_rom[130] = "P"; char_rom[131] = "G";
        char_rom[132] = "A"; char_rom[133] = "]"; char_rom[134] = " "; char_rom[135] = "M";
        char_rom[136] = "C"; char_rom[137] = "U"; char_rom[138] = " "; char_rom[139] = "T";
        char_rom[140] = "A"; char_rom[141] = "K"; char_rom[142] = "E"; char_rom[143] = "O";
        char_rom[144] = "V"; char_rom[145] = "E"; char_rom[146] = "R"; char_rom[147] = 8'h0D;
        char_rom[148] = 8'h0A; char_rom[149] = 0;

        // Msg 5: NO PCLK (Start idx 160)
        char_rom[160] = "["; char_rom[161] = "E"; char_rom[162] = "R"; char_rom[163] = "R";
        char_rom[164] = "]"; char_rom[165] = " "; char_rom[166] = "N"; char_rom[167] = "O";
        char_rom[168] = " "; char_rom[169] = "P"; char_rom[170] = "C"; char_rom[171] = "L";
        char_rom[172] = "K"; char_rom[173] = "!"; char_rom[174] = 8'h0D; char_rom[175] = 8'h0A;
        char_rom[176] = 0;

        // Msg 6: NO VSYNC (Start idx 192)
        char_rom[192] = "["; char_rom[193] = "E"; char_rom[194] = "R"; char_rom[195] = "R";
        char_rom[196] = "]"; char_rom[197] = " "; char_rom[198] = "N"; char_rom[199] = "O";
        char_rom[200] = " "; char_rom[201] = "V"; char_rom[202] = "S"; char_rom[203] = "Y";
        char_rom[204] = "N"; char_rom[205] = "C"; char_rom[206] = "!"; char_rom[207] = 8'h0D;
        char_rom[208] = 8'h0A; char_rom[209] = 0;
    end

    localparam S_START        = 0;
    localparam S_PRINT_BOOT   = 1;
    localparam S_WAIT_CAM     = 2;
    localparam S_PRINT_CAM_OK = 3;
    localparam S_WAIT_FRAME   = 4;
    localparam S_PRINT_DONE   = 5;
    localparam S_HANDOVER     = 6;

    localparam S_PRINT_CAM_STATS = 7;

    reg [3:0] state;
    reg [7:0] rom_ptr;
    reg [7:0] msg_base;
    reg       tx_req;
    
    assign uart_tx_start = tx_req;
    assign uart_tx_data  = char_rom[rom_ptr];

    // Give some time on start for PuTTY to catch up
    reg [23:0] startup_delay;
    reg [25:0] frame_timeout;

    reg pclk_d1, pclk_d2, pclk_d3;
    reg vsync_d1, vsync_d2, vsync_d3;
    
    always @(posedge clk) begin
        pclk_d1 <= dvp_pclk;
        pclk_d2 <= pclk_d1;
        pclk_d3 <= pclk_d2;
        
        vsync_d1 <= dvp_vsync;
        vsync_d2 <= vsync_d1;
        vsync_d3 <= vsync_d2;
    end
    
    wire pclk_edge = pclk_d2 & ~pclk_d3;
    wire vsync_edge = vsync_d2 & ~vsync_d3;
    
    reg [23:0] pclk_ticks;
    reg [15:0] vsync_ticks;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_START;
            rom_ptr         <= 8'd0;
            msg_base        <= 8'd0;
            tx_req          <= 1'b0;
            handover_to_mcu <= 1'b0;
            startup_delay   <= 24'd0;
            frame_timeout   <= 26'd0;
            pclk_ticks      <= 24'd0;
            vsync_ticks     <= 16'd0;
        end else begin
            case (state)
                S_START: begin
                    if (startup_delay == 24'd5_000_000) begin
                        state    <= S_PRINT_BOOT;
                        msg_base <= 8'd0;
                        rom_ptr  <= 8'd0;
                    end else begin
                        startup_delay <= startup_delay + 1'b1;
                    end
                end
                
                S_PRINT_BOOT: begin
                    if (char_rom[rom_ptr] == 8'd0) begin
                        state <= S_WAIT_CAM;
                    end else if (!uart_tx_busy && !tx_req) begin
                        tx_req <= 1'b1;
                    end else if (uart_tx_busy && tx_req) begin
                        tx_req  <= 1'b0;
                        rom_ptr <= rom_ptr + 1'b1;
                    end
                end
                
                S_WAIT_CAM: begin
                    if (cam_init_done) begin
                        state    <= S_PRINT_CAM_OK;
                        msg_base <= 8'd32;
                        rom_ptr  <= 8'd32;
                    end
                end
                
                S_PRINT_CAM_OK: begin
                    if (char_rom[rom_ptr] == 8'd0) begin
                        state <= S_WAIT_FRAME;
                    end else if (!uart_tx_busy && !tx_req) begin
                        tx_req <= 1'b1;
                    end else if (uart_tx_busy && tx_req) begin
                        tx_req  <= 1'b0;
                        rom_ptr <= rom_ptr + 1'b1;
                    end
                end
                
                S_WAIT_FRAME: begin
                    if (pclk_edge) pclk_ticks <= pclk_ticks + 1'b1;
                    if (vsync_edge) vsync_ticks <= vsync_ticks + 1'b1;

                    if (first_frame_seen) begin
                        state    <= S_PRINT_CAM_STATS;
                        msg_base <= 8'd64; // PCLK ALIVE
                        rom_ptr  <= 8'd64;
                    end else if (frame_timeout == 26'd54_000_000) begin
                        state    <= S_PRINT_CAM_STATS;
                        if (pclk_ticks == 0) begin
                            msg_base <= 8'd160; // ERR NO PCLK
                            rom_ptr  <= 8'd160;
                        end else if (vsync_ticks == 0) begin
                            msg_base <= 8'd192; // ERR NO VSYNC
                            rom_ptr  <= 8'd192;
                        end else begin
                            msg_base <= 8'd96;  // CAM DEAD NO FRAMES
                            rom_ptr  <= 8'd96;
                        end
                    end else begin
                        frame_timeout <= frame_timeout + 1'b1;
                    end
                end
                
                S_PRINT_CAM_STATS: begin
                    if (char_rom[rom_ptr] == 8'd0) begin
                        state    <= S_PRINT_DONE;
                        msg_base <= 8'd128; // MCU TAKEOVER
                        rom_ptr  <= 8'd128;
                    end else if (!uart_tx_busy && !tx_req) begin
                        tx_req <= 1'b1;
                    end else if (uart_tx_busy && tx_req) begin
                        tx_req  <= 1'b0;
                        rom_ptr <= rom_ptr + 1'b1;
                    end
                end
                
                S_PRINT_DONE: begin
                    if (char_rom[rom_ptr] == 8'd0) begin
                        state <= S_HANDOVER;
                    end else if (!uart_tx_busy && !tx_req) begin
                        tx_req <= 1'b1;
                    end else if (uart_tx_busy && tx_req) begin
                        tx_req  <= 1'b0;
                        rom_ptr <= rom_ptr + 1'b1;
                    end
                end
                
                S_HANDOVER: begin
                    handover_to_mcu <= 1'b1; // Switch the top-level MUX!
                end
            endcase
        end
    end
endmodule
