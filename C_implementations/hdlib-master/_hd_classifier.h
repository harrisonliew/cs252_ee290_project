typedef uint8_t class_t;

struct hd_classifier_t
{
    // configuration
    int profiling;

    // HD vector length
    int n_blk;

    // number of classes supported by hd_classifier
    int n_class;

    // trained class vectors pre-clipping
    // shape: [n_class, d]
    uint32_t * class_vec_sum;
    int * class_vec_cnt; // TODO binding

    // trained class vectors
    // shape: [n_class, n_blk]
    block_t * class_vec;
};

void hd_classifier_init(
    struct hd_classifier_t * const state,
    const int n_blk,
    const int n_class,
    const int profiling
);

void hd_classifier_free(
    struct hd_classifier_t * const state
);

void hd_classifier_enable_profiling(
    struct hd_classifier_t * const state
);

void hd_classifier_threshold(
    const struct hd_classifier_t * const state
);

class_t hd_classifier_predict(
    const struct hd_classifier_t * const state,
    struct hd_encoder_t * const encoder_state,
    const feature_t * const x,
    const int n_x
);

void hd_classifier_predict_batch(
    const struct hd_classifier_t * const state,
    struct hd_encoder_t * const encoder_states,
    const int batch_size,
    const feature_t ** const x,
    const int * n_x,
    class_t * prediction
);

void hamming_distance_init();

int hamming_distance(
    const void * const a,
    const void * const b,
    const int n
);

// stores classifier state and encoder state
void save(
    const struct hd_classifier_t * const s_classif,
    const struct hd_encoder_t * const s_enc,
    const char * const filename
);

// initializes s_classifier and s_encoder
// Allocates necessary memory and loads the data! init is not necessary!
// returns 0 if load was successful
// returns -1 if file was not found
int load(
    struct hd_classifier_t * const s_classif,
    struct hd_encoder_t * const s_enc,
    const char * const filename
);
