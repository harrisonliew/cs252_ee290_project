#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "fusion_funcs.h"
#include "init.h"
//the data.h and mems_<early/late>.h file can be created directly in MATLAB (after the simulation)
//using the function "data_file_creator.m"
#include "data.h"
#include "mems_early.h"
//#include "mems_late.h"

int main(){
 
    float buffer[channels_GSR];
	uint64_t q[bit_dim + 1];
          
	//Spatial Encoder
    #if PROFILE == 1
        uint64_t spatial_start = read_cycles();
    #endif

    //spatially encode first sample
    memcpy(buffer, TEST_SET_GSR[0], sizeof(TEST_SET_GSR[0]));
    computeNgram(channels_GSR, cntr_bits_GSR, buffer, iM_GSR, projM_pos_GSR, projM_neg_GSR, q);

    #if PROFILE == 1
        printf("Spatial cycles: %llu\n", read_cycles() - spatial_start);
    #endif

    return 0; 
}
