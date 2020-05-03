#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "associative_memory.h"
#include "fusion_funcs.h"
#include "init.h"
//the data.h and mems_<early/late>.h file can be created directly in MATLAB (after the simulation)
//using the function "data_file_creator.m"
#include "data.h"
#include "mems_early.h"
//#include "mems_late.h"

float buffer_GSR[channels_GSR];
float buffer_ECG[channels_ECG];
float buffer_EEG[channels_EEG];

int main(){
 
          
	uint64_t overflow = 0;
	uint64_t old_overflow = 0;
	uint64_t mask = 1;
	uint64_t q[bit_dim + 1], q_GSR[bit_dim + 1], q_ECG[bit_dim+1], q_EEG[bit_dim+1] = {0};
	uint64_t q_N[bit_dim + 1], q_N_GSR[bit_dim + 1], q_N_ECG[bit_dim+1], q_N_EEG[bit_dim+1] = {0};
	int class[NUMBER_OF_INPUT_SAMPLES-N+1];

    int numTests = 0;
    int correct = 0;

	for(int ix = 0; ix < NUMBER_OF_INPUT_SAMPLES-N+1; ix++){
        numTests++;

        #if PROFILE == 1
            uint64_t cpu_start = read_cycles();
        #endif

		for(int z = 0; z < N; z++){
 
            memcpy(buffer_GSR, TEST_SET_GSR[ix+z], sizeof(buffer_GSR));
            memcpy(buffer_ECG, TEST_SET_ECG[ix+z], sizeof(buffer_ECG));
            memcpy(buffer_EEG, TEST_SET_EEG[ix+z], sizeof(buffer_EEG));

			//Spatial and Temporal Encoder: computes the N-gram.
			//N.B. if N = 1 we don't have the Temporal Encoder but only the Spatial Encoder.
			if (z == 0) {
                computeNgram(channels_GSR, buffer_GSR, iM_GSR, projM_pos_GSR, projM_neg_GSR, q_GSR);
                //printf("q_GSR: %llx\n", q_GSR[0]);
                computeNgram(channels_ECG, buffer_ECG, iM_ECG, projM_pos_ECG, projM_neg_ECG, q_ECG);
                //printf("q_ECG: %llx\n", q_ECG[0]);
                computeNgram(channels_EEG, buffer_EEG, iM_EEG, projM_pos_EEG, projM_neg_EEG, q_EEG);
                //printf("q_EEG: %llx\n", q_EEG[0]);
                //majority
                for (int b = 0; b < bit_dim + 1; b++) {
                    q[b] = (q_GSR[b] & q_ECG[b]) | (q_ECG[b] & q_EEG[b]) | (q_EEG[b] & q_GSR[b]);
                }
            } else {
 
                computeNgram(channels_GSR, buffer_GSR, iM_GSR, projM_pos_GSR, projM_neg_GSR, q_N_GSR);
                computeNgram(channels_ECG, buffer_ECG, iM_ECG, projM_pos_ECG, projM_neg_ECG, q_N_ECG);
                computeNgram(channels_EEG, buffer_EEG, iM_EEG, projM_pos_EEG, projM_neg_EEG, q_N_EEG);
                //majority
                for (int b = 0; b < bit_dim + 1; b++) {
                    q_N[b] = (q_N_GSR[b] & q_N_ECG[b]) | (q_N_ECG[b] & q_N_EEG[b]) | (q_N_EEG[b] & q_N_GSR[b]);
                }
 
				//Here the hypervector q is shifted by 1 position as permutation,
				//before performing the componentwise XOR operation with the new query (q_N).
				overflow = q[0] & mask;

				for(int i = 1; i < bit_dim; i++){

					old_overflow = overflow;
					overflow = q[i] & mask;
					q[i] = (q[i] >> 1) | (old_overflow << (64 - 1));
					q[i] = q_N[i] ^ q[i];

				}

				old_overflow = overflow;
				overflow = (q[bit_dim] >> 16) & mask;
				q[bit_dim] = (q[bit_dim] >> 1) | (old_overflow << (64 - 1));
				q[bit_dim] = q_N[bit_dim] ^ q[bit_dim];

				q[0] = (q[0] >> 1) | (overflow << (64 - 1));
				q[0] = q_N[0] ^ q[0];


			}
 
		}
	
        #if PROFILE == 1
            printf("Spatial + Temporal cycles: %llu\n", read_cycles() - cpu_start);

            cpu_start = read_cycles();
        #endif
 
	    //classifies the new N-gram through the Associative Memory matrix.
		if (N == 1)
			class[ix] = associative_memory_64bit(q, aM);
		else
			class[ix] = associative_memory_64bit(q, aM);

        if (class[ix] == labels[ix]) correct++;

        #if PROFILE == 1
            printf("Assoc. Mem. cycles: %llu\n", read_cycles() - cpu_start);
        #endif
	
 	    printf("Sample %d predicted class: %d\n", ix, class[ix]);

	}

    // accuracy count
    printf("Correct: %d out of %d\n", correct, numTests); 
    printf("Accuracy: %.4f\n", (float)correct/(float)numTests);

    return 0; 
}

