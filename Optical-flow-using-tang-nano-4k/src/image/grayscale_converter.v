//============================================================================
// RGB565 to 8-bit Grayscale Converter
// Uses luminance approximation: Y ≈ (R*77 + G*150 + B*29) >> 8
// Pure combinational logic — zero latency
//============================================================================
module grayscale_converter (
    input  wire        clk,          // System clock
    input  wire        rst_n,        // Active-low reset
    
    // Input: RGB565 pixel from DVP receiver
    input  wire [15:0] rgb565,       // RGB565: R[15:11] G[10:5] B[4:0]
    input  wire        pixel_valid_in,
    input  wire [9:0]  pixel_x_in,
    input  wire [8:0]  pixel_y_in,
    
    // Output: 8-bit grayscale pixel (1 clock cycle latency for registered output)
    output reg  [7:0]  gray_pixel,
    output reg         pixel_valid_out,
    output reg  [9:0]  pixel_x_out,
    output reg  [8:0]  pixel_y_out
);

    // Extract and extend RGB channels to 8 bits
    wire [7:0] r8 = {rgb565[15:11], rgb565[15:13]};  // 5-bit R -> 8-bit
    wire [7:0] g8 = {rgb565[10:5],  rgb565[10:9]};   // 6-bit G -> 8-bit
    wire [7:0] b8 = {rgb565[4:0],   rgb565[4:2]};    // 5-bit B -> 8-bit
    
    // Luminance calculation: Y = (R*77 + G*150 + B*29) >> 8
    // Max value: (255*77 + 255*150 + 255*29) = 255*256 = 65280
    // After >>8: 255 (fits in 8 bits perfectly)
    wire [15:0] y_sum = r8 * 8'd77 + g8 * 8'd150 + b8 * 8'd29;
    
    // Register output for timing closure
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gray_pixel      <= 8'd0;
            pixel_valid_out <= 1'b0;
            pixel_x_out     <= 10'd0;
            pixel_y_out     <= 9'd0;
        end else begin
            pixel_valid_out <= pixel_valid_in;
            pixel_x_out     <= pixel_x_in;
            pixel_y_out     <= pixel_y_in;
            
            if (pixel_valid_in)
                gray_pixel <= y_sum[15:8];  // >>8
            else
                gray_pixel <= 8'd0;
        end
    end

endmodule
