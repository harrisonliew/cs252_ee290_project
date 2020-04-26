#include <string.h>
#include <stdint.h>
#include <stdlib.h>

#include "hd_encoder.h"

// rand() generates a random number between 0 and RAND_MAX, which is
// guaranteed to be no less than 32767 on any standard implementation.
#if (RAND_MAX >= (1u << 32) - 1u)
#define RAND_BYTES 4
#elif (RAND_MAX >= (1u << 16) - 1u)
#define RAND_BYTES 2
#elif (RAND_MAX >= (1u << 8) - 1u)
#define RAND_BYTES 1
#endif

void hd_encoder_init(
    struct hd_encoder_t * const state,
    const int n_blk,
    const int ngramm,
    const int n_items
)
{
    state->n_blk = n_blk;
    state->ngramm = ngramm;
    state->n_items = n_items;
    state->ngramm_buffer = (block_t*)malloc(n_blk * sizeof(block_t));
    state->ngramm_sum_buffer = (uint32_t*)malloc(n_blk * sizeof(block_t) * 8 * sizeof(uint32_t));
    state->item_buffer = (block_t*)malloc(ngramm * n_blk * sizeof(block_t));
    state->item_buffer_head = 0;
    state->item_lookup = (block_t*)malloc(n_items * n_blk * sizeof(block_t));

    // initialise HD vector lookup table with uniformly distributed 0s and 1s
    int i;
    for (i = 0; i < n_items * n_blk; ++i)
    {
        state->item_lookup[i] = 0;

        int j;
        for (j = 0; j < sizeof(state->item_lookup[0]) / RAND_BYTES; j++)
        {
            state->item_lookup[i] <<= 8 * RAND_BYTES;
            state->item_lookup[i] += rand() & ((1u << 8 * RAND_BYTES) - 1u);
        }
    }
}
