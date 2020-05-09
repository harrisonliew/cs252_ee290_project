## Hwacha computeNgram code

.text

.globl cntr_init_6b_v
.globl cntr_init_7b_v
.globl last_chHV_v
.globl proj_chHV_pos_v
.globl proj_chHV_neg_v
.globl set_chHV2_v
.globl mode_6b_v
.globl mode_7b_v
.globl query_6b_v
.globl query_7b_v

# init 6b counter
# vs1: 1
# vs2: 1's
# vs3: cntr_init
# vv4+: counter
.align 3
cntr_init_6b_v:
	vpset vp0

	vand vv4, vv4, vs0		# set cntr[0] to 0
	vslli vs4, vs1, 0		# 1 << 0
	vand vs4, vs3, vs4		# cntr_init & (1 << 0)
	vcmpeq vp1, vs4, vv4	# (cntr_init & (1 << 0)) == 0
@!vp1 vor vv4, vv4, vs2		# set cntr[0] to 1's

	vand vv5, vv5, vs0		# set cntr[1] to 0
	vslli vs4, vs1, 1		# 1 << 1
	vand vs4, vs3, vs4		# cntr_init & (1 << 1)
	vcmpeq vp1, vs4, vv5	# (cntr_init & (1 << 1)) == 0
@!vp1 vor vv5, vv5, vs2		# set cntr[1] to 1's

	vand vv6, vv6, vs0		# set cntr[2] to 0
	vslli vs4, vs1, 2		# 1 << 2
	vand vs4, vs3, vs4		# cntr_init & (1 << 2)
	vcmpeq vp1, vs4, vv6	# (cntr_init & (1 << 2)) == 0
@!vp1 vor vv6, vv6, vs2		# set cntr[2] to 1's

	vand vv7, vv7, vs0		# set cntr[3] to 0
	vslli vs4, vs1, 3		# 1 << 3
	vand vs4, vs3, vs4		# cntr_init & (1 << 3)
	vcmpeq vp1, vs4, vv7	# (cntr_init & (1 << 3)) == 0
@!vp1 vor vv7, vv7, vs2		# set cntr[3] to 1's

	vand vv8, vv8, vs0		# set cntr[4] to 0
	vslli vs4, vs1, 4		# 1 << 4
	vand vs4, vs3, vs4		# cntr_init & (1 << 4)
	vcmpeq vp1, vs4, vv8	# (cntr_init & (1 << 4)) == 0
@!vp1 vor vv8, vv8, vs2		# set cntr[4] to 1's

	vand vv9, vv9, vs0		# set cntr[5] to 0
	vslli vs4, vs1, 5		# 1 << 5
	vand vs4, vs3, vs4		# cntr_init & (1 << 5)
	vcmpeq vp1, vs4, vv9	# (cntr_init & (1 << 5)) == 0
@!vp1 vor vv9, vv9, vs2		# set cntr[5] to 1's
	
	vstop

# init 7b counter
# vs1: 1
# vs2: 1's
# vs3: cntr_init
# vv4+: counter
.align 3
cntr_init_7b_v:
	vpset vp0

	vand vv4, vv4, vs0		# set cntr[0] to 0
	vslli vs4, vs1, 0		# 1 << 0
	vand vs4, vs3, vs4		# cntr_init & (1 << 0)
	vcmpeq vp1, vs4, vv4	# (cntr_init & (1 << 0)) == 0
@!vp1 vor vv4, vv4, vs2		# set cntr[0] to 1's

	vand vv5, vv5, vs0		# set cntr[1] to 0
	vslli vs4, vs1, 1		# 1 << 1
	vand vs4, vs3, vs4		# cntr_init & (1 << 1)
	vcmpeq vp1, vs4, vv5	# (cntr_init & (1 << 1)) == 0
@!vp1 vor vv5, vv5, vs2		# set cntr[1] to 1's

	vand vv6, vv6, vs0		# set cntr[2] to 0
	vslli vs4, vs1, 2		# 1 << 2
	vand vs4, vs3, vs4		# cntr_init & (1 << 2)
	vcmpeq vp1, vs4, vv6	# (cntr_init & (1 << 2)) == 0
@!vp1 vor vv6, vv6, vs2		# set cntr[2] to 1's

	vand vv7, vv7, vs0		# set cntr[3] to 0
	vslli vs4, vs1, 3		# 1 << 3
	vand vs4, vs3, vs4		# cntr_init & (1 << 3)
	vcmpeq vp1, vs4, vv7	# (cntr_init & (1 << 3)) == 0
@!vp1 vor vv7, vv7, vs2		# set cntr[3] to 1's

	vand vv8, vv8, vs0		# set cntr[4] to 0
	vslli vs4, vs1, 4		# 1 << 4
	vand vs4, vs3, vs4		# cntr_init & (1 << 4)
	vcmpeq vp1, vs4, vv8	# (cntr_init & (1 << 4)) == 0
@!vp1 vor vv8, vv8, vs2		# set cntr[4] to 1's

	vand vv9, vv9, vs0		# set cntr[5] to 0
	vslli vs4, vs1, 5		# 1 << 5
	vand vs4, vs3, vs4		# cntr_init & (1 << 5)
	vcmpeq vp1, vs4, vv9	# (cntr_init & (1 << 5)) == 0
@!vp1 vor vv9, vv9, vs2		# set cntr[5] to 1's
	
	vand vv10, vv10, vs0	# set cntr[6] to 0
	vslli vs4, vs1, 6		# 1 << 6
	vand vs4, vs3, vs4		# cntr_init & (1 << 6)
	vcmpeq vp1, vs4, vv10	# (cntr_init & (1 << 6)) == 0
@!vp1 vor vv10, vv10, vs2	# set cntr[6] to 1's

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
# vv0: temp
# vv1: carry
# vv4+: counter bits (from LSB up)
.align 3
mode_6b_v:
	vpset vp0

	vand vv1, vv4, vv2		# carry = cntr[0] & chHV
	vxor vv4, vv4, vv2		# cntr[0] ^= chHV

	vand vv0, vv5, vv5		# temp = cntr[1]
	vxor vv5, vv5, vv1		# cntr[1] ^= carry
	vand vv1, vv1, vv0		# carry &= temp

	vand vv0, vv6, vv6		# temp = cntr[2]
	vxor vv6, vv6, vv1		# cntr[2] ^= carry
	vand vv1, vv1, vv0		# carry &= temp

	vand vv0, vv7, vv7		# temp = cntr[3]
	vxor vv7, vv7, vv1		# cntr[3] ^= carry
	vand vv1, vv1, vv0		# carry &= temp

	vand vv0, vv8, vv8		# temp = cntr[4]
	vxor vv8, vv8, vv1		# cntr[4] ^= carry
	vand vv1, vv1, vv0		# carry &= temp

	vand vv0, vv9, vv9		# temp = cntr[5]
	vxor vv9, vv9, vv1		# cntr[5] ^= carry

	vstop

# find the mode, 7b counter
# vv2: chHV
# vv4: temp
# vv5: carry
# vv4+: counter bits (from LSB up)
.align 3
mode_7b_v:
	vpset vp0

	vand vv1, vv4, vv2		# carry = cntr[0] & chHV
	vxor vv4, vv4, vv2		# cntr[0] ^= chHV

	vand vv0, vv5, vv5		# temp = cntr[1]
	vxor vv5, vv5, vv1		# cntr[1] ^= carry
	vand vv1, vv1, vv0		# carry &= temp

	vand vv0, vv6, vv6		# temp = cntr[2]
	vxor vv6, vv6, vv1		# cntr[2] ^= carry
	vand vv1, vv1, vv0		# carry &= temp

	vand vv0, vv7, vv7		# temp = cntr[3]
	vxor vv7, vv7, vv1		# cntr[3] ^= carry
	vand vv1, vv1, vv0		# carry &= temp

	vand vv0, vv8, vv8		# temp = cntr[4]
	vxor vv8, vv8, vv1		# cntr[4] ^= carry
	vand vv1, vv1, vv0		# carry &= temp

	vand vv0, vv9, vv9		# temp = cntr[5]
	vxor vv9, vv9, vv1		# cntr[5] ^= carry
	vand vv1, vv1, vv0		# carry &= temp

	vand vv0, vv10, vv10	# temp = cntr[6]
	vxor vv10, vv10, vv1	# cntr[6] ^= carry

	vstop

# store counter MSB to query (6b counter)
.align 3
query_6b_v:
	vpset vp0
	vsd vv9, va3
	vstop

# store counter MSB to query (7b counter)
.align 3
query_7b_v:
	vpset vp0
	vsd vv10, va3
	vstop
