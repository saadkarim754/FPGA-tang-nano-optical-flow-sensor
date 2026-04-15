//============================================================================
// 7-Line Buffer with 7x7 Window Extraction
// B-SRAM OPTIMIZED PACKED SHIFT REGISTER
// 5-BIT GRAYSCALE PRECISION (Ultra-Lightweight logic variant)
//============================================================================
module line_buffer (
    input  wire        clk,
    input  wire        rst_n, // Kept only for counters
    
    // Input pixel stream (Truncated to 5-bits to save hundreds of DFFs)
    input  wire [4:0]  pixel_in,
    input  wire        pixel_valid,
    input  wire [9:0]  pixel_x,
    input  wire [8:0]  pixel_y,
    
    // Output: 7x7 pixel window (flattened, 49 * 5 = 245 bits) + center coordinate
    output wire [244:0] window_flat,
    output reg          window_valid,
    output reg  [9:0]   center_x,
    output reg  [8:0]   center_y
);
    parameter IMG_WIDTH = 320;

    //------------------------------------------------------------------------
    // Cascaded Line Delays -> Packed BRAMs!
    //------------------------------------------------------------------------
    wire [4:0] line_out_0, line_out_1, line_out_2, line_out_3;
    wire [4:0] line_out_4, line_out_5;

    // Pack lines 0, 1, 2, 3 into a single 32-bit BRAM
    line_packed_delay_4x u_packed_4 (
        .clk(clk), .ce(pixel_valid), .din(pixel_in), 
        .dout0(line_out_0), .dout1(line_out_1),
        .dout2(line_out_2), .dout3(line_out_3)
    );

    // Pack lines 4, 5 into a 16-bit BRAM
    line_packed_delay_2x u_packed_2 (
        .clk(clk), .ce(pixel_valid), .din(line_out_3), 
        .dout0(line_out_4), .dout1(line_out_5)
    );

    //------------------------------------------------------------------------
    // Row pixel assignments
    //------------------------------------------------------------------------
    wire [4:0] row_pixel_0 = pixel_in;
    wire [4:0] row_pixel_1 = line_out_0;
    wire [4:0] row_pixel_2 = line_out_1;
    wire [4:0] row_pixel_3 = line_out_2;
    wire [4:0] row_pixel_4 = line_out_3;
    wire [4:0] row_pixel_5 = line_out_4;
    wire [4:0] row_pixel_6 = line_out_5;
    
    //------------------------------------------------------------------------
    // Shift registers (5-bit)
    // NO asynchronous reset! This saves immense routing congestion.
    //------------------------------------------------------------------------
    reg [4:0] sr_0_0, sr_0_1, sr_0_2, sr_0_3, sr_0_4, sr_0_5, sr_0_6;
    reg [4:0] sr_1_0, sr_1_1, sr_1_2, sr_1_3, sr_1_4, sr_1_5, sr_1_6;
    reg [4:0] sr_2_0, sr_2_1, sr_2_2, sr_2_3, sr_2_4, sr_2_5, sr_2_6;
    reg [4:0] sr_3_0, sr_3_1, sr_3_2, sr_3_3, sr_3_4, sr_3_5, sr_3_6;
    reg [4:0] sr_4_0, sr_4_1, sr_4_2, sr_4_3, sr_4_4, sr_4_5, sr_4_6;
    reg [4:0] sr_5_0, sr_5_1, sr_5_2, sr_5_3, sr_5_4, sr_5_5, sr_5_6;
    reg [4:0] sr_6_0, sr_6_1, sr_6_2, sr_6_3, sr_6_4, sr_6_5, sr_6_6;
    
    always @(posedge clk) begin
        if (pixel_valid) begin
            sr_0_6<=sr_0_5; sr_0_5<=sr_0_4; sr_0_4<=sr_0_3; sr_0_3<=sr_0_2; sr_0_2<=sr_0_1; sr_0_1<=sr_0_0; sr_0_0<=row_pixel_0;
            sr_1_6<=sr_1_5; sr_1_5<=sr_1_4; sr_1_4<=sr_1_3; sr_1_3<=sr_1_2; sr_1_2<=sr_1_1; sr_1_1<=sr_1_0; sr_1_0<=row_pixel_1;
            sr_2_6<=sr_2_5; sr_2_5<=sr_2_4; sr_2_4<=sr_2_3; sr_2_3<=sr_2_2; sr_2_2<=sr_2_1; sr_2_1<=sr_2_0; sr_2_0<=row_pixel_2;
            sr_3_6<=sr_3_5; sr_3_5<=sr_3_4; sr_3_4<=sr_3_3; sr_3_3<=sr_3_2; sr_3_2<=sr_3_1; sr_3_1<=sr_3_0; sr_3_0<=row_pixel_3;
            sr_4_6<=sr_4_5; sr_4_5<=sr_4_4; sr_4_4<=sr_4_3; sr_4_3<=sr_4_2; sr_4_2<=sr_4_1; sr_4_1<=sr_4_0; sr_4_0<=row_pixel_4;
            sr_5_6<=sr_5_5; sr_5_5<=sr_5_4; sr_5_4<=sr_5_3; sr_5_3<=sr_5_2; sr_5_2<=sr_5_1; sr_5_1<=sr_5_0; sr_5_0<=row_pixel_5;
            sr_6_6<=sr_6_5; sr_6_5<=sr_6_4; sr_6_4<=sr_6_3; sr_6_3<=sr_6_2; sr_6_2<=sr_6_1; sr_6_1<=sr_6_0; sr_6_0<=row_pixel_6;
        end
    end
    
    //------------------------------------------------------------------------
    // Output window (flattened)
    //------------------------------------------------------------------------
    assign window_flat[  4:  0] = sr_6_6;    assign window_flat[  9:  5] = sr_6_5;
    assign window_flat[ 14: 10] = sr_6_4;    assign window_flat[ 19: 15] = sr_6_3;
    assign window_flat[ 24: 20] = sr_6_2;    assign window_flat[ 29: 25] = sr_6_1;
    assign window_flat[ 34: 30] = sr_6_0;    assign window_flat[ 39: 35] = sr_5_6;
    assign window_flat[ 44: 40] = sr_5_5;    assign window_flat[ 49: 45] = sr_5_4;
    assign window_flat[ 54: 50] = sr_5_3;    assign window_flat[ 59: 55] = sr_5_2;
    assign window_flat[ 64: 60] = sr_5_1;    assign window_flat[ 69: 65] = sr_5_0;
    assign window_flat[ 74: 70] = sr_4_6;    assign window_flat[ 79: 75] = sr_4_5;
    assign window_flat[ 84: 80] = sr_4_4;    assign window_flat[ 89: 85] = sr_4_3;
    assign window_flat[ 94: 90] = sr_4_2;    assign window_flat[ 99: 95] = sr_4_1;
    assign window_flat[104:100] = sr_4_0;    assign window_flat[109:105] = sr_3_6;
    assign window_flat[114:110] = sr_3_5;    assign window_flat[119:115] = sr_3_4;
    assign window_flat[124:120] = sr_3_3;    assign window_flat[129:125] = sr_3_2;
    assign window_flat[134:130] = sr_3_1;    assign window_flat[139:135] = sr_3_0;
    assign window_flat[144:140] = sr_2_6;    assign window_flat[149:145] = sr_2_5;
    assign window_flat[154:150] = sr_2_4;    assign window_flat[159:155] = sr_2_3;
    assign window_flat[164:160] = sr_2_2;    assign window_flat[169:165] = sr_2_1;
    assign window_flat[174:170] = sr_2_0;    assign window_flat[179:175] = sr_1_6;
    assign window_flat[184:180] = sr_1_5;    assign window_flat[189:185] = sr_1_4;
    assign window_flat[194:190] = sr_1_3;    assign window_flat[199:195] = sr_1_2;
    assign window_flat[204:200] = sr_1_1;    assign window_flat[209:205] = sr_1_0;
    assign window_flat[214:210] = sr_0_6;    assign window_flat[219:215] = sr_0_5;
    assign window_flat[224:220] = sr_0_4;    assign window_flat[229:225] = sr_0_3;
    assign window_flat[234:230] = sr_0_2;    assign window_flat[239:235] = sr_0_1;
    assign window_flat[244:240] = sr_0_0;
    
    //------------------------------------------------------------------------
    // Window valid
    //------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            window_valid <= 1'b0;
            center_x     <= 10'd0;
            center_y     <= 9'd0;
        end else begin
            window_valid <= pixel_valid && (pixel_x >= 10'd6) && (pixel_y >= 9'd6);
            if (pixel_valid) begin
                center_x <= (pixel_x >= 10'd3) ? pixel_x - 10'd3 : 10'd0;
                center_y <= (pixel_y >= 9'd3)  ? pixel_y - 9'd3  : 9'd0;
            end
        end
    end
endmodule

//============================================================================
// Packed line delay (4 delays in 1 B-SRAM)
//============================================================================
module line_packed_delay_4x (
    input  wire        clk,
    input  wire        ce,
    input  wire [4:0]  din,
    output wire [4:0]  dout0,    // Delayed 1x
    output wire [4:0]  dout1,    // Delayed 2x
    output wire [4:0]  dout2,    // Delayed 3x
    output wire [4:0]  dout3     // Delayed 4x
);
    parameter DEPTH = 320;
    (* ram_style = "block_ram" *) reg [31:0] mem [0:511];

    reg [8:0] wr_ptr = 9'd0;
    reg [8:0] rd_ptr = 9'd512 - (DEPTH[8:0] - 1'b1);

    always @(posedge clk) begin
        if (ce) begin
            wr_ptr <= wr_ptr + 1'b1;
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    reg [31:0] rd_data;
    always @(posedge clk) begin
        if (ce) begin
            rd_data <= mem[rd_ptr];
            mem[wr_ptr] <= {12'd0, dout2, dout1, dout0, din};
        end
    end

    assign dout0 = rd_data[4:0];
    assign dout1 = rd_data[9:5];
    assign dout2 = rd_data[14:10];
    assign dout3 = rd_data[19:15];
endmodule

//============================================================================
// Packed line delay (2 delays in 1 B-SRAM)
//============================================================================
module line_packed_delay_2x (
    input  wire        clk,
    input  wire        ce,
    input  wire [4:0]  din,
    output wire [4:0]  dout0,
    output wire [4:0]  dout1
);
    parameter DEPTH = 320;
    (* ram_style = "block_ram" *) reg [15:0] mem [0:511];

    reg [8:0] wr_ptr = 9'd0;
    reg [8:0] rd_ptr = 9'd512 - (DEPTH[8:0] - 1'b1);

    always @(posedge clk) begin
        if (ce) begin
            wr_ptr <= wr_ptr + 1'b1;
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    reg [15:0] rd_data;
    always @(posedge clk) begin
        if (ce) begin
            rd_data <= mem[rd_ptr];
            mem[wr_ptr] <= {6'd0, dout0, din};
        end
    end

    assign dout0 = rd_data[4:0];
    assign dout1 = rd_data[9:5];
endmodule
