#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

extern "C" {
#include "hd_batch_encoder.h"
}

template<int NGRAMM>
__global__ void hd_encoder_kernel(
    const int n_blk,
    uint32_t * __restrict__ ngramm_sum_buffer,
    const block_t * __restrict__ item_lookup,
    const int n_items,
    const feature_t * __restrict__ x,
    const int n_x
);

extern "C" void hd_encoder_call_kernel(
    struct hd_encoder_t * const state,
    const feature_t * d_x,
    const int n_x,
    int use_input_chunks = 1,
    cudaStream_t stream = NULL
);

extern "C" void hd_batch_encoder_init(
     struct hd_encoder_t * const states,
     const int batch_size
)
{
    int n_blk = states[0].n_blk;
    int ngramm = states[0].ngramm;
    int n_items = states[0].n_items;

    int i;
    for (i = 1; i < batch_size; i++) {
        // initialize the state
        hd_encoder_init(&(states[i]), n_blk, ngramm, n_items);
        // free up the item lookup since we do use the same as the first one
        free(states[i].item_lookup);
        // use the same item lookup as first element in batch
        states[i].item_lookup = states[0].item_lookup;
    }
}

extern "C" void hd_batch_encoder_setup_device(
    struct hd_encoder_t * const states,
    const int batch_size
)
{
    int i;
    for (i = 0; i < batch_size; i++) {
        // initialize the state
        cudaMalloc(&(states[i].device.ngramm_sum_buffer), states[i].n_blk * sizeof(block_t) * 8 * sizeof(uint32_t));
        cudaMalloc(&(states[i].device.ngramm_buffer), states[i].ngramm * states[i].n_blk * sizeof(block_t));

        // only the first should copy the item lookup
        if (i == 0) {
            cudaMalloc(&(states[i].device.item_lookup), states[i].n_items * states[i].n_blk * sizeof(block_t));
            cudaMemcpy(
                states[i].device.item_lookup,
                states[i].item_lookup,
                states[i].n_items * states[i].n_blk * sizeof(block_t),
                cudaMemcpyHostToDevice
            );
        } else {
            // use the same item lookup as first element in batch
            states[i].device.item_lookup = states[0].device.item_lookup;
        }
    }
}

void hd_batch_encoder_free(
    struct hd_encoder_t * const states,
    const int batch_size
)
{
    int i;
    for (i = 0; i < batch_size; i++) {
        cudaFree(states[i].device.ngramm_sum_buffer);
        cudaFree(states[i].device.ngramm_buffer);

        free(states[i].ngramm_buffer);
        free(states[i].ngramm_sum_buffer);
        free(states[i].item_buffer);
        if (i == 0) {
            free(states[i].item_lookup);
            cudaFree(states[i].device.item_lookup);
        }
    }

    cudaDeviceReset();
}

void hd_batch_encoder_encode (
    struct hd_encoder_t * states,
    const int batch_size,
    const feature_t ** const x,
    const int * const n_x
)
{
    // setup streams
    cudaStream_t * streams = (cudaStream_t*) malloc(sizeof(cudaStream_t) * batch_size);
    int i;
    for (i = 0; i < batch_size; i++) {
        cudaStreamCreate(&(streams[i]));
    }

    const int n_blk = states[0].n_blk;

    // array for device pointers
    feature_t ** d_x = (feature_t**) malloc(sizeof(feature_t *) * batch_size);

    // start every kernel
    for (i = 0; i < batch_size; i++) {
        // reset the sum count
        states[i].ngramm_sum_count = 0;

        // allocate input data memory on the device
        cudaMalloc(&(d_x[i]), n_x[i] * sizeof(feature_t));
        // copy the input data
        cudaMemcpyAsync(d_x[i], x[i], n_x[i] * sizeof(feature_t), cudaMemcpyHostToDevice, streams[i]);

        // call the kernel
        hd_encoder_call_kernel(&(states[i]), d_x[i], n_x[i], 0, streams[i]);

        // copy the output (ngramm_sum_buffer) back from the device
        cudaMemcpyAsync(
            states[i].ngramm_sum_buffer,
            states[i].device.ngramm_sum_buffer,
            n_blk * sizeof(block_t) * 8 * sizeof(uint32_t),
            cudaMemcpyDeviceToHost,
            streams[i]
        );

        // set the ngramm_sum_count
        states[i].ngramm_sum_count += n_x[i] - (states[i].ngramm - 1);
    }

    // wait until batch is complete
    cudaDeviceSynchronize();

    // free up all the input data memory on the device
    for (i = 0; i < batch_size; i++) {
        cudaFree(d_x[i]);
    }
    // free up the array holding all the device pointers
    free(d_x);
    // free up the streams
    free(streams);
}