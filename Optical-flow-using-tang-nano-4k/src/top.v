//============================================================================
// Top-Level Module: Optical Flow Co-Processor
// Target: Tang Nano 4K (GW1NSR-LV4CQN48PC6/I5)
// Integrates DVP camera → Grayscale → Line Buffer → FAST Detector →
// Feature Store → AHB Bridge → Cortex-M3 EMPU → UART
//============================================================================
module top (
    // Clock & Reset
    input  wire        clk_27m,      // 27MHz on-board oscillator
    input  wire        btn_reset_n,  // KEY1: active-low reset
    
    // LED
    output wire        led,          // On-board LED (active low)
    
    // DVP Camera Interface  
    input  wire        dvp_pclk,     // Pixel clock from OV2640
    input  wire        dvp_vsync,    // Vertical sync
    input  wire        dvp_href,     // Horizontal reference
    input  wire [7:0]  dvp_d,        // 8-bit pixel data bus
    inout  wire        dvp_sda,      // SCCB data (directly to camera)
    inout  wire        dvp_scl,      // SCCB clock (directly to camera)
    output wire        dvp_xclk,     // Camera master clock output
    
    // UART (to flight controller)
    output wire        uart_tx,      // UART0 TX
    input  wire        uart_rx       // UART0 RX
);

    //========================================================================
    // Clock & Reset
    //========================================================================
    // Use 27MHz directly as system clock (no PLL needed initially)
    // Can add PLL to go to 54MHz later if timing closure requires it
    wire sys_clk = clk_27m;
    wire sys_rst_n = btn_reset_n;

    // Generate camera XCLK = sys_clk/2 (~13.5MHz from 27MHz source)
    reg xclk_div2;
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            xclk_div2 <= 1'b0;
        else
            xclk_div2 <= ~xclk_div2;
    end
    assign dvp_xclk = xclk_div2;
    
    //========================================================================
    // Camera SCCB lines - Hardware Initializer (Bypasses MCU)
    //========================================================================
    wire cam_init_done;
    
    camera_init u_camera_init (
        .clk       (sys_clk),
        .rst_n     (sys_rst_n),
        .sda       (dvp_sda),
        .scl       (dvp_scl),
        .init_done (cam_init_done)
    );
    // DVP Receiver
    //========================================================================
    wire [4:0]  pixel_5bit;
    wire        dvp_pixel_valid;
    wire [9:0]  dvp_pixel_x;
    wire [8:0]  dvp_pixel_y;
    wire        dvp_frame_start;
    wire        dvp_frame_done;
    
    dvp_receiver u_dvp_receiver (
        .clk          (sys_clk),
        .rst_n        (sys_rst_n),
        .dvp_pclk     (dvp_pclk),
        .dvp_vsync    (dvp_vsync),
        .dvp_href     (dvp_href),
        .dvp_data     (dvp_d),
        .pixel_data   (pixel_5bit),
        .pixel_valid  (dvp_pixel_valid),
        .pixel_x      (dvp_pixel_x),
        .pixel_y      (dvp_pixel_y),
        .frame_start  (dvp_frame_start),
        .frame_done   (dvp_frame_done)
    );
    
    //========================================================================
    // Line Buffer (7x7 Window Extraction)
    //========================================================================
    wire [244:0] win_flat;
    wire         win_valid;
    wire [9:0]   win_x;
    wire [8:0]   win_y;
    
    line_buffer u_line_buffer (
        .clk          (sys_clk),
        .rst_n        (sys_rst_n),
        .pixel_in     (pixel_5bit),
        .pixel_valid  (dvp_pixel_valid),
        .pixel_x      (dvp_pixel_x),
        .pixel_y      (dvp_pixel_y),
        .window_flat  (win_flat),
        .window_valid (win_valid),
        .center_x     (win_x),
        .center_y     (win_y)
    );
    
    //========================================================================
    // FAST-9 Corner Detector
    //========================================================================
    wire [9:0]  feat_x;
    wire [8:0]  feat_y;
    wire        feat_valid;
    wire [7:0]  fast_threshold;
    wire        detect_enable;
    
    fast_detector u_fast_detector (
        .clk          (sys_clk),
        .rst_n        (sys_rst_n),
        .threshold    (fast_threshold[4:0]),
        .enable       (detect_enable),
        .window_flat  (win_flat),
        .window_valid (win_valid),
        .center_x     (win_x),
        .center_y     (win_y),
        .feature_x    (feat_x),
        .feature_y    (feat_y),
        .feature_valid(feat_valid)
    );
    
    //========================================================================
    // Frame Synchronization
    //========================================================================
    wire        buf_swap;
    wire        frame_ready;
    wire [15:0] frame_number;
    
    frame_sync u_frame_sync (
        .clk           (sys_clk),
        .rst_n         (sys_rst_n),
        .frame_start   (dvp_frame_start),
        .frame_done    (dvp_frame_done),
        .buf_swap      (buf_swap),
        .frame_ready   (frame_ready),
        .frame_number  (frame_number),
        .led_heartbeat (led)
    );
    
    //========================================================================
    // Feature Store (Double-Buffered)
    //========================================================================
    wire [6:0]  feat_read_addr;
    wire [31:0] feat_read_data;
    wire [7:0]  feat_count;
    wire        feat_buffer_id;
    
    feature_store u_feature_store (
        .clk           (sys_clk),
        .rst_n         (sys_rst_n),
        .feature_x     (feat_x),
        .feature_y     (feat_y),
        .feature_valid (feat_valid),
        .frame_done    (buf_swap),
        .read_addr     (feat_read_addr),
        .read_data     (feat_read_data),
        .feature_count (feat_count),
        .buffer_id     (feat_buffer_id)
    );
    
    //========================================================================
    // AHB Feature Slave (connected to EMPU Master Extension)
    //========================================================================
    // AHB master extension signals (OUTPUTS from EMPU = MCU drives these)
    wire        master_hclk;          // AHB clock from EMPU
    wire        master_hrst;          // AHB reset from EMPU
    wire        master_hsel;          // Slave select
    wire [31:0] master_haddr;         // Address bus
    wire [1:0]  master_htrans;        // Transfer type
    wire        master_hwrite;        // Write enable
    wire [2:0]  master_hsize;         // Transfer size
    wire [2:0]  master_hburst;        // Burst type
    wire [3:0]  master_hprot;         // Protection control
    wire [1:0]  master_hmemattr;      // Memory attributes
    wire        master_hexreq;        // Exclusive request
    wire [3:0]  master_hmaster;       // Master ID
    wire [31:0] master_hwdata;        // Write data
    wire        master_hmastlock;     // Master lock
    wire        master_hreadymux;     // Ready mux output
    wire        master_hauser;        // Address user signal
    wire [3:0]  master_hwuser;        // Write user signal
    
    // AHB master extension signals (INPUTS to EMPU = our slave responds)
    wire [31:0] master_hrdata;        // Read data from slave
    wire        master_hreadyout;     // Slave ready signal
    wire        master_hresp;         // Slave response
    
    wire        frame_irq;
    wire [3:0]  dbg_state;
    wire        dbg_pclk_seen;
    wire        dbg_vsync_seen;
    wire        dbg_timeout_hit;
    wire [15:0] dbg_pclk_edges;
    wire [15:0] dbg_vsync_edges;
    wire [31:0] dbg_frame_timeout;

    wire        hw_handover;
    reg  [1:0]  hw_handover_sync_ff;
    wire        hw_handover_sync = hw_handover_sync_ff[1];
    
    ahb_feature_slave u_ahb_slave (
        .hclk           (master_hclk),
        .hresetn        (~master_hrst),    // EMPU hrst is active-high, slave expects active-low
        .hsel           (master_hsel),
        .haddr          (master_haddr),
        .htrans         (master_htrans),
        .hwrite         (master_hwrite),
        .hsize          (master_hsize),
        .hwdata         (master_hwdata),
        .hrdata         (master_hrdata),
        .hready         (master_hreadyout),
        .hresp          (master_hresp),
        .feat_read_addr (feat_read_addr),
        .feat_read_data (feat_read_data),
        .feat_count     (feat_count),
        .feat_buffer_id (feat_buffer_id),
        .fast_threshold (fast_threshold),
        .detect_enable  (detect_enable),
        .frame_ready    (frame_ready),
        .frame_irq      (frame_irq),
        .frame_number   (frame_number),
        .dbg_state      (dbg_state),
        .dbg_handover   (hw_handover_sync),
        .dbg_pclk_seen  (dbg_pclk_seen),
        .dbg_vsync_seen (dbg_vsync_seen),
        .dbg_timeout_hit(dbg_timeout_hit),
        .dbg_pclk_edges (dbg_pclk_edges),
        .dbg_vsync_edges(dbg_vsync_edges),
        .dbg_frame_timeout(dbg_frame_timeout),
        .dbg_master_hrst(master_hrst)
    );
    
    //========================================================================
    // Hardware Debugger & UART TX Multiplexer
    //========================================================================
    wire       hw_uart_tx;
    wire [7:0] hw_tx_data;
    wire       hw_tx_start;
    wire       hw_tx_busy;
    wire       hw_tx_done;
    
    uart_tx u_hw_uart (
        .clk      (sys_clk),
        .rst_n    (sys_rst_n),
        .tx_data  (hw_tx_data),
        .tx_start (hw_tx_start),
        .tx_busy  (hw_tx_busy),
        .tx_done  (hw_tx_done),
        .tx_pin   (hw_uart_tx)
    );
    
    fpga_debugger u_debugger (
        .clk              (sys_clk),
        .rst_n            (sys_rst_n),
        .cam_init_done    (cam_init_done),
        .first_frame_seen (dvp_frame_done),
        .uart_tx_data     (hw_tx_data),
        .uart_tx_start    (hw_tx_start),
        .uart_tx_busy     (hw_tx_busy),
        .uart_tx_done     (hw_tx_done),
        .dvp_pclk         (dvp_pclk),
        .dvp_vsync        (dvp_vsync),
        .handover_to_mcu  (hw_handover),
        .dbg_state        (dbg_state),
        .dbg_pclk_seen    (dbg_pclk_seen),
        .dbg_vsync_seen   (dbg_vsync_seen),
        .dbg_timeout_hit  (dbg_timeout_hit),
        .dbg_pclk_edges   (dbg_pclk_edges),
        .dbg_vsync_edges  (dbg_vsync_edges),
        .dbg_frame_timeout(dbg_frame_timeout)
    );

    // Temporary first-pass debug mode:
    // keep FPGA UART ownership to avoid mixed characters during handover.
    localparam DEBUG_FORCE_FPGA_UART = 1'b1;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            hw_handover_sync_ff <= 2'b00;
        else
            hw_handover_sync_ff <= {hw_handover_sync_ff[0], hw_handover};
    end

    wire mcu_uart_tx;
    assign uart_tx = DEBUG_FORCE_FPGA_UART ? hw_uart_tx
                                           : (hw_handover_sync ? mcu_uart_tx : hw_uart_tx);
    
    //========================================================================
    // Cortex-M3 EMPU Instantiation
    // Port names match gowin_empu_tmp.v generated 2026-04-12
    //========================================================================
    // Note: GPIO intentionally left unconnected to save I/O pins
    // (Tang Nano 4K only has 30 regular I/Os)
    
    Gowin_EMPU_Top u_empu (
        .sys_clk    (sys_clk),
        .reset_n    (sys_rst_n),
        
        // GPIO: left unconnected — not used, saves 16 I/O pins
        //.gpio       (gpio),
        
        // UART0: main telemetry output
        .uart0_rxd  (uart_rx),
        .uart0_txd  (mcu_uart_tx),
        
        // UART1: not routed to pins (saves I/O — Tang Nano 4K has only 30)
        .uart1_rxd  (1'b1),
        //.uart1_txd  (),  // left unconnected
        
        // I2C: Disconnected from MCU! Hardware handles it now.
        //.scl        (dvp_scl),
        //.sda        (dvp_sda),
        
        // AHB2 Master Extension: MCU accesses our feature BRAM
        .master_hclk       (master_hclk),
        .master_hrst       (master_hrst),
        .master_hsel       (master_hsel),
        .master_haddr      (master_haddr),
        .master_htrans     (master_htrans),
        .master_hwrite     (master_hwrite),
        .master_hsize      (master_hsize),
        .master_hburst     (master_hburst),
        .master_hprot      (master_hprot),
        .master_hmemattr   (master_hmemattr),
        .master_hexreq     (master_hexreq),
        .master_hmaster    (master_hmaster),
        .master_hwdata     (master_hwdata),
        .master_hmastlock  (master_hmastlock),
        .master_hreadymux  (master_hreadymux),
        .master_hauser     (master_hauser),
        .master_hwuser     (master_hwuser),
        .master_hrdata     (master_hrdata),       // ← from our slave
        .master_hreadyout  (master_hreadyout),    // ← from our slave
        .master_hresp      (master_hresp),        // ← from our slave
        .master_hexresp    (1'b0),                // No exclusive response
        .master_hruser     (3'b000),              // No user response
        
        // AHB2 Slave Extension: tie off (not used in current design)
        .slave_hsel        (1'b0),
        .slave_haddr       (32'd0),
        .slave_htrans      (2'b00),
        .slave_hwrite      (1'b0),
        .slave_hsize       (3'b000),
        .slave_hburst      (3'b000),
        .slave_hprot       (4'b0000),
        .slave_hmemattr    (2'b00),
        .slave_hexreq      (1'b0),
        .slave_hmaster     (4'b0000),
        .slave_hwdata      (32'd0),
        .slave_hmastlock   (1'b0),
        .slave_hauser      (1'b0),
        .slave_hwuser      (4'b0000),
        // slave outputs left unconnected (unused):
        // .slave_hrdata, .slave_hready, .slave_hresp, .slave_hexresp, .slave_hruser
        
        // User interrupts
        .user_int_0 (frame_irq),     // Frame-ready interrupt
        .user_int_1 (1'b0)           // Reserved
    );

endmodule
