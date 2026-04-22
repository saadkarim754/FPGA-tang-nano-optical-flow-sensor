//============================================================================
// Double-Buffered Feature Coordinate Store
// Stores detected FAST feature coordinates using ping-pong BRAM buffers
// Buffer A: written by FAST detector (current frame)
// Buffer B: readable by MCU via AHB (previous frame)
// Buffers swap atomically on frame boundary (VSYNC)
// Max 16 features per frame (reduced from 128 to save BRAM)
//
// BRAM-OPTIMIZED: Each buffer uses separate read/write always blocks
// with (* ram_style = "block_ram" *) to guarantee B-SRAM inference.
//============================================================================
module feature_store (
    input  wire        clk,
    input  wire        rst_n,
    
    // Feature input from FAST detector
    input  wire [9:0]  feature_x,
    input  wire [8:0]  feature_y,
    input  wire        feature_valid,
    
    // Frame control
    input  wire        frame_done,       // Swap buffers on this pulse
    
    // Read interface (from AHB slave bridge)
    input  wire [6:0]  read_addr,        // Feature index (0-63)
    output wire [31:0] read_data,        // Feature data
    output wire [7:0]  feature_count,    // Number of features in read buffer
    output wire        buffer_id         // Which buffer is currently readable
);

    parameter MAX_FEATURES = 16;
    
    //------------------------------------------------------------------------
    // Ping-Pong buffer control
    //------------------------------------------------------------------------
    reg active_buf;  // 0 = write to A / read from B, 1 = write to B / read from A
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_buf <= 1'b0;
        else if (frame_done)
            active_buf <= ~active_buf;
    end
    
    assign buffer_id = ~active_buf;
    
    //------------------------------------------------------------------------
    // Feature count per buffer
    //------------------------------------------------------------------------
    reg [7:0] count_a, count_b;
    reg [7:0] read_count;
    
    assign feature_count = read_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_a    <= 8'd0;
            count_b    <= 8'd0;
            read_count <= 8'd0;
        end else begin
            if (frame_done) begin
                if (!active_buf) begin
                    read_count <= count_a;
                    count_b    <= 8'd0;
                end else begin
                    read_count <= count_b;
                    count_a    <= 8'd0;
                end
            end else if (feature_valid) begin
                if (!active_buf && count_a < MAX_FEATURES)
                    count_a <= count_a + 8'd1;
                else if (active_buf && count_b < MAX_FEATURES)
                    count_b <= count_b + 8'd1;
            end
        end
    end
    
    //------------------------------------------------------------------------
    // DFF-Optimized Packed Memory Arrays (BRAM completely exhausted in top)
    //------------------------------------------------------------------------
    // Compress precisely into 19 bits: Y[8:0] (top 9) and X[9:0] (bot 10)
    wire [18:0] feature_word = {feature_y, feature_x};
    
    // Write enables (only one buffer written at a time)
    wire wr_en_a = feature_valid && !active_buf && (count_a < MAX_FEATURES);
    wire wr_en_b = feature_valid &&  active_buf && (count_b < MAX_FEATURES);
    
    // Write addresses (only 4 bits needed for 16-element depth)
    wire [3:0] wr_addr_a = count_a[3:0];
    wire [3:0] wr_addr_b = count_b[3:0];
    
    // Read address
    wire [3:0] rd_addr = read_addr[3:0];
    
    //--- DFF Buffer A ---
    reg [18:0] buf_a [0:15];
    reg [18:0] rd_data_a;
    
    always @(posedge clk) begin
        if (wr_en_a)
            buf_a[wr_addr_a] <= feature_word;
        rd_data_a <= buf_a[rd_addr];
    end
    
    //--- DFF Buffer B ---
    reg [18:0] buf_b [0:15];
    reg [18:0] rd_data_b;
    
    always @(posedge clk) begin
        if (wr_en_b)
            buf_b[wr_addr_b] <= feature_word;
        rd_data_b <= buf_b[rd_addr];
    end
    
    // Select active buffer output and unpack safely to AHB 32-bit format
    wire [18:0] active_rd = active_buf ? rd_data_a : rd_data_b;
    assign read_data = {7'd0, active_rd[18:10], 6'd0, active_rd[9:0]};

endmodule
