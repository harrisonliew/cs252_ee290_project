#!/usr/bin/env python3

'''
Associative Memory (AM) classifier for binary Hyperdimensional (HD) Comuputing
'''
import time
import sys
import torch as t


__author__ = "Michael Hersche"
__email__ = "herschmi@ethz.ch"
__date__ = "17.5.2019"


class am_classifier:

    def __init__(self, D, _encoder, device):
        '''

        Parameters
        ----------
        D : int
                HD dimension
        encode: hd_encoding class
                encoding class
        '''
        self._device = device
        self._n_classes = 1
        self._D = D

        self._encoder = _encoder

    def am_init(self, n_classes):
        '''
        Train AM

        Parameters
        ----------
        n_classes:
        '''
        self._n_classes = n_classes
        self._am = t.Tensor(self._n_classes, self._D).zero_().to(self._device)
        self._cnt = t.Tensor(self._n_classes).zero_().to(self._device)

        return

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
        X = t.from_numpy(X).type(t.int32).to(self._device)
        y = t.from_numpy(y).type(t.int32).to(self._device)

        n_samples = X.shape[0]
        # summation of training vectors
        for sample in range(n_samples):
            y_s = y[sample]
            if (y_s < self._n_classes) and (y_s >= 0):
                enc_vec, n_add = self._encoder.encode(X[sample].view(1, -1))
                self._am[y_s].add_(enc_vec)
                self._cnt[y_s] += n_add
            else:
                raise ValueError("Label is not in range of [{:},{:}], got {:}".format(
                    0, self._n_classes, y_s))

        return

    def am_threshold(self):
        '''
        Threshold AM
        '''
        # Thresholding
        for y_s in range(self._n_classes):
            # break ties randomly by adding random vector to
            if self._cnt[y_s] % 2 == 0:
                self._am[y_s].add_(t.randint(0, 2, (self._D,)).type(
                    t.FloatTensor).to(self._device))  # add random vector
                self._cnt[y_s] += 1
            self._am[y_s] = self._am[y_s] > int(self._cnt[y_s] / 2)
        return

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
        X = t.from_numpy(X).type(t.int32).to(self._device)
        n_samples = X.shape[0]
        dec_values = t.Tensor(n_samples).to(self._device)
        hd_dist = t.Tensor(n_samples, self._n_classes).zero_().to(self._device)

        for sample in range(n_samples):
            # encode samples
            self._encoder.encode(X[sample].view(1, -1))
            enc_vec, _ = self._encoder.clip()
            # calculate hamming distance for every class
            for y_s in range(self._n_classes):
                hd_dist[sample, y_s] = self.hamming_distance(
                    enc_vec, self._am[y_s])

            dec_values[sample] = t.argmin(hd_dist[sample])

        return dec_values.cpu().numpy()

    def hamming_distance(self, X1, X2):
        '''
        Calculate Hamming distance

        Parameters
        ----------
        X1: torch tensor, size = [_D,]
                Input 1
        X2: torch tensor, size = [_D,]
                Input 2

        Returns
        -------
        hdist : torch tensor, size = [1]
                normalized hamming distance
        '''
        D = X1.shape[0]

        cossim = t.mm((2 * X1 - 1).view(1, -1), (2 * X2 - 1).view(-1, 1))[0] / float(D)

        return (1 - cossim) / 2
