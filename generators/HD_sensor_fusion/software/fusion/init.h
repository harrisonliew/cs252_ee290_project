#ifndef INIT_H_
#define INIT_H_

#include <stdint.h>
#include <math.h>

//dimension of the hypervectors (must be even)
#define dimension 10000
//number of classes to be classify
#define classes 2
//number of acquisition's channels
//and # of bits needed for popcounter
#define channels_GSR 32
#define cntr_bits_GSR 6
#define channels_ECG 77
#define cntr_bits_ECG 7
#define channels_EEG 105
#define cntr_bits_EEG 7
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
//number of bits to shift by in temporal encoder
//64b implementation will not do circular
#define temporal_shift 64
//profile cycles taken
#define PROFILE 0

#endif
