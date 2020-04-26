#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#include "hd_encoder.h"
#include "hd_batch_encoder.h"
#include "hd_classifier.h"

void hd_classifier_init(
    struct hd_classifier_t * const state,
    const int n_blk,
    const int n_class,
    const int profiling
)
{
    state->n_blk = n_blk;
    state->n_class = n_class;
    // class_vec_sum and class_vec_cnt are not initialised, they are set externally
    state->class_vec = malloc(n_class * n_blk * sizeof(block_t));
    state->profiling = profiling;
}

void hd_classifier_free(
    struct hd_classifier_t * const state
)
{
    free(state->class_vec);
}

void hd_classifier_enable_profiling(
    struct hd_classifier_t * const state
)
{
    state->profiling = 1;
}

void hd_classifier_threshold(
    const struct hd_classifier_t * const state
)
{
    class_t class;
    for (class = 0; class < state->n_class; class++)
    {
        clip(
            state->class_vec_sum + class * state->n_blk * sizeof(block_t) * 8,
            state->n_blk * sizeof(block_t) * 8,
            state->class_vec_cnt[class],
            state->class_vec + class * state->n_blk
        );
    }
}

class_t hd_classifier_predict(
    const struct hd_classifier_t * const state,
    struct hd_encoder_t * const encoder_state,
    const feature_t * const x,
    const int n_x
)
{
    if (state->profiling)
    {
        // profile encoding time
        struct timespec tstart = {0,0};
        struct timespec tend = {0,0};
        clock_gettime(CLOCK_REALTIME, &tstart);

        hd_encoder_encode(encoder_state, x, n_x);

        clock_gettime(CLOCK_REALTIME, &tend);
        long dtime = (1000000000 * tend.tv_sec + tend.tv_nsec) - (1000000000 * tstart.tv_sec + tstart.tv_nsec);
        printf("%d, %ld\n", n_x, dtime / 1000);
    }
    else
    {
        hd_encoder_encode(encoder_state, x, n_x);
    }

    hd_encoder_clip(encoder_state);

    int best_score = INT_MAX;
    class_t best_class;
    class_t class;
    for (class = 0; class < state->n_class; class++)
    {
        int score = hamming_distance(
            encoder_state->ngramm_buffer,
            state->class_vec + class * state->n_blk,
            state->n_blk * sizeof(state->class_vec[0])
        );

        if (score < best_score)
        {
            best_score = score;
            best_class = class;
        }
    }

    return best_class;
}

void hd_classifier_predict_batch(
    const struct hd_classifier_t * const state,
    struct hd_encoder_t * const encoder_states,
    const int batch_size,
    const feature_t ** const x,
    const int * n_x,
    class_t * prediction
)
{
    int i;

    if (state->profiling)
    {
        // profile encoding time
        struct timespec tstart = {0,0};
        struct timespec tend = {0,0};
        clock_gettime(CLOCK_REALTIME, &tstart);

        hd_batch_encoder_encode(encoder_states, batch_size, x, n_x);
        
        clock_gettime(CLOCK_REALTIME, &tend);
        long dtime = (1000000000 * tend.tv_sec + tend.tv_nsec) - (1000000000 * tstart.tv_sec + tstart.tv_nsec);
    
        // compute total number of samples
        int tot_n_x = 0;
        for (i = 0; i < batch_size; i++) {
            tot_n_x += n_x[i];
        }
        printf("%d, %ld\n", tot_n_x, dtime / 1000);
    }
    else
    {
        hd_batch_encoder_encode(encoder_states, batch_size, x, n_x);
    }

    // for every sample in the batch, clip and do inference
    //int i;
    for (i = 0; i < batch_size; i++) {
        hd_encoder_clip(&encoder_states[i]);

        int best_score = INT_MAX;
        class_t best_class;
        class_t class;
        for (class = 0; class < state->n_class; class++)
        {
            int score = hamming_distance(
                encoder_states[i].ngramm_buffer,
                state->class_vec + class * state->n_blk,
                state->n_blk * sizeof(state->class_vec[0])
            );

            if (score < best_score)
            {
                best_score = score;
                best_class = class;
            }
        }
        prediction[i] = best_class;
    }
}

char hamming_distance_lookup[1 << 8];

void hamming_distance_init()
{
    int i;
    for (i = 0; i < 1 << 8; i++)
    {
        int tmp = i;
        hamming_distance_lookup[i] = 0;
        int j;
        for (j = 0; j < 8; j++)
        {
            hamming_distance_lookup[i] += tmp & 1;
            tmp >>= 1;
        }
    }
}

int hamming_distance(
    const void * const a,
    const void * const b,
    const int n
)
{
    int result = 0;
    const uint8_t * a_iter = a;
    const uint8_t * b_iter = b;

    int i;
    for (i = 0; i < n; i++)
    {
        result += hamming_distance_lookup[*a_iter++ ^ *b_iter++];
    }

    return result;
}

void save(
    const struct hd_classifier_t * const s_classif,
    const struct hd_encoder_t * const s_enc,
    const char * const filename
)
{
    FILE * fp = fopen(filename, "wb");

    // write dimensionality
    fwrite(&(s_classif->n_blk), sizeof(s_classif->n_blk), 1, fp);
    fwrite(&(s_classif->n_class), sizeof(s_classif->n_class), 1, fp);
    fwrite(&(s_enc->ngramm), sizeof(s_enc->ngramm), 1, fp);
    fwrite(&(s_enc->n_items), sizeof(s_enc->n_items), 1, fp);

    // write trained language vectors
    fwrite(s_classif->class_vec, sizeof(block_t), s_classif->n_blk * s_classif->n_class, fp);

    // write item_lookup
    fwrite(s_enc->item_lookup, sizeof(block_t), s_enc->n_items * s_enc->n_blk, fp);

    fclose(fp);
}

int load(
    struct hd_classifier_t * const s_classif,
    struct hd_encoder_t * const s_enc,
    const char * filename
)
{
    // to keep track of how many bytes were read, for checking if everything was ok
    int bytes_read = 0;

    // try to open file
    FILE * fp = fopen(filename, "rb");

    // exit if fp is null
    if (fp == NULL) return -1;

    // first, read dimensionality from the file
    bytes_read += fread(&(s_classif->n_blk), sizeof(s_classif->n_blk), 1, fp);
    bytes_read += fread(&(s_classif->n_class), sizeof(s_classif->n_class), 1, fp);
    bytes_read += fread(&(s_enc->ngramm), sizeof(s_enc->ngramm), 1, fp);
    bytes_read += fread(&(s_enc->n_items), sizeof(s_enc->n_items), 1, fp);
    s_enc->n_blk = s_classif->n_blk; // also apply n_blk to encoder

    printf("Reading model: D=%d, n_class=%d, ngramm=%d, n_items=%d\n",
           s_enc->n_blk * 32,
           s_classif->n_class,
           s_enc->ngramm,
           s_enc->n_items);

    // now, allocate the necessary memory
    hd_classifier_init(s_classif, s_classif->n_blk, s_classif->n_class, 0);
    hd_encoder_init(s_enc, s_enc->n_blk, s_enc->ngramm, s_enc->n_items);
    // TODO This line above also initializes the item lookup!

    // read the trained language vectors
    bytes_read += fread(s_classif->class_vec, sizeof(block_t), s_classif->n_blk * s_classif->n_class, fp);

    // read item_lookup
    bytes_read += fread(s_enc->item_lookup, sizeof(block_t), s_enc->n_items * s_enc->n_blk, fp);

    // close the file
    fclose(fp);

    // check if the right amount of bytes were read
    if (bytes_read == 4 + s_classif->n_blk * s_classif->n_class + s_enc->n_items * s_enc->n_blk)
    {
        return 0;
    }
    else
    {
        printf("Failed to read file: %s! Bytes read: %d\n", filename, bytes_read);
        return -1;
    }
}
