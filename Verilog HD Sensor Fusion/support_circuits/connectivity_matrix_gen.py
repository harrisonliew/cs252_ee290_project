import numpy as np

HV_DIMENSION = 1000;
MAX_BUNDLE_CYCLES = 80;

def HVbin(hv):
	dim = len(hv)
	return ''.join(['1' if hv[i] > 0 else '0' for i in range(dim-1,-1,-1)])

file = open('conn_mat_newline.txt', 'w')

for i in range(MAX_BUNDLE_CYCLES):
	hv = np.zeros(HV_DIMENSION)
	flips = round(HV_DIMENSION/(i+1))
	idx = np.random.permutation(HV_DIMENSION)
	hv[idx[0:flips]] = 1
	file.write(HVbin(hv) + '\n')