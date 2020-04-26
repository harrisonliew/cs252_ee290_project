"""
plot hdlib data
"""

import sys
import numpy as np
import matplotlib.pyplot as plt

for arg in sys.argv[1:]:
    print(f'plotting {arg}')
    data = np.genfromtxt(arg, delimiter=",")
    plt.scatter(data[:, 0], data[:, 1])

plt.show()
