//============================================================================
// DVP Camera Receiver for OV2640 (Ultra-Lightweight 5-bit Grayscale)
//============================================================================
module dvp_receiver (
    input  wire        clk,          // System clock
    input  wire        rst_n,        // Active-low reset
    
    // DVP camera interface
    input  wire        dvp_pclk,     
    input  wire        dvp_vsync,    
    input  wire        dvp_href,     
    input  wire [7:0]  dvp_data,     
    
    // Output interface (synchronized to system clock)
    output reg  [4:0]  pixel_data,   // 5-bit Grayscale! (Massive DFF saving)
    output reg         pixel_valid,  
    output reg  [9:0]  pixel_x,      
    output reg  [8:0]  pixel_y,      
    output reg         frame_start,  
    output reg         frame_done    
);

    //------------------------------------------------------------------------
    // PCLK Domain: Extract Grayscale immediately
    //------------------------------------------------------------------------
    reg [4:0]  gray_latch;           
    reg        byte_toggle;          
    reg [4:0]  gray_pixel;           
    reg        pixel_ready;     
    
    reg        vsync_d1;
    wire       vsync_falling = vsync_d1 & ~dvp_vsync;
    
    always @(posedge dvp_pclk) begin
        // Removed reset on data-paths to drastically improve dense placement!
        vsync_d1 <= dvp_vsync;
        pixel_ready <= 1'b0;
        
        if (vsync_falling) begin
            byte_toggle <= 1'b0;
        end
        
        if (dvp_href) begin
            if (!byte_toggle) begin
                // First byte of RGB565 is R[4:0], G[5:3]
                // We extract the top 3 bits of Green (dvp_data[2:0])
                gray_latch[4:2] <= dvp_data[2:0];
                byte_toggle <= 1'b1;
            end else begin
                // Second byte is G[2:0], B[4:0]
                // We extract the next 2 bits of Green (dvp_data[7:6])
                gray_pixel <= {gray_latch[4:2], dvp_data[7:6]};
                pixel_ready <= 1'b1;
                byte_toggle <= 1'b0;
            end
        end else begin
            byte_toggle <= 1'b0;
        end
    end

    //------------------------------------------------------------------------
    // Clock Domain Crossing: PCLK -> System Clock
    //------------------------------------------------------------------------
    reg [2:0] vsync_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) vsync_sync <= 3'b0;
        else vsync_sync <= {vsync_sync[1:0], dvp_vsync};
    end
    wire vsync_sys = vsync_sync[2];
    reg  vsync_sys_d1;
    wire vsync_sys_falling = vsync_sys_d1 & ~vsync_sys;
    wire vsync_sys_rising  = ~vsync_sys_d1 & vsync_sys;
    
    // Toggle-based CDC for valid pulse
    reg pclk_toggle;
    always @(posedge dvp_pclk) begin
        if (pixel_ready) pclk_toggle <= ~pclk_toggle;
    end
    
    reg [2:0] toggle_sync;
    always @(posedge clk) begin
        toggle_sync <= {toggle_sync[1:0], pclk_toggle};
    end
    wire new_pixel = toggle_sync[2] ^ toggle_sync[1];
    
    // Latch stable pixel
    reg [4:0] pixel_sys_latch;
    always @(posedge dvp_pclk) begin
        if (pixel_ready) pixel_sys_latch <= gray_pixel;
    end
    
    //------------------------------------------------------------------------
    // System clock domain outputs and XY counters
    //------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_valid <= 1'b0;
            frame_start <= 1'b0;
            frame_done  <= 1'b0;
            pixel_x <= 10'd0;
            pixel_y <= 9'd0;
            vsync_sys_d1 <= 1'b0;
            pixel_data <= 5'd0;
        end else begin
            vsync_sys_d1 <= vsync_sys;
            pixel_valid  <= 1'b0;
            frame_start  <= 1'b0;
            frame_done   <= 1'b0;
            
            if (vsync_sys_falling) begin
                frame_start <= 1'b1;
                pixel_x <= 10'd0;
                pixel_y <= 9'd0;
            end
            if (vsync_sys_rising) begin
                frame_done <= 1'b1;
            end
            
            if (new_pixel) begin
                pixel_data  <= pixel_sys_latch;
                pixel_valid <= 1'b1;
                // Generate XY natively in SYS domain (Saves ~40 DFFs of CDC)
                if (pixel_x == 10'd319) begin
                    pixel_x <= 10'd0;
                    pixel_y <= pixel_y + 9'd1;
                end else begin
                    pixel_x <= pixel_x + 10'd1;
                end
            end
        end
    end
endmodule
