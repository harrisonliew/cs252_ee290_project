#include <stdio.h>
#include <math.h>
#include <string.h>
#include "init.h"
#include "fusion_funcs.h"

#define ROUND(num) ((num - floorf(num) > 0.5f) ? ceilf(num) : floorf(num))

uint64_t read_cycles() {
    uint64_t cycles;
    asm volatile ("rdcycle %0" : "=r" (cycles));
    return cycles;
}

int min_dist_hamm(int distances[classes]){
/*************************************************************************
	DESCRIPTION: computes the minimum Hamming Distance.

	INPUTS:
		distances     : distances associated to each class
	OUTPUTS:
		min_index     : the class related to the minimum distance
**************************************************************************/
	int min = distances[0];
	int min_index = 0;

	for(int i = 1; i < classes; i++){

		if(min > distances[i]){

			min = distances[i];
			min_index = i;

		}

	}

	return min_index;
}



void hamming_dist(uint64_t q[bit_dim + 1], uint64_t aM[][bit_dim + 1], int sims[classes]){
/**************************************************************************
	DESCRIPTION: computes the Hamming Distance for each class.

	INPUTS:
		q        : query hypervector
		aM		 : Associative Memory matrix

	OUTPUTS:
		sims	 : Distances' vector
***************************************************************************/

	int r_tmp = 0;

	uint64_t tmp = 0;
	for(int i = 0; i < classes; i++){
		for(int j = 0; j < bit_dim + 1; j++){

			tmp = q[j] ^ aM[i][j];

			r_tmp += numberOfSetBits(tmp);
		}
		sims[i] = r_tmp;
		r_tmp = 0;
	}
}

void computeNgram(int channels, float buffer[], uint64_t iM[][bit_dim + 1], uint64_t projM_pos[][bit_dim + 1], uint64_t projM_neg[][bit_dim + 1], uint64_t query[bit_dim + 1]){
/*************************************************************************
	DESCRIPTION: computes the N-gram

	INPUTS:
		buffer   :  input data
		iM       :	Item Memory for the IDs of channels
		chAM     :  Continuous Item Memory for the values of a channel
	OUTPUTS:
		query    :  query hypervector
**************************************************************************/

    #if PROFILE == 1
        uint64_t cpu_start = read_cycles();
        uint64_t mux_start, mux_end, maj_start, maj_end;
    #endif

    memset( query, 0, (bit_dim+1)*sizeof(uint64_t));

    int num_mats = (channels+1)/64 + 1;

    uint64_t chHV[num_mats*64];

	//Spatial Encoder: captures the spatial information for a given time-aligned samples of channels
	for(int i = 0; i < bit_dim + 1; i++){

        #if PROFILE == 1
            mux_start = read_cycles();
        #endif

		for(int j = 0; j < channels; j++){

            // 0.0 is not checked (highly unlikely to be exactly 0)
            chHV[j] = iM[j][i] ^ (buffer[j] > 0.0 ? projM_pos[j][i] : projM_neg[j][i]);

		}
		//this is done in the Matlab for some reason???
		chHV[channels] = chHV[channels-1] ^ chHV[1];

        for(int j = channels+1; j < num_mats*64; j++){
            chHV[j] = 0;
        }

        #if PROFILE == 1
            mux_end = read_cycles();
        #endif

        //much faster componentwise majority: do some 64 bit matrix transposes
		//and then compute the number of 1's with the function numberOfSetBits(uint64_t).
        uint64_t t, mask;

        #if PROFILE == 1
            maj_start = read_cycles();
        #endif

        for (int n = 0; n < num_mats*64; n += 64) {
            //taken from Hacker's Delight. ~400 instructions.
            mask = 0x00000000FFFFFFFFULL;
            for (int j = 32; j != 0; j = j >> 1, mask = mask ^ (mask << j)) {
                for (int k = 0; k < 64; k = (k + j + 1) & ~j) {
                    t = (chHV[n+k] ^ (chHV[n+k+j] >> j)) & mask;
                    chHV[n+k] = chHV[n+k] ^ t;
                    chHV[n+k+j] = chHV[n+k+j] ^ (t << j);
                }
            }
        }
        
        #if PROFILE == 1
            maj_end = read_cycles();
        #endif

        //note row indices swapped with desired bit position after transpose
		for(int z = 63; z >= 0; z--){
            int num_set_bits = 0;
            for (int n = 63; n < num_mats*64; n += 64) {
                num_set_bits += numberOfSetBits(chHV[n-z]);
            }
            if (num_set_bits > channels/2) query[i] = query[i] | ( 1ULL << z ) ;
        }

	}

    #if PROFILE == 1
        printf("muxing cycles: %llu\n", mux_end - mux_start);
        printf("majority cycles: %llu\n", maj_end - maj_start);
        printf("spatial encoding cycles: %llu\n", read_cycles() - cpu_start);
    #endif

}

int numberOfSetBits(uint64_t i)
{
/*************************************************************************
	DESCRIPTION:   computes the number of 1's

	INPUTS:
		i        :  the i-th variable that composes the hypervector

**************************************************************************/

     i = i - ((i >> 1) & 0x5555555555555555);
     i = (i & 0x3333333333333333) + ((i >> 2) & 0x3333333333333333);
     return (((i + (i >> 4)) & 0x0F0F0F0F0F0F0F0F) * 0x0101010101010101) >> 56;
}
