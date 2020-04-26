#!/usr/bin/env python3

'''

=================================================
Language Classification Using Ngramm-Sum Encoding
=================================================
'''

__author__ = "Michael Hersche"
__email__ = "herschmi@ethz.ch"
__date__ = "20.5.2019"

import argparse
import sys
import time
import numpy as np

sys.path.append('../../pyhdlib/')

from load_data import load_data
from hd_classifier import hd_classifier_ext, bin2int

# data loader
dl = load_data()

# init HD classifier
ngramm = 3
encoding = "sumNgramm"
nitem = dl._nitem
D = 10000
device = 'cuda:0'


name = 'data/models/' + str(ngramm) + 'gramm'


#hd = hd_classifier(D, encoding, device, nitem, ngramm, name=name)
hd = hd_classifier_ext()

def plot_language_class(training, testing, store):
    ########################## training ########################################

    if training:
        #hd.am_init(dl._n_labels)
        hd.am_init(D, nitem, dl._n_labels, ngramm)
        label = 0

        while (label != -1):
            # load data
            data, label = dl.get_train_item()

            if label == -1:
                break

            print("train class {:} ".format(dl._langLabels[np.asscalar(label)]))
            # train am
            hd.am_update(data, label)

        hd.am_threshold()
        #hd.save()
        hd.save(name)
    else:
        #hd.load()
        hd.load(name)

    ########################## testing ########################################

    if testing:
        err = 0
        i = 0
        n_test = dl.get_test_item_num()
        n_test_ran = 0
        y = 0

        print('testing...')
        while (True):
            # get data and push to gpu
            X, y = dl.get_test_item()

            if y == -1:
                break

            y_hat = hd.predict(X)

            curr_err = np.sum(y_hat != y)
            n_test_ran += len(y_hat)
            err += curr_err

            print(f'{n_test_ran/(n_test-1):-3.1%}, accuracy: {1-err/n_test_ran:.4}', end='\r')

        print('done, accuracy: {:.4}'.format(1 - err / n_test_ran))

    if store:
        # store test data as binary files
        dl.store_test_data('data/binary_test_data')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='natural language classifier')

    parser.set_defaults(train=True, test=True, store=False)
    parser.add_argument('--no-training', '-f', dest='train', action='store_false', default=True)
    parser.add_argument('--no-testing', '-p', dest='test', action='store_false', default=True)
    parser.add_argument('--save-intermediate-test-data', '-s', dest='store', action='store_true', default=False, help='convert test data to an intermediate format')

    args = parser.parse_args()

    plot_language_class(args.train, args.test, args.store)
