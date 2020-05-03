#ifndef FUSION_FUNCS_H_
#define FUSION_FUNCS_H_
 
#include "init.h"

uint64_t read_cycles();
void hamming_dist(uint64_t q[bit_dim + 1], uint64_t aM[][bit_dim + 1], int sims[classes]);
int max_dist_hamm(int distances[classes]);
void computeNgram(int channels, float buffer[], uint64_t iM[][bit_dim + 1], uint64_t projM_pos[][bit_dim + 1], uint64_t projM_neg[][bit_dim + 1], uint64_t query[bit_dim + 1]);
int numberOfSetBits(uint64_t i);

#endif
