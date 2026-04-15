//============================================================================
// Sparse Optical Flow Calculation — Implementation
// Nearest-neighbor matching with median-filtered outlier rejection
//============================================================================
#include "flow_calc.h"

//----------------------------------------------------------------------------
// Internal: Simple insertion sort for median filter (small arrays)
//----------------------------------------------------------------------------
static void sort_int16(int16_t *arr, uint8_t n) {
    for (uint8_t i = 1; i < n; i++) {
        int16_t key = arr[i];
        int8_t j = i - 1;
        while (j >= 0 && arr[j] > key) {
            arr[j + 1] = arr[j];
            j--;
        }
        arr[j + 1] = key;
    }
}

//----------------------------------------------------------------------------
// Compute optical flow
//----------------------------------------------------------------------------
void compute_optical_flow(
    const feature_t *prev_features, uint8_t prev_count,
    const feature_t *curr_features, uint8_t curr_count,
    flow_result_t *result
) {
    flow_vector_t matches[MAX_FEATURES];
    uint8_t match_count = 0;
    
    // Initialize result
    result->vx = 0;
    result->vy = 0;
    result->quality = 0;
    result->match_count = 0;
    
    // Edge case: not enough features
    if (prev_count < 3 || curr_count < 3) {
        return;
    }
    
    //--------------------------------------------------------------------
    // Phase 1: Nearest-neighbor matching
    // For each feature in current frame, find closest in previous frame
    //--------------------------------------------------------------------
    for (uint8_t i = 0; i < curr_count && i < MAX_FEATURES; i++) {
        uint32_t min_dist2 = MAX_MATCH_DIST2;
        int8_t best_match = -1;
        
        int16_t cx = (int16_t)curr_features[i].x;
        int16_t cy = (int16_t)curr_features[i].y;
        
        for (uint8_t j = 0; j < prev_count && j < MAX_FEATURES; j++) {
            int16_t dx = cx - (int16_t)prev_features[j].x;
            int16_t dy = cy - (int16_t)prev_features[j].y;
            uint32_t dist2 = (uint32_t)(dx * dx + dy * dy);
            
            if (dist2 < min_dist2) {
                min_dist2 = dist2;
                best_match = j;
            }
        }
        
        if (best_match >= 0) {
            matches[match_count].dx = cx - (int16_t)prev_features[best_match].x;
            matches[match_count].dy = cy - (int16_t)prev_features[best_match].y;
            match_count++;
        }
    }
    
    if (match_count < 3) {
        result->match_count = match_count;
        return;
    }
    
    //--------------------------------------------------------------------
    // Phase 2: Median filter for outlier rejection
    //--------------------------------------------------------------------
    int16_t dx_arr[MAX_FEATURES];
    int16_t dy_arr[MAX_FEATURES];
    
    for (uint8_t i = 0; i < match_count; i++) {
        dx_arr[i] = matches[i].dx;
        dy_arr[i] = matches[i].dy;
    }
    
    sort_int16(dx_arr, match_count);
    sort_int16(dy_arr, match_count);
    
    int16_t median_dx = dx_arr[match_count / 2];
    int16_t median_dy = dy_arr[match_count / 2];
    
    //--------------------------------------------------------------------
    // Phase 3: Average vectors within 2x median deviation
    //--------------------------------------------------------------------
    int32_t sum_dx = 0, sum_dy = 0;
    uint8_t inlier_count = 0;
    
    // Compute median absolute deviation
    int16_t mad_threshold = 5;  // Minimum 5 pixels deviation tolerance
    for (uint8_t i = 0; i < match_count; i++) {
        int16_t dev_x = matches[i].dx - median_dx;
        int16_t dev_y = matches[i].dy - median_dy;
        if (dev_x < 0) dev_x = -dev_x;
        if (dev_y < 0) dev_y = -dev_y;
        
        if (dev_x <= mad_threshold && dev_y <= mad_threshold) {
            sum_dx += matches[i].dx;
            sum_dy += matches[i].dy;
            inlier_count++;
        }
    }
    
    //--------------------------------------------------------------------
    // Phase 4: Compute final result
    //--------------------------------------------------------------------
    if (inlier_count > 0) {
        // Scale by 100 for fixed-point precision
        result->vx = (int16_t)((sum_dx * 100) / inlier_count);
        result->vy = (int16_t)((sum_dy * 100) / inlier_count);
        result->match_count = inlier_count;
        
        // Quality: ratio of inliers to total matches (0-255)
        result->quality = (uint8_t)((uint16_t)inlier_count * 255 / match_count);
    }
}
