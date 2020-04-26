#!/usr/bin/env python3

'''
==============================================================================
Associative Memory (AM) classifier for binary Hyperdimensional (HD) Comuputing 
==============================================================================
'''
import time
import sys
import torch as t
import numpy as np
import cloudpickle as cpckl


from hd_encoder import sng_encoder
from am_classifier import am_classifier


__author__ = "Michael Hersche"
__email__ = "herschmi@ethz.ch"
__date__ = "17.5.2019"


class hd_classifier_ext():
    def __init__(self):

        import cffi
        import os
        import platform

        path = os.path.dirname(os.path.abspath(os.path.join(__file__, '..')))

        self._ffi = cffi.FFI()
        self._ffi.cdef('\n'.join([
            open(os.path.join(path, '_hd_encoder.h'), 'r').read(),
            open(os.path.join(path, '_hd_classifier.h'), 'r').read()
        ]))
        self._lib = self._ffi.dlopen(
            os.path.join(path, f'hdlib_{platform.machine()}.so')
        )

    def encode(self, X):
        # compute dimensionality
        n_samples, n_feat = X.shape

        self._lib.hd_encoder_encode(
            self._encoder,
            self._ffi.cast('const feature_t * const', X.data_ptr()),
            n_feat
        )

    def save(self, filename):
        self._lib.save(self._classifier, self._encoder, self._ffi.new("char[]", filename.encode('ascii')))

    def load(self, filename):
        # prepare classifier and encoder structs
        self._classifier = self._ffi.new('struct hd_classifier_t *')
        self._encoder = self._ffi.new('struct hd_encoder_t *')
        self._lib.hamming_distance_init()

        # load the data
        result = self._lib.load(self._classifier, self._encoder, self._ffi.new("char[]", filename.encode('ascii')))
        assert result == 0

        self._n_classes = self._classifier.n_class

        # prepare data for interaction
        # TODO this will likely be unnecesary in the future (see same lines in am_init)
        self._ngramm_sum_buffer = t.Tensor(self._encoder.n_blk * 32).type(t.int32).contiguous()
        self._encoder.ngramm_sum_buffer = self._ffi.cast('uint32_t * const', self._ngramm_sum_buffer.data_ptr())

    def am_init(self, D, nitem, n_classes, ngramm=3):
        # round D up to the nearest multiple of 32
        n_blk = int((D + 31) / 32)
        if D != n_blk * 32:
            print(f"Dimensionality given which is not a multiple of 32! Using {n_blk * 32} instead")
        D = n_blk * 32

        self._D = D

        # setup encoder
        self._encoder = self._ffi.new('struct hd_encoder_t *')
        self._lib.hd_encoder_init(self._encoder, n_blk, ngramm, nitem)
        self._lib.hamming_distance_init()
        # overwrite the encoder summing buffer with a torch tensor's pointer
        # this is so that the result can be communicated without copying
        # TODO this will likely be unnecesary in the future
        self._ngramm_sum_buffer = t.Tensor(D).type(t.int32).contiguous()
        self._encoder.ngramm_sum_buffer = self._ffi.cast('uint32_t * const', self._ngramm_sum_buffer.data_ptr())

        # setup classifier
        self._n_classes = n_classes
        self._class_vec_sum = t.Tensor(self._n_classes, self._D).type(t.int32).zero_()
        self._class_vec_cnt = t.Tensor(self._n_classes).type(t.int32).zero_()

        self._classifier = self._ffi.new('struct hd_classifier_t *')
        self._lib.hd_classifier_init(self._classifier, self._encoder.n_blk, n_classes, 0)
        self._classifier.class_vec_sum = self._ffi.cast('block_t *', self._class_vec_sum.data_ptr())
        self._classifier.class_vec_cnt = self._ffi.cast('int *', self._class_vec_cnt.data_ptr())

        # TODO: release memory and close self._lib

    def am_update(self, X, y):
        '''
        Update AM

        Parameters
        ----------
        X: numpy array, size = [n_samples, n_feat]
                Training samples
        y: numpy array, size = [n_samples]
                Training labels
        '''
        X = t.from_numpy(X).type(t.uint8)
        y = t.from_numpy(y).type(t.int32)

        n_samples = X.shape[0]
        # summation of training vectors
        for sample in range(n_samples):
            y_s = y[sample]
            if (y_s < self._n_classes) and (y_s >= 0):
                self.encode(X[sample].view(1, -1))
                self._class_vec_sum[y_s].add_(self._ngramm_sum_buffer)
                self._class_vec_cnt[y_s] += self._encoder.ngramm_sum_count
            else:
                raise ValueError("Label is not in range of [{:},{:}], got {:}".format(
                    0, self._n_classes, y_s))

        return

    def am_threshold(self):
        self._lib.hd_classifier_threshold(self._classifier)

    def fit(self, X, y):
        '''
        Train AM

        Parameters
        ----------
        X: numpy array, size = [n_samples, n_feat]
                Training samples
        y: numpy array, size = [n_samples]
                Training labels
        '''
        n_samples, _ = X.shape
        n_classes = t.max(y) + 1
        self.am_init(n_classes)

        # Train am
        self.am_update(X, y)

        # Thresholding
        self.am_threshold()

        return

    def predict(self, X):
        '''
        Prediction

        Parameters
        ----------
        X: torch tensor, size = [n_samples, _D]
                Input samples to predict.

        Returns
        -------
        dec_values : torch tensor, size = [n_sampels]
                predicted values.

        '''
        X = t.from_numpy(X).type(t.uint8)
        n_samples = X.shape[0]
        dec_values = t.Tensor(n_samples)

        for sample in range(n_samples):
            dec_values[sample] = self._lib.hd_classifier_predict(
                self._classifier,
                self._encoder,
                self._ffi.cast('const feature_t * const', X[sample].data_ptr()),
                X[sample].shape[0]
            )

        return dec_values.numpy()


class hd_classifier(am_classifier):

    def __init__(self, D=10000, encoding='sumNgramm', device='cpu', nitem=1, ngramm=3, name='test'):
        '''

        Parameters
        ----------
        D : int
                HD dimension
        encode: hd_encoding class
                encoding class
        '''

        self._name = name
        try:
            self.load()
        except:

            use_cuda = t.cuda.is_available()
            _device = t.device(device if use_cuda else "cpu")

            if encoding is 'sumNgramm':
                _encoder = sng_encoder(D, _device, nitem, ngramm)
            else:
                raise ValueError(f'{encoding} encoding not supported')

            super().__init__(D, _encoder, _device)

    def save(self):
        '''
        save class as self.name.txt
        '''
        file = open(self._name + '.txt', 'wb')
        cpckl.dump(self.__dict__, file)
        file.close()

    def load(self):
        '''
        try load self._name.txt
        '''
        file = open(self._name + '.txt', 'rb')

        self.__dict__ = cpckl.load(file)

    def save2binary_model(self):
        '''
        try load self._name_bin.npz
        '''

        _am = bin2int(self._am.cpu().type(t.LongTensor).numpy())
        _itemMemory = bin2int(
            self._encoder._itemMemory.cpu().type(t.LongTensor).numpy())

        np.save(self._name + 'bin', _n_classes=self._n_classes, _am=_am,
                _itemMemory=_itemMemory, _encoding=self._encoding)

        return


def bin2int(x):
    '''
    try load self._name_bin.npz

    Parameters
    ----------
    x : numpy array size = [u,v]
            input array binary
    Restults
    --------
    y : numpy array uint32 size = [u, ceil(v/32)]
    '''

    u, v = x.shape

    v_out = int(np.ceil(v / 32))
    y = np.zeros((u, v_out), dtype=np.uint32)

    for uidx in range(u):
        for vidx in range(v_out):
            for bidx in range(32):  # iterate through all bit index
                if vidx * 32 + bidx < v:
                    y[uidx, vidx] += x[uidx, vidx * 32 + bidx] << bidx

    return y
