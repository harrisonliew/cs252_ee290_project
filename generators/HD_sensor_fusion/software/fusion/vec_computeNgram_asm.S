## Hwacha computeNgram code

#include "vec-util.h"

.text
.align 2

.globl cntr_init_6b_v
.globl cntr_init_7b_v
.globl last_chHV_v
.globl proj_chHV_pos_v
.globl proj_chHV_pos_v
.globl set_chHV2_v
.globl mode_6b_v
.globl mode_7b_v
.globl query_6b_v
.globl query_7b_v

# init 6b counter
# vs1: 1
# vs2: 1's
# vs3: cntr_init
# vv6+: counter
.align 3
cntr_init_6b_v:
	vpset vp0

	vand vv6, vs0, vs0		# set cntr[0] to 0
	vslli vs4, vs1, 0		# 1 << 0
	vand vs4, vs3, vs4		# cntr_init & (1 << 0)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 0)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv6, vs2, vs2		# set cntr[0] to 1's

	vand vv7, vs0, vs0		# set cntr[1] to 0
	vslli vs4, vs1, 1		# 1 << 1
	vand vs4, vs3, vs4		# cntr_init & (1 << 1)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 1)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv7, vs2, vs2		# set cntr[1] to 1's

	vand vv8, vs0, vs0		# set cntr[2] to 0
	vslli vs4, vs1, 2		# 1 << 2
	vand vs4, vs3, vs4		# cntr_init & (1 << 2)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 2)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv8, vs2, vs2		# set cntr[2] to 1's

	vand vv9, vs0, vs0		# set cntr[3] to 0
	vslli vs4, vs1, 3		# 1 << 3
	vand vs4, vs3, vs4		# cntr_init & (1 << 3)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 3)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv9, vs2, vs2		# set cntr[3] to 1's

	vand vv10, vs0, vs0		# set cntr[4] to 0
	vslli vs4, vs1, 4		# 1 << 4
	vand vs4, vs3, vs4		# cntr_init & (1 << 4)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 4)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv10, vs2, vs2		# set cntr[4] to 1's

	vand vv11, vs0, vs0		# set cntr[5] to 0
	vslli vs4, vs1, 5		# 1 << 5
	vand vs4, vs3, vs4		# cntr_init & (1 << 5)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 5)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv11, vs2, vs2		# set cntr[5] to 1's

	vstop

# init 7b counter
# vs1: 1
# vs2: 1's
# vs3: cntr_init
# vv6+: counter
.align 3
cntr_init_7b_v:
	vpset vp0

	vand vv6, vs0, vs0		# set cntr[0] to 0
	vslli vs4, vs1, 0		# 1 << 0
	vand vs4, vs3, vs4		# cntr_init & (1 << 0)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 0)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv6, vs2, vs2		# set cntr[0] to 1's

	vand vv7, vs0, vs0		# set cntr[1] to 0
	vslli vs4, vs1, 1		# 1 << 1
	vand vs4, vs3, vs4		# cntr_init & (1 << 1)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 1)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv7, vs2, vs2		# set cntr[1] to 1's

	vand vv8, vs0, vs0		# set cntr[2] to 0
	vslli vs4, vs1, 2		# 1 << 2
	vand vs4, vs3, vs4		# cntr_init & (1 << 2)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 2)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv8, vs2, vs2		# set cntr[2] to 1's

	vand vv9, vs0, vs0		# set cntr[3] to 0
	vslli vs4, vs1, 3		# 1 << 3
	vand vs4, vs3, vs4		# cntr_init & (1 << 3)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 3)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv9, vs2, vs2		# set cntr[3] to 1's

	vand vv10, vs0, vs0		# set cntr[4] to 0
	vslli vs4, vs1, 4		# 1 << 4
	vand vs4, vs3, vs4		# cntr_init & (1 << 4)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 4)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv10, vs2, vs2		# set cntr[4] to 1's

	vand vv11, vs0, vs0		# set cntr[5] to 0
	vslli vs4, vs1, 5		# 1 << 5
	vand vs4, vs3, vs4		# cntr_init & (1 << 5)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 5)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv11, vs2, vs2		# set cntr[5] to 1's

	vand vv12, vs0, vs0		# set cntr[6] to 0
	vslli vs4, vs1, 6		# 1 << 6
	vand vs4, vs3, vs4		# cntr_init & (1 << 6)
	vcmpeq vp1, vs4, vs0	# (cntr_init & (1 << 6)) == 0
	@!vp1 vcjal vs4, 8		# skip set to ones
	vand vv12, vs2, vs2		# set cntr[6] to 1's

	vstop

# chHV ^= chHV2
.align 3
last_chHV_v:
	vpset vp0
	vxor vv2, vv2, vv3
	vstop

# chHV = iM ^ projM_pos
.align 3
proj_chHV_pos_v:
	vpset vp0
	vld vv0, va0			# iM
	vld vv1, va1			# projM_pos 
	vxor vv2, vv0, vv1		# chHV = iM ^ projM_pos
	vstop

# chHV = iM ^ projM_neg
.align 3
proj_chHV_neg_v:
	vpset vp0
	vld vv0, va0			# iM
	vld vv1, va2			# projM_neg
	vxor vv2, vv0, vv1		# chHV = iM ^ projM_neg
	vstop

# chHV2 = chHV
.align 3
set_chHV2_v:
	vpset vp0
	vand vv3, vv2, vv2
	vstop

# find the mode, 6b counter
# vv2: chHV
# vv4: temp
# vv5: carry
# vv6+: counter bits (from LSB up)
.align 3
mode_6b_v:
	vpset vp0

	vand vv5, vv6, vv2		# carry = cntr[0] & chHV
	vxor vv6, vv6, vv2		# cntr[1] ^= chHV

	vand vv4, vv7, vv7		# temp = cntr[1]
	vxor vv7, vv7, vv5		# cntr[1] ^= carry
	vand vv5, vv5, vv4		# carry &= temp

	vand vv4, vv8, vv8		# temp = cntr[2]
	vxor vv8, vv8, vv5		# cntr[2] ^= carry
	vand vv5, vv5, vv4		# carry &= temp

	vand vv4, vv9, vv9		# temp = cntr[3]
	vxor vv9, vv9, vv5		# cntr[3] ^= carry
	vand vv5, vv5, vv4		# carry &= temp

	vand vv4, vv10, vv10	# temp = cntr[4]
	vxor vv10, vv10, vv5	# cntr[4] ^= carry
	vand vv5, vv5, vv4		# carry &= temp

	vand vv4, vv11, vv11	# temp = cntr[5]
	vxor vv11, vv11, vv5	# cntr[5] ^= carry

	vstop

# find the mode, 7b counter
# vv2: chHV
# vv4: temp
# vv5: carry
# vv6+: counter bits (from LSB up)
.align 3
mode_7b_v:
	vpset vp0

	vand vv5, vv6, vv2		# carry = cntr[0] & chHV
	vxor vv6, vv6, vv2		# cntr[1] ^= chHV

	vand vv4, vv7, vv7		# temp = cntr[1]
	vxor vv7, vv7, vv5		# cntr[1] ^= carry
	vand vv5, vv5, vv4		# carry &= temp

	vand vv4, vv8, vv8		# temp = cntr[2]
	vxor vv8, vv8, vv5		# cntr[2] ^= carry
	vand vv5, vv5, vv4		# carry &= temp

	vand vv4, vv9, vv9		# temp = cntr[3]
	vxor vv9, vv9, vv5		# cntr[3] ^= carry
	vand vv5, vv5, vv4		# carry &= temp

	vand vv4, vv10, vv10	# temp = cntr[4]
	vxor vv10, vv10, vv5	# cntr[4] ^= carry
	vand vv5, vv5, vv4		# carry &= temp

	vand vv4, vv11, vv11	# temp = cntr[5]
	vxor vv11, vv11, vv5	# cntr[5] ^= carry
	vand vv5, vv5, vv4		# carry &= temp

	vand vv4, vv12, vv12	# temp = cntr[5]
	vxor vv12, vv12, vv5	# cntr[5] ^= carry

	vstop

# store counter MSB to query (6b counter)
.align 3
query_6b_v:
	vpset vp0
	vsd vv11, va3
	vstop

# store counter MSB to query (7b counter)
.align 3
query_7b_v:
	vpset vp0
	vsd vv12, va3
	vstop
