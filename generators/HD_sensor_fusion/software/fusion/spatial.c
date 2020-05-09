#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "util.h"
#include "fusion_funcs.h"
#include "init.h"
//the data.h and mems_<early/late>.h file can be created directly in MATLAB (after the simulation)
//using the function "data_file_creator.m"
#include "data.h"
#include "mems_early.h"
//#include "mems_late.h"

int main(){
 
    float buffer[channels_ECG];
	uint64_t q_cpu[bit_dim + 1], q_hwacha[bit_dim+1];
          
	//CPU Spatial Encoder
    #if PROFILE == 1
        uint64_t spatial_start = read_cycles();

    memcpy(buffer, TEST_SET_ECG[0], sizeof(TEST_SET_ECG[0]));
    computeNgram(channels_ECG, cntr_bits_ECG, buffer, iM_ECG, projM_pos_ECG, projM_neg_ECG, q_cpu);

        printf("CPU spatial cycles: %llu\n", read_cycles() - spatial_start);
        spatial_start = read_cycles();
    #endif

	//Hwacha Spatial Encoder
    vec_computeNgram(channels_ECG, cntr_bits_ECG, buffer, iM_ECG, projM_pos_ECG, projM_neg_ECG, q_hwacha);

    #if PROFILE == 1
        printf("Hwacha spatial cycles: %llu\n" , read_cycles() - spatial_start);
        for(int i = 0; i < bit_dim+1; i++) {
            printf("cpu: %llx   hwacha: %llx\n", q_cpu[i], q_hwacha[i]);
        }
        printf("Verify: %d\n", verifyuint64_t(bit_dim+1, q_cpu, q_hwacha));
    #endif

    return 0; 
}
