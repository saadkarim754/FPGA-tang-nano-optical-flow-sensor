//============================================================================
// Frame Synchronization & Interrupt Controller
// Manages frame boundaries, double-buffer swaps, and MCU interrupt generation
//============================================================================
module frame_sync (
    input  wire        clk,
    input  wire        rst_n,
    
    // DVP frame signals (from dvp_receiver, already in system clock domain)
    input  wire        frame_start,   // Pulse at start of new frame
    input  wire        frame_done,    // Pulse at end of frame
    
    // Feature store control
    output reg         buf_swap,      // Pulse to swap double buffers
    
    // Status outputs
    output reg         frame_ready,   // New frame features available
    output reg  [15:0] frame_number,  // Rolling frame counter
    
    // LED heartbeat (active low for Tang Nano 4K)
    output wire        led_heartbeat
);

    //------------------------------------------------------------------------
    // Frame counter
    //------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            frame_number <= 16'd0;
        else if (frame_done)
            frame_number <= frame_number + 16'd1;
    end
    
    //------------------------------------------------------------------------
    // Buffer swap and frame ready generation
    //------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buf_swap    <= 1'b0;
            frame_ready <= 1'b0;
        end else begin
            buf_swap    <= 1'b0;
            frame_ready <= 1'b0;
            
            if (frame_done) begin
                buf_swap    <= 1'b1;
                frame_ready <= 1'b1;
            end
        end
    end
    
    //------------------------------------------------------------------------
    // LED heartbeat: blink at ~1Hz using frame counter
    // At 30fps, toggle every 15 frames = ~0.5 second
    //------------------------------------------------------------------------
    reg led_state;
    reg [4:0] blink_cnt;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_state <= 1'b0;
            blink_cnt <= 5'd0;
        end else if (frame_done) begin
            if (blink_cnt == 5'd14) begin
                blink_cnt <= 5'd0;
                led_state <= ~led_state;
            end else begin
                blink_cnt <= blink_cnt + 5'd1;
            end
        end
    end
    
    assign led_heartbeat = ~led_state;  // Active-low LED on Tang Nano 4K

endmodule
