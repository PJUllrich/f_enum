Generating 1000000 random integers...
Data ready: 1000000 element list, 8000000 byte binary


*** sort (1000000 integers) ***

Name                            ips        average  deviation         median         99th %
FEnum.sort/1 (binary)         90.20       11.09 ms     ±1.09%       11.06 ms       11.50 ms
FEnum.sort/1 (list)           51.63       19.37 ms     ±8.81%       18.26 ms       23.64 ms
Enum.sort/1                    9.08      110.09 ms    ±10.27%      108.25 ms      140.55 ms

Comparison:
FEnum.sort/1 (binary)         90.20
FEnum.sort/1 (list)           51.63 - 1.75x slower +8.28 ms
Enum.sort/1                    9.08 - 9.93x slower +99.00 ms

Memory usage statistics:

Name                     Memory usage
FEnum.sort/1 (binary)            64 B
FEnum.sort/1 (list)               0 B - 0.00x memory usage -64 B
Enum.sort/1               215880224 B - 3373128.50x memory usage +215880160 B

**All measurements for memory usage were the same**

*** sort :desc (1000000 integers) ***

Name                               ips        average  deviation         median         99th %
FEnum.sort/desc (binary)         90.04       11.11 ms     ±0.50%       11.09 ms       11.29 ms
FEnum.sort/desc (list)           51.72       19.33 ms     ±8.87%       18.23 ms       23.83 ms
Enum.sort/desc                    9.01      111.04 ms    ±18.68%      105.44 ms      168.34 ms

Comparison:
FEnum.sort/desc (binary)         90.04
FEnum.sort/desc (list)           51.72 - 1.74x slower +8.23 ms
Enum.sort/desc                    9.01 - 10.00x slower +99.94 ms

Memory usage statistics:

Name                        Memory usage
FEnum.sort/desc (binary)            64 B
FEnum.sort/desc (list)               0 B - 0.00x memory usage -64 B
Enum.sort/desc               231211408 B - 3612678.25x memory usage +231211344 B

**All measurements for memory usage were the same**

*** reverse (1000000 integers) ***

Name                               ips        average  deviation         median         99th %
FEnum.reverse/1 (binary)       2420.83        0.41 ms     ±3.64%        0.41 ms        0.46 ms
Enum.reverse/1                  900.98        1.11 ms    ±58.18%        1.01 ms        4.82 ms
FEnum.reverse/1 (list)          882.30        1.13 ms    ±56.06%        1.04 ms        4.92 ms

Comparison:
FEnum.reverse/1 (binary)       2420.83
Enum.reverse/1                  900.98 - 2.69x slower +0.70 ms
FEnum.reverse/1 (list)          882.30 - 2.74x slower +0.72 ms

Memory usage statistics:

Name                        Memory usage
FEnum.reverse/1 (binary)      0.00006 MB
Enum.reverse/1                  11.01 MB - 180342.50x memory usage +11.01 MB
FEnum.reverse/1 (list)          11.01 MB - 180352.50x memory usage +11.01 MB

**All measurements for memory usage were the same**

*** dedup (1000000 sorted integers) ***

Name                             ips        average  deviation         median         99th %
FEnum.dedup/1 (binary)        337.47        2.96 ms     ±0.74%        2.96 ms        3.02 ms
FEnum.dedup/1 (list)          135.79        7.36 ms    ±18.18%        7.45 ms       12.51 ms
Enum.dedup/1                  132.57        7.54 ms    ±16.70%        7.62 ms       12.10 ms

Comparison:
FEnum.dedup/1 (binary)        337.47
FEnum.dedup/1 (list)          135.79 - 2.49x slower +4.40 ms
Enum.dedup/1                  132.57 - 2.55x slower +4.58 ms

Memory usage statistics:

Name                      Memory usage
FEnum.dedup/1 (binary)      0.00006 MB
FEnum.dedup/1 (list)          16.94 MB - 277548.00x memory usage +16.94 MB
Enum.dedup/1                  16.94 MB - 277548.00x memory usage +16.94 MB

**All measurements for memory usage were the same**

*** uniq (1000000 integers) ***

Name                            ips        average  deviation         median         99th %
FEnum.uniq/1 (binary)         23.73       42.14 ms     ±2.68%       42.58 ms       43.21 ms
FEnum.uniq/1 (list)           20.54       48.69 ms     ±3.75%       48.45 ms       55.06 ms
Enum.uniq/1                    4.00      250.28 ms     ±4.94%      247.90 ms      284.27 ms

Comparison:
FEnum.uniq/1 (binary)         23.73
FEnum.uniq/1 (list)           20.54 - 1.16x slower +6.55 ms
Enum.uniq/1                    4.00 - 5.94x slower +208.14 ms

Memory usage statistics:

Name                     Memory usage
FEnum.uniq/1 (binary)            64 B
FEnum.uniq/1 (list)               0 B - 0.00x memory usage -64 B
Enum.uniq/1               392108248 B - 6126691.38x memory usage +392108184 B

**All measurements for memory usage were the same**

*** sum (1000000 integers) ***

Name                           ips        average  deviation         median         99th %
FEnum.sum/1 (binary)       4708.02        0.21 ms     ±1.81%        0.21 ms        0.23 ms
Enum.sum/1                  618.69        1.62 ms     ±1.70%        1.61 ms        1.70 ms
FEnum.sum/1 (list)          617.77        1.62 ms     ±2.12%        1.61 ms        1.73 ms

Comparison:
FEnum.sum/1 (binary)       4708.02
Enum.sum/1                  618.69 - 7.61x slower +1.40 ms
FEnum.sum/1 (list)          617.77 - 7.62x slower +1.41 ms

Memory usage statistics:

Name                    Memory usage
FEnum.sum/1 (binary)             0 B
Enum.sum/1                       0 B - 1.00x memory usage +0 B
FEnum.sum/1 (list)               0 B - 1.00x memory usage +0 B

**All measurements for memory usage were the same**

*** min (1000000 integers) ***

Name                           ips        average  deviation         median         99th %
FEnum.min/1 (binary)       3601.22        0.28 ms     ±1.10%        0.28 ms        0.29 ms
FEnum.min/1 (list)          629.74        1.59 ms     ±3.54%        1.57 ms        1.82 ms
Enum.min/1                  623.28        1.60 ms     ±3.68%        1.59 ms        1.82 ms

Comparison:
FEnum.min/1 (binary)       3601.22
FEnum.min/1 (list)          629.74 - 5.72x slower +1.31 ms
Enum.min/1                  623.28 - 5.78x slower +1.33 ms

Memory usage statistics:

Name                    Memory usage
FEnum.min/1 (binary)             0 B
FEnum.min/1 (list)               0 B - 1.00x memory usage +0 B
Enum.min/1                       0 B - 1.00x memory usage +0 B

**All measurements for memory usage were the same**

*** max (1000000 integers) ***

Name                           ips        average  deviation         median         99th %
FEnum.max/1 (binary)       3594.59        0.28 ms     ±1.11%        0.28 ms        0.29 ms
FEnum.max/1 (list)          631.40        1.58 ms     ±3.03%        1.57 ms        1.79 ms
Enum.max/1                  624.64        1.60 ms     ±3.50%        1.58 ms        1.83 ms

Comparison:
FEnum.max/1 (binary)       3594.59
FEnum.max/1 (list)          631.40 - 5.69x slower +1.31 ms
Enum.max/1                  624.64 - 5.75x slower +1.32 ms

Memory usage statistics:

Name                    Memory usage
FEnum.max/1 (binary)             0 B
FEnum.max/1 (list)               0 B - 1.00x memory usage +0 B
Enum.max/1                       0 B - 1.00x memory usage +0 B

**All measurements for memory usage were the same**

*** member? worst case (1000000 integers) ***

Name                               ips        average  deviation         median         99th %
FEnum.member?/2 (binary)        4.70 K      212.64 μs     ±1.78%      211.25 μs      228.05 μs
FEnum.member?/2 (list)          1.73 K      576.86 μs     ±6.55%      573.21 μs      674.35 μs
Enum.member?/2 (worst)          1.68 K      595.42 μs     ±8.64%      590.52 μs      743.19 μs

Comparison:
FEnum.member?/2 (binary)        4.70 K
FEnum.member?/2 (list)          1.73 K - 2.71x slower +364.22 μs
Enum.member?/2 (worst)          1.68 K - 2.80x slower +382.78 μs

Memory usage statistics:

Name                        Memory usage
FEnum.member?/2 (binary)             0 B
FEnum.member?/2 (list)               0 B - 1.00x memory usage +0 B
Enum.member?/2 (worst)               0 B - 1.00x memory usage +0 B

**All measurements for memory usage were the same**

*** frequencies (1000000 integers) ***

Name                                   ips        average  deviation         median         99th %
FEnum.frequencies/1 (binary)          8.82      113.43 ms     ±3.32%      113.30 ms      120.46 ms
FEnum.frequencies/1 (list)            8.57      116.65 ms     ±3.33%      115.08 ms      123.38 ms
Enum.frequencies/1                    2.71      368.66 ms     ±4.74%      365.90 ms      409.28 ms

Comparison:
FEnum.frequencies/1 (binary)          8.82
FEnum.frequencies/1 (list)            8.57 - 1.03x slower +3.23 ms
Enum.frequencies/1                    2.71 - 3.25x slower +255.23 ms

Memory usage statistics:

Name                            Memory usage
FEnum.frequencies/1 (binary)         1.59 KB
FEnum.frequencies/1 (list)         568.83 KB - 358.67x memory usage +567.24 KB
Enum.frequencies/1              561038.09 KB - 353758.00x memory usage +561036.50 KB

**All measurements for memory usage were the same**

=== CHAIN BENCHMARKS ===


*** Chain: sort + dedup + take(100) ***

Name                                      ips        average  deviation         median         99th %
FEnum chain (sort+dedup+take)           45.19       22.13 ms     ±4.52%       22.33 ms       23.71 ms
Enum pipeline (sort+dedup+take)          7.81      127.99 ms     ±9.01%      121.82 ms      157.88 ms

Comparison:
FEnum chain (sort+dedup+take)           45.19
Enum pipeline (sort+dedup+take)          7.81 - 5.78x slower +105.87 ms

Memory usage statistics:

Name                               Memory usage
FEnum chain (sort+dedup+take)        0.00180 MB
Enum pipeline (sort+dedup+take)       224.51 MB - 124693.31x memory usage +224.51 MB

**All measurements for memory usage were the same**

*** Chain: sort + reverse + slice(0..99) ***

Name                                         ips        average  deviation         median         99th %
FEnum chain (sort+reverse+slice)           53.55       18.67 ms     ±3.70%       18.77 ms       20.25 ms
Enum pipeline (sort+reverse+slice)          7.66      130.50 ms    ±12.37%      131.87 ms      162.39 ms

Comparison:
FEnum chain (sort+reverse+slice)           53.55
Enum pipeline (sort+reverse+slice)          7.66 - 6.99x slower +111.83 ms

Memory usage statistics:

Name                                  Memory usage
FEnum chain (sort+reverse+slice)        0.00182 MB
Enum pipeline (sort+reverse+slice)       220.50 MB - 120927.31x memory usage +220.50 MB

**All measurements for memory usage were the same**

*** Chain: sort + uniq + sum ***

Name                                    ips        average  deviation         median         99th %
FEnum chain (sort+uniq+sum)           16.92       59.12 ms     ±1.26%       59.04 ms       60.83 ms
Enum pipeline (sort+uniq+sum)          2.57      389.33 ms     ±4.18%      387.35 ms      424.06 ms

Comparison:
FEnum chain (sort+uniq+sum)           16.92
Enum pipeline (sort+uniq+sum)          2.57 - 6.59x slower +330.21 ms

Memory usage statistics:

Name                             Memory usage
FEnum chain (sort+uniq+sum)        0.00021 MB
Enum pipeline (sort+uniq+sum)       579.28 MB - 2812105.67x memory usage +579.28 MB

**All measurements for memory usage were the same**

*** Chain: sort + dedup + frequencies ***

Name                                             ips        average  deviation         median         99th %
FEnum chain (sort+dedup+frequencies)            8.48      117.87 ms     ±3.41%      116.34 ms      125.28 ms
Enum pipeline (sort+dedup+frequencies)          2.88      347.70 ms     ±2.49%      347.56 ms      363.53 ms

Comparison:
FEnum chain (sort+dedup+frequencies)            8.48
Enum pipeline (sort+dedup+frequencies)          2.88 - 2.95x slower +229.83 ms

Memory usage statistics:

Name                                      Memory usage
FEnum chain (sort+dedup+frequencies)           0.56 MB
Enum pipeline (sort+dedup+frequencies)       575.10 MB - 1035.29x memory usage +574.54 MB

**All measurements for memory usage were the same**

*** Chain: filter + sort + uniq + sum (mixed Tier 1 + 2) ***

Name                                           ips        average  deviation         median         99th %
FEnum chain (filter+sort+uniq+sum)           18.26       54.77 ms     ±6.06%       53.29 ms       60.62 ms
Enum pipeline (filter+sort+uniq+sum)          5.50      181.94 ms     ±5.16%      181.86 ms      202.29 ms

Comparison:
FEnum chain (filter+sort+uniq+sum)           18.26
Enum pipeline (filter+sort+uniq+sum)          5.50 - 3.32x slower +127.18 ms

Memory usage statistics:

Name                                    Memory usage
FEnum chain (filter+sort+uniq+sum)           7.63 MB
Enum pipeline (filter+sort+uniq+sum)       278.75 MB - 36.52x memory usage +271.12 MB

**All measurements for memory usage were the same**

Benchmarks complete!