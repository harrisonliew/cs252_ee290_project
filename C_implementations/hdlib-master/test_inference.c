/*
 * Main file to load a pretrained model and predict (prepared) test samples
 */

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "hd_encoder.h"
#include "hd_batch_encoder.h"
#include "hd_classifier.h"

#define MODEL_FILE "examples/language_classif/data/models/3gramm"

#define TEST_FOLDER "examples/language_classif/data/binary_test_data/"
#define TEST_FOLDER_LEN 48
#define TEST_SAMPLE_NAME "sample_00000"
#define TEST_SAMPLE_NAME_LEN 12
#define TEST_SAMPLE_NAME_IDX (TEST_FOLDER_LEN + 7)
#define MEASUREMENT_SAMPLE_NAME "measurement_sample"
#define MEASUREMENT_SAMPLE_NAME_LEN 18

# define BATCH_SIZE 16

char current_filename[TEST_FOLDER_LEN + TEST_SAMPLE_NAME_LEN + 11];

feature_t * load_binary_sample(char * filename, int * n_x, class_t * y)
{
    // try to load the file
    FILE * fp = fopen(filename, "rb");
    if (fp == NULL) return NULL;

    int bytes_read = 0;

    // read class idx and size
    bytes_read += fread(y, sizeof(class_t), 1, fp);
    bytes_read += fread(n_x, sizeof(int), 1, fp);

    // allocate memory of given size
    feature_t * x = malloc(sizeof(feature_t) * (*n_x));

    // read X data
    bytes_read += fread(x, sizeof(feature_t), (*n_x), fp);

    // check if the correct number of bytes were read
    if (bytes_read != 2 + *n_x) {
        printf("Failed to read file: %s!\n", current_filename);
        fclose(fp);
        return NULL;
    }

    fclose(fp);
    return x;
}

feature_t * load_test_sample(int sample_idx, int * n_x, class_t * y)
{
    // prepare filename
    sprintf(current_filename + TEST_SAMPLE_NAME_IDX, "%05d", sample_idx);
    return load_binary_sample(current_filename, n_x, y);
}

feature_t * load_measurement_sample(int * n_x, class_t * y) {
    char filename[TEST_FOLDER_LEN + MEASUREMENT_SAMPLE_NAME_LEN + 11];
    strcpy(filename, TEST_FOLDER);
    strcat(filename, MEASUREMENT_SAMPLE_NAME);
    return load_binary_sample(filename, n_x, y);
}

feature_t * get_random_sample(int n_x, int n_items) {
    feature_t * data = malloc(n_x * sizeof(feature_t));
    int i;
    for (i = 0; i < n_x; i++) {
        data[i] = (feature_t)(rand() % n_items);
    }
    return data;
}

int do_measurement(int from, int to, int step, int num_repeat) {
    if (num_repeat <= 0) num_repeat = 1;

    // prepare data
    struct hd_encoder_t encoder;
    struct hd_classifier_t classifier;

    // initialize hamming distance
    hamming_distance_init();

    // load
    if (load(&classifier, &encoder, MODEL_FILE) != 0) {
        printf("Could not read model!\n");
        return 1;
    }

    hd_classifier_enable_profiling(&classifier);

    // setup the device (allocate device memory and copy item lookup to device)
    hd_encoder_setup_device(&encoder);
    // model is now loaded and ready to do inference!

    // prepare data
    int n_x = to;
    /*
    class_t y;
    feature_t * x = load_measurement_sample(&n_x, &y);
    if (x == NULL) {
        printf("no data found!\n");
        return 1;
    }
    */

    int cur_len = from;

    while(cur_len <= to) {
        int i;
        for (i = 0; i < num_repeat; i++) {
            // generate random data
            feature_t * x = get_random_sample(cur_len, encoder.n_items);
            // make prediction
            hd_classifier_predict(&classifier, &encoder, x, cur_len);
            // free up memory
            free(x);
        }
        // increment step
        cur_len += step;
        if (n_x < cur_len) break;
    }

    // free(x);

    // free up all memory
    hd_encoder_free(&encoder);
    hd_classifier_free(&classifier);

    return 0;
}

int do_batch_measurement(int from, int to, int step, int num_repeat) {
    if (num_repeat <= 0) num_repeat = 1;

    // prepare data
    struct hd_encoder_t encoders[BATCH_SIZE];
    struct hd_classifier_t classifier;

    // initialize hamming distance
    hamming_distance_init();

    // load data (encoder data into the first encoder
    if (load(&classifier, &(encoders[0]), MODEL_FILE) != 0) {
        printf("Could not read model!\n");
        return 1;
    }

    hd_classifier_enable_profiling(&classifier);

    // setup the batch
    hd_batch_encoder_init(encoders, BATCH_SIZE);

    // setup the device (allocate device memory and copy item lookup to device)
    hd_batch_encoder_setup_device(encoders, BATCH_SIZE);
    // model is now loaded and ready to do inference!

    // prepare current_filename
    strcpy(current_filename, TEST_FOLDER);
    strcat(current_filename, TEST_SAMPLE_NAME);

    // prepare data
    int n_x[BATCH_SIZE];
    feature_t * x[BATCH_SIZE];
    class_t y[BATCH_SIZE];
    class_t yhat[BATCH_SIZE];

    // load the measurement data multiple times
    int sample;
    /*
    for (sample = 0; sample < BATCH_SIZE; sample++) {
        x[sample] = load_measurement_sample(&(n_x[sample]), &(y[sample]));
        if (x[sample] == NULL) {
            printf("Cannot load measurement sample!\n");
        }
    }
    int original_n_x = n_x[0];
    */
    int original_n_x = to;

    int cur_len = from;
    while(cur_len <= to) {
        int i;
        for (i = 0; i < num_repeat; i++) {
            // prepare n_x vector to all be cur_len
            for (sample = 0; sample < BATCH_SIZE; sample++) {
                x[sample] = get_random_sample(cur_len, encoders[0].n_items);
                n_x[sample] = cur_len;
            }

            // make prediction
            hd_classifier_predict_batch(&classifier, encoders, BATCH_SIZE, (const feature_t**)x, n_x, yhat);

            // free up memory
            for (sample = 0; sample < BATCH_SIZE; sample++) {
                free(x[sample]);
            }
        }
        // increment step
        cur_len += step;
        if (original_n_x < cur_len) break;
    }

    // free up memory of measurement samples
    /*
    for (sample = 0; sample < BATCH_SIZE; sample++) {
        free(x[sample]);
    }
    */

    // free up all memory
    hd_batch_encoder_free(encoders, BATCH_SIZE);
    hd_classifier_free(&classifier);

    return 0;
}

int do_inference(int num_samples, int verbose, int profiling) {
    // prepare data
    struct hd_encoder_t encoder;
    struct hd_classifier_t classifier;

    // initialize hamming distance
    hamming_distance_init();

    // load
    if (load(&classifier, &encoder, MODEL_FILE) != 0) {
        printf("Could not read model!\n");
        return 1;
    }

    if (profiling)
    {
        hd_classifier_enable_profiling(&classifier);
    }

    // setup the device (allocate device memory and copy item lookup to device)
    hd_encoder_setup_device(&encoder);
    // model is now loaded and ready to do inference!

    // prepare current_filename
    strcpy(current_filename, TEST_FOLDER);
    strcat(current_filename, TEST_SAMPLE_NAME);

    // prepare data
    int idx = 0;

    // loop through every element until file was no longer found
    int n_err = 0;
    int n_tot = 0;
    while(1) {
        // load the sample
        int n_x;
        class_t y;
        feature_t * x = load_test_sample(idx++, &n_x, &y);
        if (x == NULL) break;

        // make prediction
        class_t yhat = hd_classifier_predict(&classifier, &encoder, x, n_x);

        // check if result was the same
        n_tot++;
        if (yhat != y) {
            n_err++;
            if (verbose) {
                printf("Error: True class: %d, Estimation: %d\n", y, yhat);
            }
        }

        // free the sample up again
        free(x);

        if (num_samples > 0 && idx >= num_samples) {
            break;
        }
    }

    // print results
    printf("Accuracy: %f\n", 1.0 - (double)n_err / (double)n_tot);

    // free up all memory
    hd_encoder_free(&encoder);
    hd_classifier_free(&classifier);

    return 0;
}

int do_batch_inference(int num_samples, int verbose, int profiling) {
    // prepare data
    struct hd_encoder_t encoders[BATCH_SIZE];
    struct hd_classifier_t classifier;

    // initialize hamming distance
    hamming_distance_init();

    // load data (encoder data into the first encoder
    if (load(&classifier, &(encoders[0]), MODEL_FILE) != 0) {
        printf("Could not read model!\n");
        return 1;
    }

    if (profiling)
    {
        hd_classifier_enable_profiling(&classifier);
    }

    // setup the batch
    hd_batch_encoder_init(encoders, BATCH_SIZE);

    // setup the device (allocate device memory and copy item lookup to device)
    hd_batch_encoder_setup_device(encoders, BATCH_SIZE);
    // model is now loaded and ready to do inference!

    // prepare current_filename
    strcpy(current_filename, TEST_FOLDER);
    strcat(current_filename, TEST_SAMPLE_NAME);

    // prepare data
    int idx = 0;
    int n_x[BATCH_SIZE];
    feature_t * x[BATCH_SIZE];
    class_t y[BATCH_SIZE];
    class_t yhat[BATCH_SIZE];

    // loop through every element until file was no longer found
    int n_err = 0;
    int n_tot = 0;
    while(1) {
        // load all samples from the batch
        int i;
        for (i = 0; i < BATCH_SIZE; i++) {
            x[i] = load_test_sample(idx++, &(n_x[i]), &(y[i]));
            if (x[i] == NULL) break;
        }
        // if exited before, the block is smaller
        if (i == 0) break;
        int batch_size = i;

        // make prediction
        hd_classifier_predict_batch(&classifier, encoders, batch_size, (const feature_t**)x, n_x, yhat);

        // check if result was the same
        for (i = 0; i < batch_size; i++) {
            n_tot++;
            if (yhat[i] != y[i]) {
                n_err++;
                if (verbose) {
                    printf("Error: True class: %d, Estimation: %d\n", y[i], yhat[i]);
                }
            }

            // free up memory
            free(x[i]);
        }

        if (num_samples > 0 && idx >= num_samples) {
            break;
        }
    }

    // print results
    printf("Accuracy: %f\n", 1.0 - (double)n_err / (double)n_tot);

    // free up all memory
    hd_batch_encoder_free(encoders, BATCH_SIZE);
    hd_classifier_free(&classifier);

    return 0;
}

int main(int argc, char *argv[])
{
    int verbose = 0, profiling = 0, num_samples = -1;
    
    int i;
    for (i = 0; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0) {
            verbose = 1;
        }
        if (strcmp(argv[i], "-p") == 0) {
            profiling = 1;
        }
        if (strcmp(argv[i], "-n") == 0) {
            // increment i to get to the next argument
            i += 1;
            if (i == argc) {
                printf("The '-n' argument requires a number!\n");
                return 1;
            }
            char * p_end;
            // parse the input to a integer
            num_samples = (int) strtol(argv[i], &p_end, 10);
            if (num_samples == 0) {
                printf("A positive number is required for the '-n' argument\n");
                return 1;
            }
        }
    }

    // set parameter to something positive to limit the number of samples processed
    //return do_batch_inference(num_samples, verbose, profiling);
    return do_inference(num_samples, verbose, profiling);
    //return do_measurement(10, 10000, 10, num_samples);
    //return do_batch_measurement(5, 625, 1, num_samples);
}
