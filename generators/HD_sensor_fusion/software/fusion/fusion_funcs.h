#ifndef FUSION_FUNCS_H_
#define FUSION_FUNCS_H_
 
#include "init.h"

uint64_t read_cycles();
void hamming_dist(uint64_t q[bit_dim + 1], uint64_t aM[][bit_dim + 1], int sims[classes]);
int min_dist_hamm(int distances[classes]);
void computeNgram(int channels, int cntr_bits, float buffer[], uint64_t iM[][bit_dim + 1], uint64_t projM_pos[][bit_dim + 1], uint64_t projM_neg[][bit_dim + 1], uint64_t query[bit_dim + 1]);
int numberOfSetBits(uint64_t i);

static int verifyuint64_t(int n, uint64_t* test, uint64_t* verify) {
    int i;
    // Unrolled for faster verification
    for (i = 0; i < n/2*2; i+=2) {
        uint64_t t0 = test[i], t1 = test[i+1];
        uint64_t v0 = verify[i], v1 = verify[i+1];
        int eq1 = t0 == v0, eq2 = t1 == v1;
        if (!(eq1 & eq2)) return i+1+eq1;
    }
    if (n % 2 != 0 && test[n-1] != verify[n-1])
        return n;
    return 0;
}

#endif
