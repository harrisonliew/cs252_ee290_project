#! /bin/bash

for BLOCK_SIZE in 32 64 128 256
do
    for INPUT_CHUNKS in 1 2 4 8 16
    do
        echo "num threads per block: $BLOCK_SIZE, input chunk size: $INPUT_CHUNKS"

        # compile the code with the different define directives
        echo "compiling..."
        nvcc hd_encoder.cu hd_batch_encoder.cu hd_encoder_common.c hd_classifier.c test_inference.c -o test_inference_grid -O3 --use_fast_math -std=c++11 -Xcompiler '-fopenmp' --gpu-architecture=compute_53 --compiler-options -DNUM_THREADS_PER_BLOCK=$BLOCK_SIZE -DMAX_NUM_INPUT_CHUNKS=$INPUT_CHUNKS

        FILENAME="measurement_grid_$BLOCK_SIZE:$INPUT_CHUNKS.csv"
        echo "measuring into file $FILENAME"
        ./test_inference_grid -n 1 > $FILENAME
    done
done
