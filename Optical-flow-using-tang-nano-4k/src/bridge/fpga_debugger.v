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
    input  wire       uart_tx_done,
    
    input  wire       dvp_pclk,
    input  wire       dvp_vsync,

    output reg        handover_to_mcu,

    // Exported debug telemetry
    output wire [3:0] dbg_state,
    output wire       dbg_pclk_seen,
    output wire       dbg_vsync_seen,
    output wire       dbg_timeout_hit,
    output wire [15:0] dbg_pclk_edges,
    output wire [15:0] dbg_vsync_edges,
    output wire [31:0] dbg_frame_timeout
);

    // ASCII ROM Messages
    // Msg 0: [FPGA][S1] Booting...
    // Msg 1: [FPGA][S2] OV2640 OK!
    // Msg 2: [CAM][S3] PCLK&VSYNC ALIVE
    
    reg [7:0] char_rom [0:255];
    initial begin
        // Initialize memory with spaces/nulls
        // Msg 0 (Start idx 0): [FPGA][S1] Booting...
        char_rom[0]  = "["; char_rom[1]  = "F"; char_rom[2]  = "P"; char_rom[3]  = "G";
        char_rom[4]  = "A"; char_rom[5]  = "]"; char_rom[6]  = "["; char_rom[7]  = "S";
        char_rom[8]  = "1"; char_rom[9]  = "]"; char_rom[10] = " "; char_rom[11] = "B";
        char_rom[12] = "o"; char_rom[13] = "o"; char_rom[14] = "t"; char_rom[15] = "i";
        char_rom[16] = "n"; char_rom[17] = "g"; char_rom[18] = "."; char_rom[19] = ".";
        char_rom[20] = "."; char_rom[21] = 8'h0D; char_rom[22] = 8'h0A; char_rom[23] = 0;

        // Msg 1 (Start idx 32): [FPGA][S2] OV2640 OK!
        char_rom[32] = "["; char_rom[33] = "F"; char_rom[34] = "P"; char_rom[35] = "G";
        char_rom[36] = "A"; char_rom[37] = "]"; char_rom[38] = "["; char_rom[39] = "S";
        char_rom[40] = "2"; char_rom[41] = "]"; char_rom[42] = " "; char_rom[43] = "O";
        char_rom[44] = "V"; char_rom[45] = "2"; char_rom[46] = "6"; char_rom[47] = "4";
        char_rom[48] = "0"; char_rom[49] = " "; char_rom[50] = "O"; char_rom[51] = "K";
        char_rom[52] = "!"; char_rom[53] = 8'h0D; char_rom[54] = 8'h0A; char_rom[55] = 0;

        // Msg 2 (Start idx 64): [CAM][S3] PCLK&VSYNC ALIVE
        char_rom[64] = "["; char_rom[65] = "C"; char_rom[66] = "A"; char_rom[67] = "M";
        char_rom[68] = "]"; char_rom[69] = "["; char_rom[70] = "S"; char_rom[71] = "3";
        char_rom[72] = "]"; char_rom[73] = " "; char_rom[74] = "P"; char_rom[75] = "C";
        char_rom[76] = "L"; char_rom[77] = "K"; char_rom[78] = "&"; char_rom[79] = "V";
        char_rom[80] = "S"; char_rom[81] = "Y"; char_rom[82] = "N"; char_rom[83] = "C";
        char_rom[84] = " "; char_rom[85] = "A"; char_rom[86] = "L"; char_rom[87] = "I";
        char_rom[88] = "V"; char_rom[89] = "E"; char_rom[90] = 8'h0D; char_rom[91] = 8'h0A;
        char_rom[92] = 0;

        // Msg 3 (Start idx 96): [CAM][S3] DEAD NO FRAMES
        char_rom[96] = "["; char_rom[97] = "C"; char_rom[98] = "A"; char_rom[99] = "M";
        char_rom[100] = "]"; char_rom[101] = "["; char_rom[102] = "S"; char_rom[103] = "3";
        char_rom[104] = "]"; char_rom[105] = " "; char_rom[106] = "D"; char_rom[107] = "E";
        char_rom[108] = "A"; char_rom[109] = "D"; char_rom[110] = " "; char_rom[111] = "N";
        char_rom[112] = "O"; char_rom[113] = " "; char_rom[114] = "F"; char_rom[115] = "R";
        char_rom[116] = "A"; char_rom[117] = "M"; char_rom[118] = "E"; char_rom[119] = "S";
        char_rom[120] = 8'h0D; char_rom[121] = 8'h0A; char_rom[122] = 0;

        // Msg 4 (Start idx 128): [FPGA][S4] MCU TAKEOVER
        char_rom[128] = "["; char_rom[129] = "F"; char_rom[130] = "P"; char_rom[131] = "G";
        char_rom[132] = "A"; char_rom[133] = "]"; char_rom[134] = "["; char_rom[135] = "S";
        char_rom[136] = "4"; char_rom[137] = "]"; char_rom[138] = " "; char_rom[139] = "M";
        char_rom[140] = "C"; char_rom[141] = "U"; char_rom[142] = " "; char_rom[143] = "T";
        char_rom[144] = "A"; char_rom[145] = "K"; char_rom[146] = "E"; char_rom[147] = "O";
        char_rom[148] = "V"; char_rom[149] = "E"; char_rom[150] = "R"; char_rom[151] = 8'h0D;
        char_rom[152] = 8'h0A; char_rom[153] = 0;

        // Msg 5 (Start idx 160): [ERR][S3] NO PCLK!
        char_rom[160] = "["; char_rom[161] = "E"; char_rom[162] = "R"; char_rom[163] = "R";
        char_rom[164] = "]"; char_rom[165] = "["; char_rom[166] = "S"; char_rom[167] = "3";
        char_rom[168] = "]"; char_rom[169] = " "; char_rom[170] = "N"; char_rom[171] = "O";
        char_rom[172] = " "; char_rom[173] = "P"; char_rom[174] = "C"; char_rom[175] = "L";
        char_rom[176] = "K"; char_rom[177] = "!"; char_rom[178] = 8'h0D; char_rom[179] = 8'h0A;
        char_rom[180] = 0;

        // Msg 6 (Start idx 192): [ERR][S3] NO VSYNC!
        char_rom[192] = "["; char_rom[193] = "E"; char_rom[194] = "R"; char_rom[195] = "R";
        char_rom[196] = "]"; char_rom[197] = "["; char_rom[198] = "S"; char_rom[199] = "3";
        char_rom[200] = "]"; char_rom[201] = " "; char_rom[202] = "N"; char_rom[203] = "O";
        char_rom[204] = " "; char_rom[205] = "V"; char_rom[206] = "S"; char_rom[207] = "Y";
        char_rom[208] = "N"; char_rom[209] = "C"; char_rom[210] = "!"; char_rom[211] = 8'h0D;
        char_rom[212] = 8'h0A; char_rom[213] = 0;
    end

    localparam S_START        = 0;
    localparam S_PRINT_BOOT   = 1;
    localparam S_WAIT_CAM     = 2;
    localparam S_PRINT_CAM_OK = 3;
    localparam S_WAIT_FRAME   = 4;
    localparam S_PRINT_DONE   = 5;
    localparam S_HANDOVER     = 6;

    localparam S_PRINT_CAM_STATS = 7;
    localparam [15:0] HANDOVER_GUARD_CYCLES = 16'd27000;  // ~1ms at 27MHz

    reg [3:0] state;
    reg [7:0] rom_ptr;
    reg [7:0] msg_base;
    reg       tx_req;
    reg [7:0] tx_data_latched;
    
    assign uart_tx_start = tx_req;
    assign uart_tx_data  = tx_data_latched;

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
    reg        timeout_hit;
    reg [15:0] handover_guard;

    assign dbg_state         = state;
    assign dbg_pclk_seen     = (pclk_ticks != 24'd0);
    assign dbg_vsync_seen    = (vsync_ticks != 16'd0);
    assign dbg_timeout_hit   = timeout_hit;
    assign dbg_pclk_edges    = pclk_ticks[15:0];
    assign dbg_vsync_edges   = vsync_ticks;
    assign dbg_frame_timeout = {6'd0, frame_timeout};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_START;
            rom_ptr         <= 8'd0;
            msg_base        <= 8'd0;
            tx_req          <= 1'b0;
            tx_data_latched <= 8'd0;
            handover_to_mcu <= 1'b0;
            startup_delay   <= 24'd0;
            frame_timeout   <= 26'd0;
            pclk_ticks      <= 24'd0;
            vsync_ticks     <= 16'd0;
            timeout_hit     <= 1'b0;
            handover_guard  <= 16'd0;
        end else begin
            // One-cycle strobe by default.
            tx_req <= 1'b0;

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
                    end else if (uart_tx_done) begin
                        rom_ptr <= rom_ptr + 1'b1;
                    end else if (!uart_tx_busy) begin
                        tx_data_latched <= char_rom[rom_ptr];
                        tx_req          <= 1'b1;
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
                    end else if (uart_tx_done) begin
                        rom_ptr <= rom_ptr + 1'b1;
                    end else if (!uart_tx_busy) begin
                        tx_data_latched <= char_rom[rom_ptr];
                        tx_req          <= 1'b1;
                    end
                end
                
                S_WAIT_FRAME: begin
                    if (pclk_edge) pclk_ticks <= pclk_ticks + 1'b1;
                    if (vsync_edge) vsync_ticks <= vsync_ticks + 1'b1;

                    if (first_frame_seen) begin
                        timeout_hit <= 1'b0;
                        state    <= S_PRINT_CAM_STATS;
                        msg_base <= 8'd64; // PCLK ALIVE
                        rom_ptr  <= 8'd64;
                    end else if (frame_timeout == 26'd54_000_000) begin
                        timeout_hit <= 1'b1;
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
                    end else if (uart_tx_done) begin
                        rom_ptr <= rom_ptr + 1'b1;
                    end else if (!uart_tx_busy) begin
                        tx_data_latched <= char_rom[rom_ptr];
                        tx_req          <= 1'b1;
                    end
                end
                
                S_PRINT_DONE: begin
                    if (char_rom[rom_ptr] == 8'd0) begin
                        if (!uart_tx_busy) begin
                            state <= S_HANDOVER;
                            handover_guard <= HANDOVER_GUARD_CYCLES;
                        end
                    end else if (uart_tx_done) begin
                        rom_ptr <= rom_ptr + 1'b1;
                    end else if (!uart_tx_busy) begin
                        tx_data_latched <= char_rom[rom_ptr];
                        tx_req          <= 1'b1;
                    end
                end
                
                S_HANDOVER: begin
                    if (handover_guard != 16'd0)
                        handover_guard <= handover_guard - 1'b1;
                    else
                        handover_to_mcu <= 1'b1; // Switch the top-level MUX after guard period.
                end
            endcase
        end
    end
endmodule
