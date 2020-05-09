#include <string.h>
#include "util.h"
#include "fusion_funcs.h"
#include "init.h"
#include "mems_early.h"
#include "vec_majority_3.h"

int main(){
    uint64_t inputs[3][bit_dim];

    for(int i = 0; i < 3; i++) {
        memcpy(inputs[i], iM_GSR[i], sizeof(inputs[i]));
    }

    uint64_t cpu_result[bit_dim], vec_result[bit_dim];

    // CPU majority
    uint64_t start = read_cycles();

    for(int b = 0; b < bit_dim; b++) {
        cpu_result[b] = (inputs[0][b] & inputs[1][b]) | (inputs[1][b] & inputs[2][b]) | (inputs[2][b] & inputs[0][b]);
    }

    printf("cpu cycles: %d\n", read_cycles() - start);

    // Hwacha majority
    start = read_cycles();

    vec_majority_3_asm(bit_dim, vec_result, inputs[0], inputs[1], inputs[2]);
    
    printf("hwacha cycles: %d\n", read_cycles() - start);

    // Check the result
    return verifyuint64_t(bit_dim, cpu_result, vec_result);
}