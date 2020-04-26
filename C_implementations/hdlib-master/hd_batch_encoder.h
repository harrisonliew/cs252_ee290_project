#ifndef HD_BATCH_ENCODER_H
#define HD_BATCH_ENCODER_H

#include "hd_encoder.h"

// initializes a batch of states.
// states is an array of hd_encoder_t[batch_size]
// the first element must already be initialized (with hd_encoder_init),
// and the item lookup must already be set up.
void hd_batch_encoder_init(
     struct hd_encoder_t * const states,
     const int batch_size
);

void hd_batch_encoder_setup_device(
    struct hd_encoder_t * const states,
    const int batch_size
);

void hd_batch_encoder_free(
    struct hd_encoder_t * const states,
    const int batch_size
);

void hd_batch_encoder_encode (
    struct hd_encoder_t * states,
    const int batch_size,
    const feature_t ** const x,
    const int * const n_x
);

#endif //HD_BATCH_ENCODER_H
