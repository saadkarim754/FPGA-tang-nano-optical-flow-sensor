//============================================================================
// Cortex-M3 Main Firmware — Optical Flow Co-Processor
// Reads FAST features from FPGA via AHB, computes flow, outputs via UART
//============================================================================
#include <stdint.h>
#include "flow_calc.h"
#include "ov2640_regs.h"

//============================================================================
// Memory-Mapped Peripheral Base Addresses (Gowin EMPU)
//============================================================================
#define UART0_BASE          0x40004000
#define UART0_DATA          (*(volatile uint32_t *)(UART0_BASE + 0x000))
#define UART0_STATE         (*(volatile uint32_t *)(UART0_BASE + 0x004))
#define UART0_CTRL          (*(volatile uint32_t *)(UART0_BASE + 0x008))
#define UART0_BAUDDIV       (*(volatile uint32_t *)(UART0_BASE + 0x010))

#define GPIO_BASE           0x40010000
#define GPIO_DATA           (*(volatile uint32_t *)(GPIO_BASE + 0x000))
#define GPIO_DIR            (*(volatile uint32_t *)(GPIO_BASE + 0x004))

// AHB2 Master Extension address: feature registers in FPGA fabric
#define FEAT_BASE           0xA0000000
#define FEAT_COUNT_REG      (*(volatile uint32_t *)(FEAT_BASE + 0x000))
#define FEAT_STATUS_REG     (*(volatile uint32_t *)(FEAT_BASE + 0x004))
#define FEAT_THRESHOLD_REG  (*(volatile uint32_t *)(FEAT_BASE + 0x008))
#define FEAT_CONTROL_REG    (*(volatile uint32_t *)(FEAT_BASE + 0x00C))
#define FEAT_FRAMENUM_REG   (*(volatile uint32_t *)(FEAT_BASE + 0x010))
#define FEAT_DATA_BASE      (FEAT_BASE + 0x100)
#define FEAT_DATA(i)        (*(volatile uint32_t *)(FEAT_DATA_BASE + ((i) << 2)))

// NVIC for interrupt configuration
#define NVIC_ISER           (*(volatile uint32_t *)0xE000E100)

//============================================================================
// UART Helper Functions
//============================================================================
static void uart_init(uint32_t baud_div) {
    UART0_BAUDDIV = baud_div;
    UART0_CTRL = 0x03;  // TX enable, RX enable
}

static void uart_putchar(char c) {
    while (UART0_STATE & 0x01);  // Wait for TX not full
    UART0_DATA = (uint32_t)c;
}

static void uart_puts(const char *s) {
    while (*s) {
        uart_putchar(*s++);
    }
}

static void uart_put_int(int32_t val) {
    char buf[12];
    int i = 0;
    int neg = 0;
    
    if (val < 0) {
        neg = 1;
        val = -val;
    }
    
    if (val == 0) {
        buf[i++] = '0';
    } else {
        while (val > 0) {
            buf[i++] = '0' + (val % 10);
            val /= 10;
        }
    }
    
    if (neg) uart_putchar('-');
    
    // Reverse and print
    for (int j = i - 1; j >= 0; j--) {
        uart_putchar(buf[j]);
    }
}

//============================================================================
// Delay function (rough, based on loop iterations)
//============================================================================
static void delay_ms(uint32_t ms) {
    // At ~27MHz, roughly 6750 iterations per ms
    volatile uint32_t count = ms * 6750;
    while (count--);
}

//============================================================================
// Main Function
//============================================================================
// Feature buffers for two consecutive frames
static feature_t prev_features[MAX_FEATURES];
static feature_t curr_features[MAX_FEATURES];
static uint8_t   prev_count = 0;

int main(void) {
    //--------------------------------------------------------------------
    // System Initialization
    //--------------------------------------------------------------------
    // Initialize UART0 at 115200 baud
    // Baud divisor = sys_clk / baud = 27000000 / 115200 ≈ 234
    uart_init(234);
    
    // Set FAST threshold
    FEAT_THRESHOLD_REG = 30;
    
    // Enable detection
    FEAT_CONTROL_REG = 0x01;
    
    // Startup message
    uart_puts("OPTFLOW: Optical Flow Co-Processor v1.0\r\n");
    uart_puts("OPTFLOW: FAST threshold=30, QVGA 320x240\r\n");
    
    //--------------------------------------------------------------------
    // Main Loop: Poll for new frames, compute flow, send telemetry
    //--------------------------------------------------------------------
    flow_result_t flow;
    uint16_t last_frame = 0;
    
    while (1) {
        // Check frame status register
        uint32_t status = FEAT_STATUS_REG;
        
        if (status & 0x01) {  // New frame ready
            // Read feature count
            uint8_t count = (uint8_t)(FEAT_COUNT_REG & 0xFF);
            if (count > MAX_FEATURES) count = MAX_FEATURES;
            
            // Read all feature coordinates from FPGA BRAM
            for (uint8_t i = 0; i < count; i++) {
                uint32_t word = FEAT_DATA(i);
                curr_features[i].x = (uint16_t)(word & 0x03FF);        // Bits [9:0]
                curr_features[i].y = (uint16_t)((word >> 16) & 0x01FF); // Bits [24:16]
            }
            
            // Clear IRQ flag
            FEAT_CONTROL_REG = 0x03;  // Enable + clear IRQ
            FEAT_CONTROL_REG = 0x01;  // Enable only
            
            // Compute optical flow (skip first frame — need 2 frames)
            if (prev_count > 0) {
                compute_optical_flow(prev_features, prev_count,
                                     curr_features, count, &flow);
                
                // Send flow telemetry: FLOW,vx,vy,quality,matches,features
                uart_puts("FLOW,");
                uart_put_int(flow.vx);
                uart_putchar(',');
                uart_put_int(flow.vy);
                uart_putchar(',');
                uart_put_int(flow.quality);
                uart_putchar(',');
                uart_put_int(flow.match_count);
                uart_putchar(',');
                uart_put_int(count);
                uart_puts("\r\n");
            } else {
                uart_puts("OPTFLOW: First frame captured, ");
                uart_put_int(count);
                uart_puts(" features\r\n");
            }
            
            // Swap buffers: current becomes previous
            for (uint8_t i = 0; i < count; i++) {
                prev_features[i] = curr_features[i];
            }
            prev_count = count;
        } else {
            // Heartbeat print for debugging UART
            static uint16_t wait_ticks = 0;
            if (++wait_ticks >= 1000) {
                uart_puts("OPTFLOW: Waiting for camera frames...\r\n");
                wait_ticks = 0;
            }
        }
        
        // Small delay to avoid bus congestion
        delay_ms(1);
    }
    
    return 0;
}
