## Hwacha 3 input majority code

#include "vec-util.h"

.text
.align 2

.globl vec_majority_3_asm
.type  vec_majority_3_asm,@function

# assumes calling convention:
# a0 has int n (size)
# a1 has uint64* result
# a2 has uint64* x
# a3 has uint64* y
# a4 has uint64* z
vec_majority_3_asm:
	li t0, VCFG(6, 0, 0, 1)
	vsetcfg t0
stripmine:
	vsetvl t0, a0 	#a0 is requested vec len, actual is placed in t0
	vmca va0, a2
	vmca va1, a3
	vmca va2, a4
	vmca va3, a1
	la t5, majority_3_v
	vf 0(t5)
	slli t1, t0, 3
	add a1, a1, t1
	add a2, a2, t1
	add a3, a3, t1
	add a4, a4, t1
	sub a0, a0, t0
	bnez a0, stripmine
	fence
	ret

# vector thread asm
.align 3
majority_3_v:
	vpset vp0
	vld vv0, va0
	vld vv1, va1
	vld vv2, va2
	vand vv3, vv0, vv1
	vand vv4, vv1, vv2
	vand vv5, vv2, vv0
	vor vv3, vv3, vv4
	vor vv3, vv3, vv5
	vsd vv3, va3
	vstop
