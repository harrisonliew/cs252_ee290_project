#!/usr/bin/env python3

'''

=========================================
Language Classification Data Loader Class
=========================================
'''

__author__ = "Michael Hersche"
__email__ = "herschmi@ethz.ch"
__date__ = "20.5.2019"


import time
import sys
import glob
import numpy as np
import pickle


data_dir = 'data/'


class load_data:

    def __init__(self):
        '''
        Update AM

        Return
        ----------
        n_char: int
                number of characters in text
        '''
        # training files
        self._langLabels = {0: 'afr', 1: 'bul', 2: 'ces', 3: 'dan', 4: 'nld',
                            5: 'deu', 6: 'eng', 7: 'est', 8: 'fin', 9: 'fra', 10: 'ell', 11: 'hun',
                            12: 'ita', 13: 'lav', 14: 'lit', 15: 'pol', 16: 'por', 17: 'ron',
                            18: 'slk', 19: 'slv', 20: 'spa', 21: 'swe'}
        _test_langLabels = {0: 'af', 1: 'bg', 2: 'cs', 3: 'da', 4: 'nl',
                            5: 'de', 6: 'en', 7: 'et', 8: 'fi', 9: 'fr', 10: 'el', 11: 'hu',
                            12: 'it', 13: 'lv', 14: 'lt', 15: 'pl', 16: 'pt', 17: 'ro',
                            18: 'sk', 19: 'sl', 20: 'es', 21: 'sv'}
        self._test_langLabels = dict(
            [(value, key) for key, value in _test_langLabels.items()])

        self._n_labels = len(self._langLabels)
        self._tr_idx = 0
        self._tr_path = data_dir + 'training_texts/'

        # generate character to index file
        try:
            pickle_in = open(data_dir + "models/charidx.pickle", "rb")
            self._chardict = pickle.load(pickle_in)

        except:
            print("Generate new char 2 index ")
            self._genchar2idx()
            pickle_out = open(data_dir + "models/charidx.pickle", "wb")
            pickle.dump(self._chardict, pickle_out)
            pickle_out.close()

        self._nitem = len(self._chardict)
        # testing files
        self._testList = glob.glob(data_dir + "testing_texts/*.txt")
        self._n_test_labels = len(self._testList)
        self._test_idx = 0

        return

    def _genchar2idx(self):
        '''
        Generate character to index mapping from training files
        '''

        self._chardict = dict()
        # go over all training files
        for tr_idx in range(self._n_labels):
            fname = self._tr_path + self._langLabels[tr_idx] + '.txt'
            F = open(fname)
            string = F.read()
            # sweep through whole dict and update
            for char in string:
                if not (char in self._chardict):
                    self._chardict[char] = len(self._chardict)

            F.close()

    def _str2idx(self, string):
        '''
        Convert string to array of indexes
        Return
        ----------
        X: numpy array size =[nstr,]
        '''
        nstr = len(string)
        X = np.empty((nstr,), dtype=np.uint8)
        for idx in range(nstr):
            if string[idx] in self._chardict:
                X[idx] = self._chardict[string[idx]]
            else:
                X[idx] = self._chardict[' ']

        return X

    def get_train_item(self):
        '''
        Load next training item
        Return
        ----------
        char_array: np array of characters
                Text
        label: int
                Label of text used in training
        '''

        if self._tr_idx < self._n_labels:
            fname = self._tr_path + self._langLabels[self._tr_idx] + '.txt'
            F = open(fname)
            string = F.read()
            char_array = self._str2idx(string)
            F.close()
            self._tr_idx += 1
        else:
            self._tr_idx = 0
            char_array = np.array((2,), dtype=np.uint8)
        return char_array.reshape(1, -1), np.array(self._tr_idx - 1).reshape(1)

    def get_test_item_num(self):
        return self._n_test_labels
        
    def get_test_item(self):
        if self._test_idx < self._n_test_labels:
            fname = self._testList[self._test_idx]
            last_slash = fname.rfind('/')
            label = self._test_langLabels[fname[last_slash + 1:last_slash + 3]]

            F = open(fname)
            string = F.read()
            char_array = self._str2idx(string)
            F.close()
            self._test_idx += 1

        else:
            char_array = np.array([], dtype=np.uint8)
            label = -1

        return char_array.reshape(1, -1), np.array(label).reshape(1)

    def store_sample(self, filename, X, y):
        import struct
        assert X.shape[0] == 1
        with open(filename, "wb") as _f:
            # wirte label
            _f.write(struct.pack("B", y.item()))
            # write shape
            _f.write(struct.pack("<i", X.shape[1]))
            # write data
            for feature in X[0]:
                _f.write(struct.pack("B", feature.item()))

    def store_test_data(self, foldername, num=0):

        import os

        # make sure that the folder exists
        if not os.path.exists(foldername):
            os.makedirs(foldername)

        # default num means everything
        if num == 0:
            num = self._n_test_labels

        for i in range(num):
            print(f'storing test data... {i/(num-1):4.0%}', end='\r')
            X, y = self.get_test_item()

            if y == -1:
                break

            filename = os.path.join(foldername, f"sample_{i:05d}")
            self.store_sample(filename, X, y)

        print()

        # store one training sample for measurement
        print('storing measurement sample')
        X, y = self.get_train_item()
        if y != -1:
            filename = os.path.join(foldername, f"measurement_sample")
            self.store_sample(filename, X, y)
