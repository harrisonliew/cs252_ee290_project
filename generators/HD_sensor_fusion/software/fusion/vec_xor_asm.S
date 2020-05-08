## Hwacha xor code

#include "vec-util.h"

.text
.align 2

.globl vec_xor_asm
.type  vec_xor_asm,@function

# assumes calling convention:
# a0 has int n (size)
# a1 has uint64* result
# a2 has uint64* x
# a3 has uint64* y
vec_xor_asm:
	li t0, VCFG(3, 0, 0, 1)
	vsetcfg t0
stripmine:
	vsetvl t0, a0 	#a0 is requested vec len, actual is placed in t0
	vmca va0, a2
	vmca va1, a3
	vmca va2, a1
	la t5, xor_v
	vf 0(t5)
	slli t1, t0, 3
	add a1, a1, t1
	add a2, a2, t1
	add a3, a3, t1
	sub a0, a0, t0
	bnez a0, stripmine
	fence
	ret

# vector thread asm
.align 3
xor_v:
	vpset vp0
	vld vv0, va0
	vld vv1, va1
	vxor vv2, vv0, vv1
	vsd vv2, va2
	vstop
