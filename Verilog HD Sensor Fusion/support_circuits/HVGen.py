import numpy as np

HV_DIMENSION = 1000;
def HVbin(hv):
	dim = len(hv)
	return ''.join(['1' if hv[i] > 0 else '0' for i in range(dim-1,-1,-1)])

hv = np.random.choice([-1.0, 1.0], size=HV_DIMENSION)
file = open('iM_seed.txt', 'w')
file.write(HVbin(hv))