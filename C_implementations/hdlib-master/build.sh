#!/bin/bash
cc hd_encoder.c hd_batch_encoder.c hd_encoder_common.c hd_classifier.c --std=gnu99 -O3 --shared -fPIC -o hdlib_$(uname -m).so
cc hd_encoder.c hd_batch_encoder.c hd_encoder_common.c hd_classifier.c --std=gnu99 -O3 test_inference.c -o test_inference
