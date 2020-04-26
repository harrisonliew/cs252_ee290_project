#!/bin/bash
#Copyright (c) 2018 ETH Zurich, Lukas Cavigelli

#Titan X: compute_52, TX1: compute_53, GTX1080Ti: compute_61, TX2: compute_62
nvccflags="-O3 --use_fast_math -std=c++11 -Xcompiler '-fopenmp' --gpu-architecture=compute_53"
linkflags="--shared --compiler-options -fPIC --linker-options --no-undefined"
nvcc hd_encoder.cu hd_batch_encoder.cu hd_encoder_common.c hd_classifier.c test_inference.c -o test_inference $nvccflags
nvcc hd_encoder.cu hd_batch_encoder.cu hd_encoder_common.c hd_classifier.c -o hdlib_$(uname -m).so $nvccflags $linkflags
