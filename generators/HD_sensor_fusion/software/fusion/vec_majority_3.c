#include <string.h>
#include "util.h"
#include "fusion_funcs.h"
#include "init.h"
#include "mems_early.h"
#include "vec_majority_3.h"

int main(){
    int dim = (bit_dim/8)*8;

    uint64_t inputs[3][dim];

    for(int i = 0; i < 3; i++) {
        memcpy(inputs[i], iM_GSR[i], sizeof(inputs[i]));
    }

    uint64_t cpu_result[dim], vec_result[dim];

    // CPU majority
    uint64_t start = read_cycles();

    for(int b = 0; b < dim; b++) {
        cpu_result[b] = (inputs[0][b] & inputs[1][b]) | (inputs[1][b] & inputs[2][b]) | (inputs[2][b] & inputs[0][b]);
    }

    printf("cpu cycles: %d\n", read_cycles() - start);

    // Hwacha majority
    //setStats(1);
    start = read_cycles();

    vec_majority_3_asm(dim, vec_result, inputs[0], inputs[1], inputs[2]);
    
    printf("hwacha cycles: %d\n", read_cycles() - start);
    //setStats(0);

    // Check the result
    for(int b = 0; b < 16; b++) {
        printf("cpu majority %d: %llx\n", b, cpu_result[b]);
        printf("vec majority %d: %llx\n", b, vec_result[b]);
    }
    return verifyuint64_t(dim, cpu_result, vec_result);
}
