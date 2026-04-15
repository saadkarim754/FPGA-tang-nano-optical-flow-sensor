//============================================================================
// Sparse Optical Flow Calculation
// Uses nearest-neighbor feature matching between consecutive frames
// Fixed-point arithmetic (no floating point) for Cortex-M3 efficiency
//============================================================================
#ifndef FLOW_CALC_H
#define FLOW_CALC_H

#include <stdint.h>

// Maximum features to process per frame
#define MAX_FEATURES     128

// Maximum matching distance (squared, in pixels)
#define MAX_MATCH_DIST2  400   // 20 pixels radius

// Feature point structure
typedef struct {
    uint16_t x;
    uint16_t y;
} feature_t;

// Flow vector structure  
typedef struct {
    int16_t dx;     // Displacement X (pixels, signed)
    int16_t dy;     // Displacement Y (pixels, signed)
} flow_vector_t;

// Overall flow result
typedef struct {
    int16_t  vx;           // Average flow X (scaled by 100)
    int16_t  vy;           // Average flow Y (scaled by 100)
    uint8_t  quality;      // Match quality (0-255)
    uint8_t  match_count;  // Number of matched features
} flow_result_t;

//----------------------------------------------------------------------------
// Compute optical flow between two frames of features
// prev_features: features from previous frame
// prev_count:    number of previous features
// curr_features: features from current frame  
// curr_count:    number of current features
// result:        output flow result
//----------------------------------------------------------------------------
void compute_optical_flow(
    const feature_t *prev_features, uint8_t prev_count,
    const feature_t *curr_features, uint8_t curr_count,
    flow_result_t *result
);

#endif // FLOW_CALC_H
