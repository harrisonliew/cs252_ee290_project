import numpy as np

HV_DIMENSION = 1000;
def HVbin(hv):
	dim = len(hv)
	return ''.join(['1' if hv[i] > 0 else '0' for i in range(dim-1,-1,-1)])

hv = np.zeros(HV_DIMENSION)
idx = np.random.permutation(HV_DIMENSION)
hv[idx[0:round(HV_DIMENSION/2)]] = 1
file = open('merge_bits.txt', 'w')
file.write(HVbin(hv))