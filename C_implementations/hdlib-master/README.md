# Hyperdimensional Computing Library

### Prerequisites

- python3.6
- numpy
- pytorch4.0

The packages can be installed easily with conda and the _config.yml file: 
```
$ conda env create -f hdlib-env.yml -n hdlib-env
$ source activate hdlib-env 
```


## Author

* **Michael Hersche** - *Initial work* - [MHersche](https://github.com/MHersche)
* **Sebastian Kurella** - [skurella](https://github.com/skurella)
* **Tibor Schneider** - [tiborschneider](https://github.com/tiborschneider)

## Optimizations

- [x] CPU (bit packing, cicular buffers, hamming distance LUT)
- [x] GPU with global memory
- [x] GPU with shared memory
- [x] GPU with thread-local memory
- [x] GPU with thread-local memory and batches (does not work well)
- [ ] better batching
- [ ] memory coalescing
- [ ] memory bank alignment
- [ ] clipping and inference to GPU

## Measurements

- [x] CPU
- [ ] GPU with global memory
- [x] GPU with shared memory
- [x] GPU with thread-local memory
- [x] GPU with thread-local memory and batches (does not work well)

## Sources of parallelism

HD vector encoding of n-gramms is an embarrasingly parallel problem. There are two major ways to split the computations to parallelise them:
* HD vector can be split into arbitrarily short chunks to encode a single n-gramm in parallel
    * simply rotating the whole HD vector for feature slightly widens the dependency to neighbouring HD vector chunks
    * this can be prevented by rotating each feature within the chunk, as long as the chunk has no fewer elements than the n-gramm size
    * processing each chunk reads the HD vectors and inputs (constant) and exclusively writes to a part of the output
* input can be split into multiple chunks
    * input lenghts range from a couple tens or hundreds of features during inference to millions of features during training
    * each split is accompanied by an overlap of (n-gramm size - 1)

### No input-data-parallelism

```
| D pack | characters in input sample --> | Block |
|--------|--------------------------------|-------|
| 0      |                                |       |  ^
| :      |                                |       |  |
| :      | 128 threads                    | 0     | 128
| :      |                                |       |  |
| 127    |                                |       |  v
|--------|--------------------------------|-------|
| 128    |                                |       |
| :      | 128 threads                    | 1     |
| 255    |                                |       |
|--------|--------------------------------|-------|
| 256    |                                |       |
| :      | 128 threads                    | 2     |
| 312    |                                |       |
|--------|--------------------------------|-------|
          <------------- n_x ------------>
```

### `m`-input-data-parallelism

```
| D pack | characters in input sample --> | Block |
|--------|--------------------------------|-------|
| 0      |                |               |       |   ^
| :      |                |               |       |   |
| :      | 64 threads     | 64 threads    | 0     | 128 / m
| :      |                |               |       |   |
| 63     |                |               |       |   v
|--------|--------------------------------|-------|
| 64     |                |               |       |
| :      | 64 threads     | 64 threads    | 1     |
| 127    |                |               |       |
|--------|--------------------------------|-------|
| 128    |                |               |       |
| :      | 64 threads     | 64 threads    | 2     |
| 191    |                |               |       |
|--------|--------------------------------|-------|
| 192    |                |               |       |
| :      | 64 threads     | 64 threads    | 3     |
| 255    |                |               |       |
|--------|--------------------------------|-------|
| 256    |                |               |       |
| :      | 64 threads     | 64 threads    | 4     |
| 319    |                |               |       |
|--------|--------------------------------|-------|
          <--thread_n_x-->

          ^               ^
          |               |
       start_0         start_1
```

- Input dimension division `m`
- HD vector dimension D (packed) for each thread block: `128 / m`
- Input intervals
  - First two samples for each thread do not produce an output.
    We also need to overlap the range, so that no result is lost during this process.
    We divide the number of valid encoded ngramms (`ngramm_sum_count = n_x - (ngramm - 1)`) equally amongst the threads.
  - `thread_n_x`: Number of input features for each thread
    - for `threadIdx.y < m`: `floor((n_x - (ngramm-1)) / m)`
    - for `threadIdx.y = m`: `n_x - (m - 1) * floor(n_x / m)`
  - Start-index for threads with `threadIdx.y = y`:
    - `start_y = y * floor((n_x - (ngramm-1)) / m)`
  - End-index for threads with `threadIdx.y = y`:
    - `end_y = (y + 1) * floor((n_x - (ngramm-1)) / m) + (ngramm - 2)`
- Shared memory size (per block):
  - `item_lookup`: `(n_items * 128 / m) * 4 [bytes]`
  - `ngramm_sum_buffer`: `((32 * 128 / m) * m) * 4 [bytes] = (32 * 128) * 4 [bytes] `
  - Total: (with `n_items = 29`):
    - `sizeof(item_lookup) = 14336 / m [bytes]`
    - `sizeof(ngramm_sum_buffer) = 16384 [bytes]`
    - `sizeof(shared_memory) <= 30720 [bytes] < 65536 [bytes]`
