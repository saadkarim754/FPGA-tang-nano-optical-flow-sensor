//============================================================================
// OV2640 Camera Register Definitions & Initialization Arrays
// Derived from ESP32-camera reference implementation
// Configures: QVGA (320x240), RGB565 output, ~12MHz PCLK
//============================================================================
#ifndef OV2640_REGS_H
#define OV2640_REGS_H

#include <stdint.h>

// OV2640 SCCB address
#define OV2640_ADDR_WRITE   0x60
#define OV2640_ADDR_READ    0x61

// Bank select register
#define REG_BANK_SEL        0xFF
#define BANK_DSP            0x00
#define BANK_SENSOR         0x01

// Sensor bank registers
#define REG_COM7            0x12
#define REG_COM10           0x15
#define REG_HSTART          0x17
#define REG_HSTOP           0x18
#define REG_VSTART          0x19
#define REG_VSTOP           0x1A
#define REG_CLKRC           0x11
#define REG_AEC             0x10
#define REG_COM1            0x03

// DSP bank registers  
#define REG_RESET           0xE0
#define REG_ZMOW            0x5A
#define REG_ZMOH            0x5B
#define REG_ZMHH            0x5C
#define REG_IMAGE_MODE      0xDA
#define REG_CTRL0           0xC2
#define REG_CTRL2           0x86
#define REG_CTRL3           0x87

// Register value pair structure
typedef struct {
    uint8_t reg;
    uint8_t val;
} ov2640_reg_t;

// End-of-array marker
#define OV2640_REG_END  0xFF, 0xFF

//----------------------------------------------------------------------------
// Init sequence: Reset + basic sensor configuration
//----------------------------------------------------------------------------
static const ov2640_reg_t ov2640_init_regs[] = {
    // Software reset
    {REG_BANK_SEL, BANK_SENSOR},
    {REG_COM7,     0x80},       // Reset all registers
    
    // Wait at least 5ms after reset (handled in firmware)
    
    // Sensor bank configuration
    {REG_BANK_SEL, BANK_SENSOR},
    {REG_CLKRC,    0x01},       // Clock divider: PCLK = XCLK / 2
    {REG_COM7,     0x00},       // SVGA mode, YUV
    {REG_COM1,     0x0A},       
    {REG_HSTART,   0x11},       // Horizontal start
    {REG_HSTOP,    0x43},       // Horizontal stop
    {REG_VSTART,   0x00},       // Vertical start
    {REG_VSTOP,    0x25},       // Vertical stop
    {0x32,         0x09},       // HREF control
    {0x37,         0xC0},       
    {0x29,         0xA0},       
    {0x33,         0x0B},       
    {0x20,         0x00},       
    {0x22,         0x7F},       
    {0x36,         0x2C},       
    {0x37,         0xC0},       
    {0x2C,         0xFF},       
    {REG_COM10,    0x00},       // VSYNC polarity
    
    {OV2640_REG_END},
};

//----------------------------------------------------------------------------
// QVGA (320x240) RGB565 configuration
//----------------------------------------------------------------------------
static const ov2640_reg_t ov2640_qvga_rgb565[] = {
    // DSP bank: configure output format and scaling
    {REG_BANK_SEL,  BANK_DSP},
    {REG_RESET,     0x04},      // Reset DVP
    {REG_IMAGE_MODE, 0x09},     // RGB565 output, byte swap
    {0xD7,          0x03},      // Zoom speed
    {0xE1,          0x77},      
    {0xE5,          0x1F},      
    {0xDD,          0x7F},      
    
    // Output size: 320x240
    {0xC0,          0xC8},      // HSIZE8[7:0] = 320/8 = 40 = 0x28, but register format differs
    {0xC1,          0x96},      // VSIZE8[7:0] = 240/8 = 30 = 0x1E
    {0x8C,          0x00},      
    {REG_CTRL2,     0x3D},      // DCW enable, SDE enable
    {REG_CTRL3,     0x00},      
    
    // ZMOW/ZMOH for output window
    {REG_ZMOW,      0x28},     // 320/8 = 40 = 0x28
    {REG_ZMOH,      0x1E},     // 240/8 = 30 = 0x1E
    {REG_ZMHH,      0x00},     
    
    {REG_CTRL0,     0x00},      
    {REG_RESET,     0x00},      // Release DVP reset
    
    {OV2640_REG_END},
};

#endif // OV2640_REGS_H
