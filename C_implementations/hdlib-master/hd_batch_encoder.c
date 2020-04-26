#include <string.h>
#include <stdint.h>
#include <stdlib.h>

#include "hd_batch_encoder.h"

void hd_batch_encoder_init(
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

void hd_batch_encoder_setup_device(
    struct hd_encoder_t * const states,
    const int batch_size
)
{
    // nothing to do!
}

void hd_batch_encoder_free(
    struct hd_encoder_t * const states,
    const int batch_size
)
{
    int i;
    for (i = 0; i < batch_size; i++) {
        free(states[i].ngramm_buffer);
        free(states[i].ngramm_sum_buffer);
        free(states[i].item_buffer);
        if (i == 0) {
            free(states[i].item_lookup);
        }
    }
}

// TODO use openMP
void hd_batch_encoder_encode (
    struct hd_encoder_t * states,
    const int batch_size,
    const feature_t ** const x,
    const int * const n_x
)
{
    int i;
    for (i = 0; i < batch_size; i++) {
        hd_encoder_encode(&(states[i]), x[i], n_x[i]);
    }
}
