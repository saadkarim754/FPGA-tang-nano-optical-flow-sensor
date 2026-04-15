//============================================================================
// FAST-9 Corner Detector (3-Stage Pipeline)
// Implements the FAST (Features from Accelerated Segment Test) algorithm
// Tests 16 pixels on a Bresenham circle of radius 3
// Detects corners where 9+ contiguous pixels are brighter/darker than center
//
// Window input is FLATTENED 392-bit bus:
//   window_flat[ row*56 + col*8 +: 8 ] = pixel at (row, col)
//============================================================================
module fast_detector (
    input  wire         clk,
    input  wire         rst_n,
    
    // Threshold (configurable via AHB register)
    input  wire [4:0]   threshold,    // FAST intensity threshold (typical: 2-6 for 5-bit)
    input  wire         enable,       // Detection enable
    
    // Input: 7x7 pixel window from line buffer (flattened)
    input  wire [244:0] window_flat,
    input  wire         window_valid,
    input  wire [9:0]   center_x,
    input  wire [8:0]   center_y,
    
    // Output: detected feature coordinates
    output reg  [9:0]   feature_x,
    output reg  [8:0]   feature_y,
    output reg          feature_valid
);

    //------------------------------------------------------------------------
    // Helper: extract pixel at (row, col) from flat bus
    // window_flat[ row*35 + col*5 +: 5 ]
    //------------------------------------------------------------------------
    `define WP(r, c) window_flat[((r)*35 + (c)*5) +: 5]
    
    //------------------------------------------------------------------------
    // Extract center pixel and 16 circle pixels from the 7x7 window
    //------------------------------------------------------------------------
    // Circle pixel positions (Bresenham radius=3, indexed from top-left of 7x7):
    //   P1:  [0][3]    P2:  [0][4]    P3:  [1][5]
    //   P4:  [2][6]    P5:  [3][6]    P6:  [4][6]
    //   P7:  [5][5]    P8:  [6][4]    P9:  [6][3]
    //   P10: [6][2]    P11: [5][1]    P12: [4][0]
    //   P13: [3][0]    P14: [2][0]    P15: [1][1]
    //   P16: [0][2]
    //   Center: [3][3]
    
    wire [4:0] center = `WP(3, 3);
    
    wire [4:0] p1  = `WP(0, 3);
    wire [4:0] p2  = `WP(0, 4);
    wire [4:0] p3  = `WP(1, 5);
    wire [4:0] p4  = `WP(2, 6);
    wire [4:0] p5  = `WP(3, 6);
    wire [4:0] p6  = `WP(4, 6);
    wire [4:0] p7  = `WP(5, 5);
    wire [4:0] p8  = `WP(6, 4);
    wire [4:0] p9  = `WP(6, 3);
    wire [4:0] p10 = `WP(6, 2);
    wire [4:0] p11 = `WP(5, 1);
    wire [4:0] p12 = `WP(4, 0);
    wire [4:0] p13 = `WP(3, 0);
    wire [4:0] p14 = `WP(2, 0);
    wire [4:0] p15 = `WP(1, 1);
    wire [4:0] p16 = `WP(0, 2);
    
    //========================================================================
    // PIPELINE STAGE 1: High-Speed Pre-Screen Test + Compare All 16
    //========================================================================
    reg        stage1_valid;
    reg [9:0]  stage1_x;
    reg [8:0]  stage1_y;
    reg        stage1_pass;
    reg [15:0] stage1_bright;
    reg [15:0] stage1_dark;
    
    // Thresholded center values (with saturation up to 6 bits)
    wire [5:0] center_plus_t  = {1'b0, center} + {1'b0, threshold};
    wire [5:0] center_minus_t = (center > threshold) ? {1'b0, center} - {1'b0, threshold} : 6'd0;
    wire [4:0] upper = (center_plus_t[5]) ? 5'h1F : center_plus_t[4:0];
    wire [4:0] lower = center_minus_t[4:0];
    
    // Pre-screen: check cardinal directions (P1, P5, P9, P13)
    wire p1_bright  = (p1  > upper);
    wire p5_bright  = (p5  > upper);
    wire p9_bright  = (p9  > upper);
    wire p13_bright = (p13 > upper);
    wire p1_dark    = (p1  < lower);
    wire p5_dark    = (p5  < lower);
    wire p9_dark    = (p9  < lower);
    wire p13_dark   = (p13 < lower);
    
    wire [2:0] prescreen_bright = p1_bright + p5_bright + p9_bright + p13_bright;
    wire [2:0] prescreen_dark   = p1_dark + p5_dark + p9_dark + p13_dark;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_valid <= 1'b0;
            stage1_pass  <= 1'b0;
        end else begin
            stage1_valid <= window_valid & enable;
            stage1_pass  <= (prescreen_bright >= 3'd3) || (prescreen_dark >= 3'd3);
        end
    end

    // Removed asynchronous reset from datapath entirely
    // This allows massively denser routing in the congested LUT/FF pools
    always @(posedge clk) begin
        if (window_valid & enable) begin
            stage1_x     <= center_x;
            stage1_y     <= center_y;
            
            stage1_bright[ 0] <= (p1  > upper);
            stage1_bright[ 1] <= (p2  > upper);
            stage1_bright[ 2] <= (p3  > upper);
            stage1_bright[ 3] <= (p4  > upper);
            stage1_bright[ 4] <= (p5  > upper);
            stage1_bright[ 5] <= (p6  > upper);
            stage1_bright[ 6] <= (p7  > upper);
            stage1_bright[ 7] <= (p8  > upper);
            stage1_bright[ 8] <= (p9  > upper);
            stage1_bright[ 9] <= (p10 > upper);
            stage1_bright[10] <= (p11 > upper);
            stage1_bright[11] <= (p12 > upper);
            stage1_bright[12] <= (p13 > upper);
            stage1_bright[13] <= (p14 > upper);
            stage1_bright[14] <= (p15 > upper);
            stage1_bright[15] <= (p16 > upper);
            
            stage1_dark[ 0] <= (p1  < lower);
            stage1_dark[ 1] <= (p2  < lower);
            stage1_dark[ 2] <= (p3  < lower);
            stage1_dark[ 3] <= (p4  < lower);
            stage1_dark[ 4] <= (p5  < lower);
            stage1_dark[ 5] <= (p6  < lower);
            stage1_dark[ 6] <= (p7  < lower);
            stage1_dark[ 7] <= (p8  < lower);
            stage1_dark[ 8] <= (p9  < lower);
            stage1_dark[ 9] <= (p10 < lower);
            stage1_dark[10] <= (p11 < lower);
            stage1_dark[11] <= (p12 < lower);
            stage1_dark[12] <= (p13 < lower);
            stage1_dark[13] <= (p14 < lower);
            stage1_dark[14] <= (p15 < lower);
            stage1_dark[15] <= (p16 < lower);
        end
    end
    
    //========================================================================
    // PIPELINE STAGE 2: Full Contiguity Check
    // Check if 9+ contiguous pixels in the circle are all brighter or darker
    // Duplicate 16-bit mask to 32 bits and check for 9 consecutive 1s
    //========================================================================
    reg        stage2_valid;
    reg [9:0]  stage2_x;
    reg [8:0]  stage2_y;
    reg        stage2_is_corner;
    
    // Check for 9 consecutive 1s in a 16-bit circular mask
    wire [31:0] bright_doubled = {stage1_bright, stage1_bright};
    wire [31:0] dark_doubled   = {stage1_dark, stage1_dark};
    
    // Check each starting position
    wire bright_contig =
        (&bright_doubled[ 8: 0]) | (&bright_doubled[ 9: 1]) |
        (&bright_doubled[10: 2]) | (&bright_doubled[11: 3]) |
        (&bright_doubled[12: 4]) | (&bright_doubled[13: 5]) |
        (&bright_doubled[14: 6]) | (&bright_doubled[15: 7]) |
        (&bright_doubled[16: 8]) | (&bright_doubled[17: 9]) |
        (&bright_doubled[18:10]) | (&bright_doubled[19:11]) |
        (&bright_doubled[20:12]) | (&bright_doubled[21:13]) |
        (&bright_doubled[22:14]) | (&bright_doubled[23:15]);
    
    wire dark_contig =
        (&dark_doubled[ 8: 0]) | (&dark_doubled[ 9: 1]) |
        (&dark_doubled[10: 2]) | (&dark_doubled[11: 3]) |
        (&dark_doubled[12: 4]) | (&dark_doubled[13: 5]) |
        (&dark_doubled[14: 6]) | (&dark_doubled[15: 7]) |
        (&dark_doubled[16: 8]) | (&dark_doubled[17: 9]) |
        (&dark_doubled[18:10]) | (&dark_doubled[19:11]) |
        (&dark_doubled[20:12]) | (&dark_doubled[21:13]) |
        (&dark_doubled[22:14]) | (&dark_doubled[23:15]);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_valid     <= 1'b0;
        end else begin
            stage2_valid <= stage1_valid & stage1_pass;
        end
    end

    always @(posedge clk) begin
        if (stage1_valid & stage1_pass) begin
            stage2_x     <= stage1_x;
            stage2_y     <= stage1_y;
            
            if (stage1_pass)
                stage2_is_corner <= bright_contig | dark_contig;
            else
                stage2_is_corner <= 1'b0;
        end
    end
    
    //========================================================================
    // PIPELINE STAGE 3: Output valid feature coordinates
    // Boundary exclusion: skip features within 3 pixels of image border
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            feature_valid <= 1'b0;
        end else begin
            feature_valid <= 1'b0;
            if (stage2_valid && stage2_is_corner) begin
                if (stage2_x >= 10'd3 && stage2_x < 10'd317 &&
                    stage2_y >= 9'd3  && stage2_y < 9'd237) begin
                    feature_valid <= 1'b1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (stage2_valid && stage2_is_corner) begin
            if (stage2_x >= 10'd3 && stage2_x < 10'd317 &&
                stage2_y >= 9'd3  && stage2_y < 9'd237) begin
                feature_x     <= stage2_x;
                feature_y     <= stage2_y;
            end
        end
    end
    
    `undef WP

endmodule
