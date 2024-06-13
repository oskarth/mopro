#pragma once

#include "curves/bn254.h.metal"
#include "fields/fp_bn254.h.metal"
#include "arithmetics/unsigned_int.h.metal"

namespace {
    typedef UnsignedInteger<8> u256;
    typedef FpBN254 FieldElement;
    typedef ECPoint<FieldElement, 0> Point;
}

constant constexpr uint32_t NUM_LIMBS = 8;  // u256

[[kernel]] void accumulation_in_window_wise(
    constant const uint32_t& _window_size       [[ buffer(0) ]],
    constant const uint32_t& _instances_size    [[ buffer(1) ]],
    constant const uint32_t* _window_starts     [[ buffer(2) ]],
    constant const u256* k_buff                 [[ buffer(3) ]],
    constant const Point* p_buff                [[ buffer(4) ]],
    device Point* buckets_matrix                [[ buffer(5) ]],
    const uint32_t thread_id                    [[ thread_position_in_grid ]],
    const uint32_t thread_count                 [[ threads_per_grid ]]
)
{
    if (thread_id >= total_threads) {
        return;
    }

    uint32_t window_size = _window_size;    // c in arkworks code
    uint32_t instances_size = _instances_size;
    uint32_t buckets_len = (1 << window_size) - 1;
    uint32_t window_idx = _window_starts[thread_id];

    u256 one = u256::from_int((uint32_t)1);
    res[thread_id] = Point::neutral_element();

    // for each points and scalars, calculate the bucket index and accumulate
    for (uint32_t i = 0; i < instances_size; i++) {
        u256 k = k_buff[i];
        Point p = p_buff[i];
        // pass if k is one
        if (k == one) {
            if (window_idx == 0) {
                Point this_res = res[thread_id];
                res[thread_id] = this_res + p_buff[i];
            }
        }
        else {
            // move the b-bit scalar to the correct c-bit scalar fragment
            uint32_t scalar_fragment = (k >> window_idx).m_limbs[NUM_LIMBS - 1];
            // truncate the scalar fragment to the window size
            uint32_t m_ij = scalar_fragment & buckets_len;

        if (m_ij != 0) {
            uint32_t idx = m_ij - 1;
            Point bucket = buckets_matrix[window_idx + idx];
            buckets_matrix[window_idx + idx] = bucket + p;
        }
    }
}

[[kernel]] void initialize_buckets(
    constant const uint32_t& _window_size       [[ buffer(0) ]],
    constant const uint32_t* _window_starts     [[ buffer(1) ]],
    device Point* buckets_matrix                [[ buffer(2) ]],
    const uint32_t thread_id                    [[ thread_position_in_grid ]],
    const uint32_t total_threads                [[ threads_per_grid ]]
)
{
    if (thread_id >= total_threads) {
        return;
    }

    uint32_t window_size = _window_size;    // c in arkworks code
    uint32_t window_idx = _window_starts[thread_id];
    uint32_t buckets_len = (1 << window_size) - 1;

    for (uint32_t i = 0; i < buckets_len; i++) {
        buckets_matrix[window_idx + i] = Point::neutral_element();
    }
}

[[kernel]] void accumulation_and_reduction_phase(
    constant const uint32_t& _window_size       [[ buffer(0) ]],
    constant const uint32_t& _instances_size    [[ buffer(1) ]],
    constant const uint32_t* _window_starts     [[ buffer(2) ]],
    constant const u256* k_buff                 [[ buffer(3) ]],
    constant const Point* p_buff                [[ buffer(4) ]],
    device Point* buckets_matrix                [[ buffer(5) ]],
    device Point* res                           [[ buffer(6) ]],
    const uint32_t thread_id                    [[ thread_position_in_grid ]],
    const uint32_t total_threads           [[ threads_per_grid ]]
)
{
    if (thread_id >= total_threads) {
        return;
    }

    uint32_t window_size = _window_size;    // c in arkworks code
    uint32_t instances_size = _instances_size;
    uint32_t buckets_len = (1 << window_size) - 1;
    uint32_t window_idx = _window_starts[thread_id];

    u256 one = u256::from_int((uint32_t)1);
    res[thread_id] = Point::neutral_element();

    // for each points and scalars, calculate the bucket index and accumulate
    for (uint32_t i = 0; i < instances_size; i++) {
        u256 k = k_buff[i];
        Point p = p_buff[i];
        // pass if k is one
        if (k == one) {
            if (window_idx == 0) {
                Point this_res = res[thread_id];
                res[thread_id] = this_res + p_buff[i];
            }
        }
        else {
            // move the b-bit scalar to the correct c-bit scalar fragment
            uint32_t scalar_fragment = (k >> window_idx).m_limbs[NUM_LIMBS - 1];
            // truncate the scalar fragment to the window size
            uint32_t m_ij = scalar_fragment & buckets_len;

            if (m_ij != 0) {
                uint32_t idx = m_ij - 1;
                Point bucket = buckets_matrix[thread_id * buckets_len + idx];
                buckets_matrix[thread_id * buckets_len + idx] = bucket + p;
            }
        }
    }

    // Perform sum reduction on buckets
    // Get the last bucket of this window
    uint32_t last_bucket_idx = (thread_id + 1) * buckets_len - 1;

    Point running_sum = Point::neutral_element();
    for (uint32_t i = 0; i < buckets_len; i++) {
        running_sum = running_sum + buckets_matrix[last_bucket_idx - i];
        Point this_res = res[thread_id];
        res[thread_id] = this_res + running_sum;
    }
}

// instance-wise parallel
[[kernel]] void prepare_buckets_indices(
    constant const uint32_t& _window_size       [[ buffer(0) ]],
    constant const uint32_t* _window_starts     [[ buffer(1) ]],
    constant const uint32_t& _num_windows       [[ buffer(2) ]],
    constant const u256* k_buff                 [[ buffer(3) ]],
    device uint2* buckets_indices               [[ buffer(4) ]],
    const uint32_t thread_id                    [[ thread_position_in_grid ]],
    const uint32_t total_threads                [[ threads_per_grid ]]
)
{
    if (thread_id >= total_threads) {
        return;
    }

    uint32_t window_size = _window_size;    // c in arkworks code
    uint32_t num_windows = _num_windows;
    uint32_t buckets_len = (1 << window_size) - 1;
    u256 this_scalar = k_buff[thread_id];

    // skip if the scalar is uint scalar
    u256 one = u256::from_int((uint32_t)1);
    if (this_scalar == one) {
        return;
    }

    // for each window, record the corresponding bucket index and point idx
    for (uint32_t i = 0; i < num_windows; i++) {
        uint32_t window_idx = _window_starts[i];

        uint32_t scalar_fragment = (this_scalar >> window_idx).m_limbs[NUM_LIMBS - 1];
        uint32_t m_ij = scalar_fragment & buckets_len;

        // the case (b_idx, p_idx) = (0, 0) is not possible
        // since thread_id == 0 && i == 0 && m_ij == 1 is not possible
        if (m_ij != 0) {
            uint32_t bucket_idx = i * buckets_len + m_ij - 1;
            uint32_t point_idx = thread_id;
            buckets_indices[thread_id * num_windows + i] = uint2(bucket_idx, point_idx);
        }
    }
}

// TODO: sorting buckets_indices with bucket_idx as key

[[kernel]] void bucket_wise_accumulation(
    constant const uint32_t& _instances_size    [[ buffer(0) ]],
    constant const uint32_t& _num_windows       [[ buffer(1) ]],
    constant const Point* p_buff                [[ buffer(2) ]],
    device uint2* buckets_indices               [[ buffer(3) ]],
    device Point* buckets_matrix                [[ buffer(4) ]],
    constant const uint32_t& _max_thread_size   [[ buffer(5) ]],
    uint2 dispatch_threads_per_threadgroup      [[ dispatch_threads_per_threadgroup ]],
    uint2 threadgroup_position_in_grid          [[ threadgroup_position_in_grid ]],
    uint tid                                    [[ thread_index_in_threadgroup ]]
)
{
    uint max_threads_per_threadgroup = dispatch_threads_per_threadgroup.x * dispatch_threads_per_threadgroup.y;
    uint gid = threadgroup_position_in_grid.x;
    uint thread_id = gid * max_threads_per_threadgroup + tid;

    uint32_t max_thread_size = _max_thread_size;
    if (thread_id >= max_thread_size) {
        return;
    }

    uint32_t num_windows = _num_windows;
    uint32_t instances_size = _instances_size;

    uint32_t bucket_start_idx = 0;
    uint32_t max_idx = num_windows * instances_size;

    while (thread_id != buckets_indices[bucket_start_idx].x && bucket_start_idx < max_idx) {
        bucket_start_idx++;
    }
    // return if the bucket needs no accumulation
    if (bucket_start_idx == max_idx) {
        return;
    }

    // perform bucket-wise accumulation
    while (thread_id == buckets_indices[bucket_start_idx].x && bucket_start_idx < max_idx) {
        Point p = buckets_matrix[thread_id];
        buckets_matrix[thread_id] = p + p_buff[buckets_indices[bucket_start_idx].y];
        bucket_start_idx++;
    }
}

// window-wise reduction
[[kernel]] void sum_reduction(
    constant const uint32_t& _window_size       [[ buffer(0) ]],
    constant const u256* k_buff                 [[ buffer(1) ]],
    constant const Point* p_buff                [[ buffer(2) ]],
    device Point* buckets_matrix                [[ buffer(3) ]],
    device Point* res                           [[ buffer(4) ]],
    constant const uint32_t& _max_thread_size   [[ buffer(5) ]],
    const uint32_t thread_id                    [[ thread_index_in_threadgroup ]]
)
{
    uint32_t max_thread_size = _max_thread_size;
    if (thread_id >= max_thread_size) {
        return;
    }

    uint32_t window_size = _window_size;    // c in arkworks code
    uint32_t buckets_len = (1 << window_size) - 1;

    u256 one = u256::from_int((uint32_t)1);
    res[thread_id] = Point::neutral_element();
    
    // get the res for the first window
    if (thread_id == 0) {
        u256 k = k_buff[thread_id];
        if (k == one) {
            Point this_res = res[thread_id];
            res[thread_id] = this_res + p_buff[thread_id];
        }
    }

    // Perform sum reduction on buckets
    // Get the last bucket of this window
    uint32_t last_bucket_idx = (thread_id + 1) * buckets_len - 1;

    Point running_sum = Point::neutral_element();
    for (uint32_t i = 0; i < buckets_len; i++) {
        running_sum = running_sum + buckets_matrix[last_bucket_idx - i];
        Point this_res = res[thread_id];
        res[thread_id] = this_res + running_sum;
    }
}


[[kernel]] void final_accumulation(
    constant const uint32_t& _window_size       [[ buffer(0) ]],
    constant const uint32_t* _window_starts     [[ buffer(1) ]],
    constant const uint32_t& _num_windows       [[ buffer(2) ]],
    device Point* res                           [[ buffer(3) ]],
    device Point& msm_result                    [[ buffer(4) ]]
)
{
    uint32_t window_size = _window_size;    // c in arkworks code
    uint32_t num_windows = _num_windows;
    Point lowest_window_sum = res[0];
    uint32_t last_res_idx = num_windows - 1;

    Point total_sum = Point::neutral_element();
    for (uint32_t i = 1; i < num_windows; i++) {
        Point tmp = total_sum;
        total_sum = tmp + res[last_res_idx - i + 1];

        for (uint32_t j = 0; j < window_size; j++) {
            total_sum = total_sum.double_in_place();
        }
    }
    msm_result = total_sum + lowest_window_sum;
}
