#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

extern "C" {
#include "hd_encoder.h"
}

// number of threads per block in the grid
#ifndef NUM_THREADS_IN_BLOCK
#define NUM_THREADS_IN_BLOCK 128
#endif

#ifndef MAX_NUM_INPUT_CHUNKS
#define MAX_NUM_INPUT_CHUNKS 4
#endif

#define NUM_HD_BLOCKS_IN_BLOCK (NUM_THREADS_IN_BLOCK / MAX_NUM_INPUT_CHUNKS)

#define MAX_NUM_ITEMS 32

// TODO: Stuff to optimize
// * Copy one part of x to device, then compute it and copy the next part at the same time.
//   Use different streams for each part of the input, and use cudaMemcopyAsync.
// * make clip also on the gpu, using the data from before, and don't copy the ngramm_sum_buffer over.

// encode the whole input with a chunk of the HD vector (a single)
template<int NGRAMM, int NUM_INPUT_CHUNKS>
__global__ void hd_encoder_kernel(
    const int n_blk,
    uint32_t * __restrict__ ngramm_sum_buffer,
    const block_t * __restrict__ item_lookup,
    const int n_items,
    const feature_t * __restrict__ x,
    const int n_x
)
{
    // setup shared memory
    extern __shared__ uint32_t s[];

    // compute the index of the block on which we must work
    int blk_idx = blockIdx.x * blockDim.x + threadIdx.x;
    int x_chunk_idx = blockIdx.y * blockDim.y + threadIdx.y;

    // exit if blk_idx is outside of the range
    if (blk_idx >= n_blk || x_chunk_idx >= NUM_INPUT_CHUNKS) {
        return;
    }

    // there are (NUM_INPUT_CHUNKS - 1) overlaps of (NGRAMM - 1),
    // but the number of XOR calculations only depends on
    // the number of outputs to the accummulation buffer

    // example: n_x = 9, ngramm = 3, NUM_INPUT_CHUNKS = 2
    //          xored_n_x := 7, x_chunk_len = 4 (3 for last chunk)
    //
    // o - load only, x - load and xor
    // chunk 0: ooxxxx---
    // chunk 1: ----ooxxx
    //            <--> chunk 0 length (pre-loaded data not included)
    const int xored_n_x = n_x - (NGRAMM - 1);
    int x_chunk_len = (xored_n_x + NUM_INPUT_CHUNKS - 1) / NUM_INPUT_CHUNKS;
    const int x_chunk_start = x_chunk_idx * x_chunk_len;
    if (x_chunk_start + x_chunk_len > xored_n_x) {
        x_chunk_len = xored_n_x - x_chunk_start;
    }

    int i; // iterator

    // local copies of the:
    // - HD feature vector chunk n-gramm buffer
    block_t l_item_buffer[NGRAMM];
    memset(l_item_buffer, 0, sizeof(l_item_buffer));

    // - encoded n-gramm summation chunk buffer
    uint32_t l_ngramm_sum_buffer[sizeof(block_t) * 8];
    memset(l_ngramm_sum_buffer, 0, sizeof(l_ngramm_sum_buffer));

    // - HD vector chunk lookup array
    // To load the lookup array, we should use every thread for fetching the data.
    // Split n_items into chunks, to load the lookup of a single block in parallel.
    int num_items_to_load = (n_items + NUM_INPUT_CHUNKS - 1) / NUM_INPUT_CHUNKS;
    int start_item_to_load = x_chunk_idx * num_items_to_load;
    if (start_item_to_load + num_items_to_load > n_items) {
        num_items_to_load = n_items - start_item_to_load;
    }
    block_t *  s_item_lookup = s;
    for (i = start_item_to_load; i < start_item_to_load + num_items_to_load; i++) {
        s_item_lookup[i * blockDim.x + threadIdx.x] = item_lookup[i * n_blk + blk_idx];
    }

    // sync threads if NUM_INPUT_CHUNKS is bigger than 1 (else, we do not have any dependeny)
    if (NUM_INPUT_CHUNKS > 1) {
        __syncthreads();
    }

    // loop over every single feature
    int x_chunk_iter;
    for (x_chunk_iter = 0; x_chunk_iter < NGRAMM - 1 + x_chunk_len; x_chunk_iter++) {
        // barrel shift each HD feature vector chunk as it gets a feature increment older
        int i;
        for (i = NGRAMM - 1; i >= 1; i--) {
            block_t previous = l_item_buffer[i-1];
            l_item_buffer[i] = (previous << 1) | (previous >> 31);
        }

        // populate new HD feature vector chunk
        feature_t item_lookup_idx = x[x_chunk_start + x_chunk_iter];
        block_t item = s_item_lookup[item_lookup_idx * blockDim.x + threadIdx.x];
        l_item_buffer[0] = item;

        // only pre-load the first (NGRAMM - 1) items
        if (x_chunk_iter >= NGRAMM - 1) {
            // compute the encoded n-gramm
            block_t tmp_ngramm_buffer = item;
            for (i = 1; i < NGRAMM; i++) {
                tmp_ngramm_buffer ^= l_item_buffer[i];
            }
    
            // unpack and accumulate the encoded n-gramm
            for (i = 0; i < sizeof(block_t) * 8; i++) {
                l_ngramm_sum_buffer[i] += (tmp_ngramm_buffer >> i) & 1;
            }
        }
    }

    // accumulating the results to the ngramm_sum_buffer creates a memory race condition
    // avoid this by means of linear reduction across threads
    // reduction can use shared memory
    // TODO implement a better reduction
    if (NUM_INPUT_CHUNKS > 1) {
        // make sure that all threads are done
        __syncthreads();
        // reuse shared memory for the reduction
        uint32_t * s_ngramm_sum_buffer = s;

        int curr_x_chunk = 0;
        // make the first chunk (overwrite values)
        if (curr_x_chunk == x_chunk_idx) {
            for (i = 0; i < sizeof(block_t) * 8; i++) {
                s_ngramm_sum_buffer[i * blockDim.x + threadIdx.x] = l_ngramm_sum_buffer[i];
            }
        }

        // copy all remaining chunks except the last one
        for (curr_x_chunk = 1; curr_x_chunk < (NUM_INPUT_CHUNKS - 1); curr_x_chunk++) {
            __syncthreads();
            if (curr_x_chunk == x_chunk_idx) {
                // copy values back to ngramm_sum_buffer
                for (i = 0; i < sizeof(block_t) * 8; i++) {
                    s_ngramm_sum_buffer[i * blockDim.x + threadIdx.x] += l_ngramm_sum_buffer[i];
                }
            }
        }

        // add the last one and copy into global (result) memory
        curr_x_chunk = NUM_INPUT_CHUNKS - 1;
        __syncthreads();
        if (curr_x_chunk == x_chunk_idx) {
            // copy values back to ngramm_sum_buffer
            for (i = 0; i < sizeof(block_t) * 8; i++) {
                ngramm_sum_buffer[i * n_blk + blk_idx] = l_ngramm_sum_buffer[i] + s_ngramm_sum_buffer[i * blockDim.x + threadIdx.x];
            }
        }
    } else {
        for (i = 0; i < sizeof(block_t) * 8; i++) {
            ngramm_sum_buffer[i * n_blk + blk_idx] = l_ngramm_sum_buffer[i];
        }
    }
}

// Wrapper function to call the kernel. Input data (x) must already be copied to the device.
// if stream is NULL, then the default stream is used.
extern "C" void hd_encoder_call_kernel(
    struct hd_encoder_t * const state,
    const feature_t * d_x,
    const int n_x,
    int use_input_chunks = 1,
    cudaStream_t stream = NULL
)
{
    dim3 threads, grid;
    int smem_size;

    // conmpute the maximum of n_items and 32, to make sure we have enough space for item lookup and reduction
    int smem_parts;
    if (state->n_items > sizeof(block_t) * 8) {
        smem_parts = state->n_items;
    } else {
        smem_parts = sizeof(block_t) * 8;
    }

    if (use_input_chunks) {
        // Each grid block calculates a chunk of the HD vector
        // for the entire input. Withing the block, threads divide work
        // both along the HD vector and the input.
        threads.x = NUM_HD_BLOCKS_IN_BLOCK;
        threads.y = MAX_NUM_INPUT_CHUNKS;

        // compute the number of blocks used
        grid.x = (state->n_blk + NUM_HD_BLOCKS_IN_BLOCK - 1) / NUM_HD_BLOCKS_IN_BLOCK;

        smem_size = smem_parts * NUM_HD_BLOCKS_IN_BLOCK * sizeof(block_t);
    } else {
        threads.x = NUM_THREADS_IN_BLOCK;
        grid.x = (state->n_blk + NUM_THREADS_IN_BLOCK - 1) / NUM_THREADS_IN_BLOCK;
        smem_size = smem_parts * NUM_THREADS_IN_BLOCK * sizeof(block_t);
    }

    switch(state->ngramm) {
#define CALL_KERNEL_CASE(N) \
        case N: \
            if (use_input_chunks) { \
                hd_encoder_kernel<N, MAX_NUM_INPUT_CHUNKS><<<grid, threads, smem_size, stream>>>(    \
                    state->n_blk, \
                    state->device.ngramm_sum_buffer, \
                    state->device.item_lookup, \
                    state->n_items, \
                    d_x, n_x); \
            } else { \
                hd_encoder_kernel<N, 1><<<grid, threads, smem_size, stream>>>(    \
                    state->n_blk, \
                    state->device.ngramm_sum_buffer, \
                    state->device.item_lookup, \
                    state->n_items, \
                    d_x, n_x); \
            } \
            break;

        CALL_KERNEL_CASE(2)
        CALL_KERNEL_CASE(3)
        CALL_KERNEL_CASE(4)
        CALL_KERNEL_CASE(5)
        CALL_KERNEL_CASE(6)
        CALL_KERNEL_CASE(7)
        CALL_KERNEL_CASE(8)

        default:
            printf("Error! ngramm must be between 2 and 8, but it was %d\n", state->ngramm);
    }
}

extern "C" void hd_encoder_setup_device(struct hd_encoder_t * const state) {
    // allocate memory
    cudaMalloc(&(state->device.item_lookup), state->n_items * state->n_blk * sizeof(block_t));
    cudaMalloc(&(state->device.ngramm_sum_buffer), state->n_blk * sizeof(block_t) * 8 * sizeof(uint32_t));
    cudaMalloc(&(state->device.ngramm_buffer), state->ngramm * state->n_blk * sizeof(block_t));

    // copy LUT to device
    cudaMemcpy(
        state->device.item_lookup,
        state->item_lookup,
        state->n_items * state->n_blk * sizeof(block_t),
        cudaMemcpyHostToDevice
    );
}

extern "C" void hd_encoder_free(struct hd_encoder_t * const state) {
    cudaFree(state->device.item_lookup);
    cudaFree(state->device.ngramm_sum_buffer);
    cudaFree(state->device.ngramm_buffer);

    free(state->ngramm_buffer);
    free(state->ngramm_sum_buffer);
    free(state->item_buffer);
    free(state->item_lookup);

    cudaDeviceReset();
}

extern "C" void hd_encoder_encode (
    struct hd_encoder_t * const state,
    const feature_t * const x,
    const int n_x
)
{
    const int n_blk = state->n_blk;

    // reset the sum count and buffer
    state->ngramm_sum_count = 0;
    cudaMemset(
        state->device.ngramm_sum_buffer,
        0,
        n_blk * sizeof(block_t) * 8 * sizeof(uint32_t)
    );

    // allocate input data memory on the device
    feature_t * d_x;
    cudaMalloc(&d_x, n_x * sizeof(feature_t));
    // copy the input data
    cudaMemcpy(d_x, x, n_x * sizeof(feature_t), cudaMemcpyHostToDevice);

    // call the kernel
    hd_encoder_call_kernel(state, d_x, n_x);

    cudaDeviceSynchronize();

    // copy the output (ngramm_sum_buffer) back from the device
    cudaMemcpy(
        state->ngramm_sum_buffer,
        state->device.ngramm_sum_buffer,
        n_blk * sizeof(block_t) * 8 * sizeof(uint32_t),
        cudaMemcpyDeviceToHost
    );

    // free input memory
    cudaFree(d_x);

    // set the ngramm_sum_count
    state->ngramm_sum_count += n_x - (state->ngramm - 1);
}

void clip(
    const uint32_t * const in,
    const int n_in,
    const int count,
    block_t * const out
)
{
    int threshold = count / 2;

    memset(out, 0, (n_in + sizeof(block_t) * 8 - 1) / (sizeof(block_t) * 8));

    // we ignore the randomization here...

    int n_blk = n_in / 32;
    int blk_idx;
    for (blk_idx = 0; blk_idx < n_blk; blk_idx++) {
        int i;
        for (i = 0; i < 32; i++) {
            out[blk_idx] <<= 1;
            out[blk_idx] += ((uint32_t)(threshold - in[i * n_blk + blk_idx])) >> 31;
        }
    }

}

void hd_encoder_clip(
    struct hd_encoder_t * const state
)
{
    clip(
        state->ngramm_sum_buffer,
        sizeof(block_t) * 8 * state->n_blk,
        state->ngramm_sum_count,
        state->ngramm_buffer
    );
}