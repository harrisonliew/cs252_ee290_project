#include <string.h>
#include "util.h"
#include "fusion_funcs.h"
#include "init.h"
#include "mems_early.h"

#include "vec-util.h"

void vec_computeNgram(int channels, int cntr_bits, float buffer[], uint64_t iM[][bit_dim + 1], uint64_t projM_pos[][bit_dim + 1], uint64_t projM_neg[][bit_dim + 1], uint64_t query[bit_dim + 1]){

    uint64_t chHV, chHV2;

    int cntr_init = (1 << (cntr_bits-1)) - (channels+1)/2 - 1;
    uint64_t cntr[cntr_bits];
    uint64_t temp, carry;

    #if PROFILE == 1
    uint64_t start = read_cycles();

	//Spatial Encoder: captures the spatial information for a given time-aligned samples of channels
	for(int i = 0; i < bit_dim + 1; i++){

        //fastest componentwise majority: bit serial, word parallel
        //initialize counter to 2^(cntr_bits)/2 - channels/2
        //that way, the counter msb uint becomes the final query HV

        for(int n = 0; n < cntr_bits; n++) {
            if ((cntr_init  & (1 << n)) == 0) {
                cntr[n] = 0;
            } else {
                cntr[n] = 0xFFFFFFFFFFFFFFFFULL;
            }
        }

        for(int j = 0; j < channels+1; j++) {

            // calc chHV
            if(j == channels) {
                chHV ^= chHV2;
            } else {
                // slight hit if we don't check against 0 exactly also
                //chHV = buffer[j] == 0.0 ? iM[j][i] : (iM[j][i] ^ (buffer[j] > 0.0 ? projM_pos[j][i] : projM_neg[j][i]));
                chHV = iM[j][i] ^ (buffer[j] >= 0.0 ? projM_pos[j][i] : projM_neg[j][i]);
            }
            if(j == 1) chHV2 = chHV;

            // incremental popcount
            carry = cntr[0] & chHV;
            cntr[0] ^= chHV; 
            for(int n = 1; n < cntr_bits; n++) {
                temp = cntr[n];
                cntr[n] ^= carry;
                carry &= temp;
            }
        }
        
        query[i] = cntr[cntr_bits-1];

	}

    printf("cpu spatial encoding cycles: %llu\n", read_cycles() - start);
    start = read_cycles();
    #endif

    //Hwacha implementation

    // data registers:
    // vv0: iM
    // vv1: projM
    // vv2: chHV
    // vv3: chHV2
    // vv4: temp
    // vv5: carry
    // vv6+: counter bits (from LSB up)
    // addr registers:
    // va0: &iM
    // va1: &projM_pos
    // va2: &projM_neg
    // va3: query
    asm volatile ("vsetcfg %0" : : "r" (VCFG(cntr_bits + 6, 0, 2, 1)));

    // for counter
    uint64_t one = 0x1ULL;
    uint64_t ones = 0xFFFFFFFFFFFFFFFFULL;
    asm volatile ("vmcs vs1, %0" : : "r" (one));
    asm volatile ("vmcs vs2, %0" : : "r" (ones));
    asm volatile ("vmcs vs3, %0" : : "r" (cntr_init));
    
    void * cntr_init_6b_addr;
    void * cntr_init_7b_addr;
    void * last_chHV_addr;
    void * proj_chHV_pos_addr;
    void * proj_chHV_neg_addr;
    void * set_chHV2_addr;
    void * mode_6b_addr;
    void * mode_7b_addr;
    void * query_6b_addr;
    void * query_7b_addr;

    for(int i = 0; i < bit_dim + 1; ) {

        printf("i: %d\n", i);

        // loop setup
        int consumed;
        asm volatile ("vsetvl %0, %1" : "=r" (consumed) : "r" (i));

        // init cntr
        switch(cntr_bits) {
            case 6:
                // call 6b cntr_init vf block
                asm volatile ("la %0, cntr_init_6b_v" : "=r" (cntr_init_6b_addr));
                asm volatile ("vf 0(%0)" : : "r" (cntr_init_6b_addr));
                break;
            case 7:
                // call 7b cntr_init vf block
                asm volatile ("la %0, cntr_init_7b_v" : "=r" (cntr_init_7b_addr));
                asm volatile ("vf 0(%0)" : : "r" (cntr_init_7b_addr));
                break;
            default:
                printf("only 6 or 7 counter bits supported!");
                return;
        }

        // compute chHV & mode
        for(int j = 0; j < channels + 1; j++) {
            asm volatile ("vmca va0, %0" : : "r" (&iM[j][i]));
            asm volatile ("vmca va1, %0" : : "r" (&projM_pos[j][i]));
            asm volatile ("vmca va2, %0" : : "r" (&projM_neg[j][i]));

            if(j == channels) {
                // call vf block for chHV ^= chHV2;
                asm volatile ("la %0, last_chHV_v" : "=r" (last_chHV_addr));
                asm volatile ("vf 0(%0)" : : "r" (last_chHV_addr));
            } else {
                // call vf block for projection
                if(buffer[j] >= 0.0) {
                    asm volatile ("la %0, proj_chHV_pos_v" : "=r" (proj_chHV_pos_addr));
                    asm volatile ("vf 0(%0)" : : "r" (proj_chHV_pos_addr));
                } else {
                    asm volatile ("la %0, proj_chHV_neg_v" : "=r" (proj_chHV_neg_addr));
                    asm volatile ("vf 0(%0)" : : "r" (proj_chHV_neg_addr));
                }
            }
            if(j == 1) {
                // call vf block for chHV2 = chHV;
                asm volatile ("la %0, set_chHV2_v" : "=r" (set_chHV2_addr));
                asm volatile ("vf 0(%0)" : : "r" (set_chHV2_addr));
            }

            switch(cntr_bits) {
                case 6:
                    // call 6b mode vf block
                    asm volatile ("la %0, mode_6b_v" : "=r" (mode_6b_addr));
                    asm volatile ("vf 0(%0)" : : "r" (mode_6b_addr));
                    break;
                case 7:
                    // call 7b mode vf block
                    asm volatile ("la %0, mode_7b_v" : "=r" (mode_7b_addr));
                    asm volatile ("vf 0(%0)" : : "r" (mode_7b_addr));
                    break;
                default:
                    return;
            }
        }

        asm volatile ("vmca va3, %0" : : "r" (&query[i]));
        switch(cntr_bits) {
            case 6:
                // call vf block to store 6th bit
                asm volatile ("la %0, query_6b_v" : "=r" (query_6b_addr));
                asm volatile ("vf 0(%0)" : : "r" (query_6b_addr));
                break;
            case 7:
                // call vf block to store 7th bit
                asm volatile ("la %0, query_7b_v" : "=r" (query_7b_addr));
                asm volatile ("vf 0(%0)" : : "r" (query_7b_addr));
                break;
            default:
                return;
        }

        i += consumed;
    }

    asm volatile ("fence");

    #if PROFILE==1
    printf("hwacha spatial encoding cycles: %llu\n", read_cycles() - start);
    #endif
}
