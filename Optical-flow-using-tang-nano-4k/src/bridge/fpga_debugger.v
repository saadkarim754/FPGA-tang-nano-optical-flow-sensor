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
    
    output reg        handover_to_mcu
);

    // ASCII ROM Messages
    // Msg 0: "[FPGA] Booting...\r\n"
    // Msg 1: "[FPGA] OV2640 Configured!\r\n"
    // Msg 2: "[FPGA] Frame 1 OK! MCU Handover.\r\n"
    
    reg [7:0] char_rom [0:127];
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
        
        // Msg 2 (Start idx 64)
        char_rom[64] = "["; char_rom[65] = "F"; char_rom[66] = "P"; char_rom[67] = "G";
        char_rom[68] = "A"; char_rom[69] = "]"; char_rom[70] = " "; char_rom[71] = "M";
        char_rom[72] = "C"; char_rom[73] = "U"; char_rom[74] = " "; char_rom[75] = "T";
        char_rom[76] = "A"; char_rom[77] = "K"; char_rom[78] = "E"; char_rom[79] = "O";
        char_rom[80] = "V"; char_rom[81] = "E"; char_rom[82] = "R"; char_rom[83] = 8'h0D;
        char_rom[84] = 8'h0A; char_rom[85] = 0;
    end

    localparam S_START        = 0;
    localparam S_PRINT_BOOT   = 1;
    localparam S_WAIT_CAM     = 2;
    localparam S_PRINT_CAM_OK = 3;
    localparam S_WAIT_FRAME   = 4;
    localparam S_PRINT_DONE   = 5;
    localparam S_HANDOVER     = 6;

    reg [2:0] state;
    reg [6:0] rom_ptr;
    reg [6:0] msg_base;
    reg       tx_req;
    
    assign uart_tx_start = tx_req;
    assign uart_tx_data  = char_rom[rom_ptr];

    // Give some time on start for PuTTY to catch up
    reg [23:0] startup_delay;
    reg [25:0] frame_timeout;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_START;
            rom_ptr         <= 7'd0;
            msg_base        <= 7'd0;
            tx_req          <= 1'b0;
            handover_to_mcu <= 1'b0;
            startup_delay   <= 24'd0;
            frame_timeout   <= 26'd0;
        end else begin
            case (state)
                S_START: begin
                    if (startup_delay == 24'd5_000_000) begin
                        state    <= S_PRINT_BOOT;
                        msg_base <= 7'd0;
                        rom_ptr  <= 7'd0;
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
                        msg_base <= 7'd32;
                        rom_ptr  <= 7'd32;
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
                    if (first_frame_seen || frame_timeout == 26'd54_000_000) begin
                        state    <= S_PRINT_DONE;
                        msg_base <= 7'd64;
                        rom_ptr  <= 7'd64;
                    end else begin
                        frame_timeout <= frame_timeout + 1'b1;
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
