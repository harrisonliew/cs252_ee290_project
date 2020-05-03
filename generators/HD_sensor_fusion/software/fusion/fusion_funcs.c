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

		if(min < distances[i]){

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
    #endif

    memset( query, 0, (bit_dim+1)*sizeof(uint64_t));

    uint64_t chHV[channels+1];
    
    int num_majs = channels/64 + 1;
	uint64_t majority[num_majs];
    memset( majority, 0, num_majs*sizeof(uint64_t));
    int num_set_bits = 0;

	//Spatial Encoder: captures the spatial information for a given time-aligned samples of channels
	for(int i = 0; i < bit_dim + 1; i++){

		for(int j = 0; j < channels; j++){

            chHV[j] = iM[j][i] ^ (buffer[j] > 0.0 ? projM_pos[j][i] : projM_neg[j][i]);

		}
		//this is done in the Matlab for some reason???
		chHV[channels] = chHV[channels-1] ^ chHV[1];

		//componentwise majority: insert the value of the ith bit of each chHV row in the variable "majority"
		//and then compute the number of 1's with the function numberOfSetBits(uint64_t).
        //if(i == 0) printf("query before majority: %llx\n", query[i]);

		for(int z = 63; z >= 0; z--){

			for(int j = 0 ; j < channels + 1; j++){
                
                //if(i == 0 && z == 63) {
                //    printf("chHV: %llx\n", chHV[j]);
                //    printf("chHV shifted: %llx\n", (((chHV[j] & ( 1ULL << z)) >> z) << (j%64)));
                //}
				majority[j/64] = majority[j/64] | (((chHV[j] & ( 1ULL << z)) >> z) << (j%64));

			}
            for(int j = 0; j < num_majs; j++){
                num_set_bits += numberOfSetBits(majority[j]);
                //if(i == 0) {
                //    printf("majority[%d] for bit %d: %llx has %d set bits\n", j, z, majority[j], num_set_bits);
                //}
                majority[j] = 0;
            }

            //if(i == 0) printf("greater? %d\n", num_set_bits > channels/2);

			if (num_set_bits > channels/2) query[i] = query[i] | ( 1ULL << z ) ;

			num_set_bits = 0;
		}

	}

    #if PROFILE == 1
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
