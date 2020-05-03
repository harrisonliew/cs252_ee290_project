#ifndef INIT_H_
#define INIT_H_

#include <stdint.h>
#include <math.h>

//dimension of the hypervectors (must be even)
#define dimension 10000
//number of classes to be classify
#define classes 2
//number of acquisition's channels
#define channels_GSR 32
#define channels_ECG 77
#define channels_EEG 105
//dimension of the hypervectors after compression (dimension/32 rounded to the smallest integer)
#define bit_dim 156
//number of input samples
#define NUMBER_OF_INPUT_SAMPLES 380
//dimension of the N-grams (models for N = 3 are contained in data.h)
#define N 3
//CHANNELS_VOTING for the componentwise majority must be odd
#define CHANNELS_VOTING channels + 1
//sparsity of bipolar mapping
#define sparsity 0.7

#define PROFILE 0

#endif
