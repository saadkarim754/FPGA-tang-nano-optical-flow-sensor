//============================================================================
// AHB-Lite Slave Interface for Feature Store
// Provides memory-mapped access for the Cortex-M3 to read feature data
// Connected to EMPU's AHB2 Master Extension (base address 0xA0000000)
//
// Memory Map (offsets from base):
//   0x000: FEAT_COUNT   (R)   - Number of features in current read buffer
//   0x004: FRAME_STATUS (R)   - Bit 0: new frame ready, Bit 1: buffer ID
//   0x008: THRESHOLD    (R/W) - FAST detection threshold (8-bit)
//   0x00C: CONTROL      (R/W) - Bit 0: enable detection, Bit 1: clear IRQ
//   0x010: FRAME_NUM    (R)   - Frame counter
//   0x100-0x2FF: FEAT_DATA[0:127] (R) - Feature coordinates
//============================================================================
module ahb_feature_slave (
    input  wire        hclk,
    input  wire        hresetn,
    
    // AHB-Lite slave interface (directly connected to EMPU master extension)
    input  wire        hsel,
    input  wire [31:0] haddr,
    input  wire [1:0]  htrans,
    input  wire        hwrite,
    input  wire [2:0]  hsize,
    input  wire [31:0] hwdata,
    output reg  [31:0] hrdata,
    output wire        hready,
    output wire        hresp,
    
    // Feature store interface
    output reg  [6:0]  feat_read_addr,
    input  wire [31:0] feat_read_data,
    input  wire [7:0]  feat_count,
    input  wire        feat_buffer_id,
    
    // Control outputs
    output reg  [7:0]  fast_threshold,
    output reg         detect_enable,
    
    // Frame status
    input  wire        frame_ready,      // Pulse when new frame features ready
    output reg         frame_irq,        // Interrupt to MCU
    input  wire [15:0] frame_number
);

    // AHB response: always OK, always ready (single-cycle access)
    assign hready = 1'b1;
    assign hresp  = 1'b0;  // OKAY
    
    // Address phase latching (AHB pipelining: address in phase 1, data in phase 2)
    reg [31:0] addr_phase;
    reg        write_phase;
    reg        valid_phase;
    
    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            addr_phase  <= 32'd0;
            write_phase <= 1'b0;
            valid_phase <= 1'b0;
        end else begin
            addr_phase  <= haddr;
            write_phase <= hwrite;
            valid_phase <= hsel && (htrans[1] == 1'b1);  // Non-idle transfer
        end
    end
    
    // Register access
    wire [11:0] reg_offset = addr_phase[11:0];
    
    // IRQ management
    reg frame_ready_d1;
    wire frame_ready_pulse = frame_ready & ~frame_ready_d1;
    reg new_frame_flag;
    
    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            frame_ready_d1  <= 1'b0;
            new_frame_flag  <= 1'b0;
            frame_irq       <= 1'b0;
            fast_threshold  <= 8'd30;    // Default threshold
            detect_enable   <= 1'b1;     // Enabled by default
        end else begin
            frame_ready_d1 <= frame_ready;
            
            // Set flag on new frame
            if (frame_ready_pulse) begin
                new_frame_flag <= 1'b1;
                frame_irq      <= 1'b1;
            end
            
            // Write handling (data phase)
            if (valid_phase && write_phase) begin
                case (reg_offset)
                    12'h008: fast_threshold <= hwdata[7:0];
                    12'h00C: begin
                        detect_enable <= hwdata[0];
                        if (hwdata[1]) begin  // Clear IRQ bit
                            frame_irq      <= 1'b0;
                            new_frame_flag <= 1'b0;
                        end
                    end
                    default: ; // Ignore writes to other addresses
                endcase
            end
        end
    end
    
    // Read handling
    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            hrdata         <= 32'd0;
            feat_read_addr <= 7'd0;
        end else begin
            // Default
            hrdata <= 32'd0;
            
            if (hsel && !hwrite && htrans[1]) begin
                // Address phase: set up read
                case (haddr[11:0])
                    12'h000: hrdata <= {24'd0, feat_count};
                    12'h004: hrdata <= {30'd0, feat_buffer_id, new_frame_flag};
                    12'h008: hrdata <= {24'd0, fast_threshold};
                    12'h00C: hrdata <= {31'd0, detect_enable};
                    12'h010: hrdata <= {16'd0, frame_number};
                    default: begin
                        // Feature data region: 0x100-0x2FF
                        if (haddr[11:8] >= 4'h1 && haddr[11:8] <= 4'h2) begin
                            feat_read_addr <= haddr[8:2];  // Word-aligned index
                            hrdata         <= feat_read_data;
                        end
                    end
                endcase
            end
        end
    end

endmodule
