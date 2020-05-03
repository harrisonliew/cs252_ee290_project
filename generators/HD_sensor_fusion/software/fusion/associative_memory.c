#include "associative_memory.h"
#include "fusion_funcs.h"


int associative_memory_64bit(uint64_t q_64[bit_dim + 1], uint64_t aM_64[][bit_dim + 1]){
/*************************************************************************
	DESCRIPTION:  tests the accuracy based on input testing queries

	INPUTS:
		q_64        : query hypervector
		aM_64		: Trained associative memory
	OUYTPUTS:
		class       : classification result
**************************************************************************/

	int sims[classes] = {0};
	int class;


	//Computes Hamming Distances
	hamming_dist(q_64, aM_64, sims);
 
	//Classification with Hamming Metri
	class = max_dist_hamm(sims);

 

	return class;

}


