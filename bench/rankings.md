# FEnum scaling benchmarks — ranked by input size

Each operation below has two sub-tables. **List input** compares `Enum.<op>` against `FEnum.<op>` on a list — the honest apples-to-apples comparison when your data is already a list and you can't change its layout. **Binary input** shows `FEnum.<op>` on a packed `i64` binary on its own, with each cell reporting how much faster (or slower) it is than the fastest list variant at the same size, so you can see the extra lift you get from binary storage. Ops with no binary path (the chain benchmark) only show the first table.

The badge next to each section title shows how `FEnum` handles list input: **uses NIF** runs in Rust, **passthrough to Enum** just forwards to the standard library. The **Binary input** sub-header is always `(uses NIF)` — every binary clause dispatches to a Rust NIF.

Each cell shows iterations-per-second on the first line (higher is better) and the average run time on the second line (lower is better). Rows in the list table are ordered by the winner at `n = 1,000,000`; the **bold** cell in each column is the fastest entry at that size, and row 2 gets a third italic line with its slowdown vs. the column's fastest.

Source: `bench/scaling_bench.exs`, medians over warmup 1 s / runtime 3 s / memory 1 s on Apple M2 Pro (macOS, Elixir 1.19, Erlang/OTP 28). Regenerate the underlying HTML reports with `mix run bench/scaling_bench.exs`, then re-render this file with `elixir bench/gen_rankings.exs`.

> **Noise note:** at `n = 100` the cheap operations (`reverse`, `sum`, `min`, `max`, `member?`, `dedup`) run in sub-microsecond territory, so the IPS numbers there are dominated by benchmark jitter — don't read too much into small rank swaps in that column (e.g. `FEnum.min` appearing to beat `Enum.min` by 22× at `n = 100` in the list table, even though `FEnum.min/1` unconditionally delegates to `Enum.min/1` for list input).

### sort (uses NIF)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.sort` | 325.89 K ips<br/>3.07 µs<br/>_1.31× slower_ | **50.24 K ips**<br/>19.91 µs | **7.34 K ips**<br/>136.30 µs | **670.70 ips**<br/>1.49 ms | **51.00 ips**<br/>19.61 ms |
| `Enum.sort` | **426.86 K ips**<br/>2.34 µs | 29.70 K ips<br/>33.67 µs<br/>_1.69× slower_ | 2.22 K ips<br/>450.68 µs<br/>_3.31× slower_ | 142.54 ips<br/>7.02 ms<br/>_4.71× slower_ | 8.04 ips<br/>124.30 ms<br/>_6.34× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.sort` | **450.09 K ips**<br/>2.22 µs<br/>_1.05× faster than fastest list_ | **79.24 K ips**<br/>12.62 µs<br/>_1.58× faster than fastest list_ | **11.18 K ips**<br/>89.43 µs<br/>_1.52× faster than fastest list_ | **1.03 K ips**<br/>967.44 µs<br/>_1.54× faster than fastest list_ | **89.65 ips**<br/>11.15 ms<br/>_1.76× faster than fastest list_ |

### sort :desc (uses NIF)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.sort :desc` | 337.81 K ips<br/>2.96 µs<br/>_1.20× slower_ | **50.18 K ips**<br/>19.93 µs | **7.30 K ips**<br/>137.03 µs | **665.50 ips**<br/>1.50 ms | **50.67 ips**<br/>19.73 ms |
| `Enum.sort :desc` | **405.16 K ips**<br/>2.47 µs | 28.75 K ips<br/>34.78 µs<br/>_1.75× slower_ | 2.18 K ips<br/>458.03 µs<br/>_3.34× slower_ | 138.69 ips<br/>7.21 ms<br/>_4.80× slower_ | 7.50 ips<br/>133.38 ms<br/>_6.76× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.sort :desc` | **464.76 K ips**<br/>2.15 µs<br/>_1.15× faster than fastest list_ | **79.06 K ips**<br/>12.65 µs<br/>_1.58× faster than fastest list_ | **11.19 K ips**<br/>89.33 µs<br/>_1.53× faster than fastest list_ | **1.03 K ips**<br/>971.38 µs<br/>_1.55× faster than fastest list_ | **89.29 ips**<br/>11.20 ms<br/>_1.76× faster than fastest list_ |

### uniq (uses NIF)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.uniq` | **284.62 K ips**<br/>3.51 µs | **55.18 K ips**<br/>18.12 µs | **8.66 K ips**<br/>115.43 µs | **762.71 ips**<br/>1.31 ms | **73.67 ips**<br/>13.57 ms |
| `Enum.uniq` | 177.79 K ips<br/>5.62 µs<br/>_1.60× slower_ | 16.57 K ips<br/>60.36 µs<br/>_3.33× slower_ | 1.37 K ips<br/>730.21 µs<br/>_6.33× slower_ | 84.47 ips<br/>11.84 ms<br/>_9.03× slower_ | 4.03 ips<br/>247.96 ms<br/>_18.27× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.uniq` | **390.90 K ips**<br/>2.56 µs<br/>_1.37× faster than fastest list_ | **86.30 K ips**<br/>11.59 µs<br/>_1.56× faster than fastest list_ | **14.55 K ips**<br/>68.72 µs<br/>_1.68× faster than fastest list_ | **1.20 K ips**<br/>830.01 µs<br/>_1.58× faster than fastest list_ | **153.61 ips**<br/>6.51 ms<br/>_2.08× faster than fastest list_ |

### frequencies (uses NIF)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.frequencies` | **146.47 K ips**<br/>6.83 µs | **16.20 K ips**<br/>61.72 µs | **1.68 K ips**<br/>596.59 µs | **139.29 ips**<br/>7.18 ms | **11.39 ips**<br/>87.77 ms |
| `Enum.frequencies` | 145.70 K ips<br/>6.86 µs<br/>_1.01× slower_ | 13.21 K ips<br/>75.71 µs<br/>_1.23× slower_ | 928.71 ips<br/>1.08 ms<br/>_1.80× slower_ | 58.32 ips<br/>17.15 ms<br/>_2.39× slower_ | 2.97 ips<br/>337.11 ms<br/>_3.84× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.frequencies` | **172.58 K ips**<br/>5.79 µs<br/>_1.18× faster than fastest list_ | **17.72 K ips**<br/>56.43 µs<br/>_1.09× faster than fastest list_ | **1.78 K ips**<br/>561.44 µs<br/>_1.06× faster than fastest list_ | **148.09 ips**<br/>6.75 ms<br/>_1.06× faster than fastest list_ | **12.13 ips**<br/>82.44 ms<br/>_1.06× faster than fastest list_ |

### chain: sort+uniq+sum (uses NIF)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum chain` | **176.07 K ips**<br/>5.68 µs | **33.20 K ips**<br/>30.12 µs | **4.38 K ips**<br/>228.11 µs | **408.88 ips**<br/>2.45 ms | **39.37 ips**<br/>25.40 ms |
| `Enum pipeline` | 128.28 K ips<br/>7.80 µs<br/>_1.37× slower_ | 10.70 K ips<br/>93.46 µs<br/>_3.10× slower_ | 820.99 ips<br/>1.22 ms<br/>_5.34× slower_ | 52.02 ips<br/>19.22 ms<br/>_7.86× slower_ | 2.78 ips<br/>359.73 ms<br/>_14.16× slower_ |

### reverse (passthrough to Enum)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.reverse` | 7.53 M ips<br/>0.13 µs<br/>_1.00× slower_ | 565.60 K ips<br/>1.77 µs<br/>_1.06× slower_ | **82.95 K ips**<br/>12.06 µs | 7.22 K ips<br/>138.54 µs<br/>_1.48× slower_ | **185.67 ips**<br/>5.39 ms |
| `Enum.reverse` | **7.54 M ips**<br/>0.13 µs | **597.84 K ips**<br/>1.67 µs | 82.70 K ips<br/>12.09 µs<br/>_1.00× slower_ | **10.66 K ips**<br/>93.81 µs | 182.74 ips<br/>5.47 ms<br/>_1.02× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.reverse` | 621.88 K ips<br/>1.61 µs<br/>_12.12× slower than fastest list_ | 223.37 K ips<br/>4.48 µs<br/>_2.68× slower than fastest list_ | **143.50 K ips**<br/>6.97 µs<br/>_1.73× faster than fastest list_ | **20.03 K ips**<br/>49.92 µs<br/>_1.88× faster than fastest list_ | **2.38 K ips**<br/>420.21 µs<br/>_12.82× faster than fastest list_ |

### dedup (passthrough to Enum)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `Enum.dedup` | **3.02 M ips**<br/>0.33 µs | **294.27 K ips**<br/>3.40 µs | **36.64 K ips**<br/>27.29 µs | 3.39 K ips<br/>294.83 µs<br/>_1.00× slower_ | **78.22 ips**<br/>12.79 ms |
| `FEnum.dedup` | 2.97 M ips<br/>0.34 µs<br/>_1.02× slower_ | 293.43 K ips<br/>3.41 µs<br/>_1.00× slower_ | 35.14 K ips<br/>28.46 µs<br/>_1.04× slower_ | **3.40 K ips**<br/>293.75 µs | 77.78 ips<br/>12.86 ms<br/>_1.01× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.dedup` | 597.88 K ips<br/>1.67 µs<br/>_5.05× slower than fastest list_ | 172.51 K ips<br/>5.80 µs<br/>_1.71× slower than fastest list_ | **53.25 K ips**<br/>18.78 µs<br/>_1.45× faster than fastest list_ | **6.86 K ips**<br/>145.83 µs<br/>_2.01× faster than fastest list_ | **714.89 ips**<br/>1.40 ms<br/>_9.14× faster than fastest list_ |

### sum (passthrough to Enum)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.sum` | **211.10 K ips**<br/>4.74 µs | **501.46 K ips**<br/>1.99 µs | **51.90 K ips**<br/>19.27 µs | **5.75 K ips**<br/>173.99 µs | **681.03 ips**<br/>1.47 ms |
| `Enum.sum` | 211.02 K ips<br/>4.74 µs<br/>_1.00× slower_ | 499.62 K ips<br/>2.00 µs<br/>_1.00× slower_ | 51.62 K ips<br/>19.37 µs<br/>_1.01× slower_ | 5.74 K ips<br/>174.17 µs<br/>_1.00× slower_ | 678.26 ips<br/>1.47 ms<br/>_1.00× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.sum` | **11.95 M ips**<br/>0.08 µs<br/>_56.63× faster than fastest list_ | **5.96 M ips**<br/>0.17 µs<br/>_11.88× faster than fastest list_ | **878.63 K ips**<br/>1.14 µs<br/>_16.93× faster than fastest list_ | **83.20 K ips**<br/>12.02 µs<br/>_14.48× faster than fastest list_ | **6.79 K ips**<br/>147.29 µs<br/>_9.97× faster than fastest list_ |

### min (passthrough to Enum)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `Enum.min` | **4.66 M ips**<br/>0.21 µs | **460.63 K ips**<br/>2.17 µs | 50.02 K ips<br/>19.99 µs<br/>_1.02× slower_ | 5.49 K ips<br/>182.20 µs<br/>_1.00× slower_ | **663.78 ips**<br/>1.51 ms |
| `FEnum.min` | 211.04 K ips<br/>4.74 µs<br/>_22.07× slower_ | 460.50 K ips<br/>2.17 µs<br/>_1.00× slower_ | **51.18 K ips**<br/>19.54 µs | **5.51 K ips**<br/>181.47 µs | 658.20 ips<br/>1.52 ms<br/>_1.01× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.min` | **10.49 M ips**<br/>0.10 µs<br/>_2.25× faster than fastest list_ | **4.11 M ips**<br/>0.24 µs<br/>_8.92× faster than fastest list_ | **566.41 K ips**<br/>1.77 µs<br/>_11.07× faster than fastest list_ | **54.27 K ips**<br/>18.43 µs<br/>_9.85× faster than fastest list_ | **5.79 K ips**<br/>172.58 µs<br/>_8.73× faster than fastest list_ |

### max (passthrough to Enum)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.max` | **4.67 M ips**<br/>0.21 µs | 461.69 K ips<br/>2.17 µs<br/>_1.00× slower_ | 49.84 K ips<br/>20.07 µs<br/>_1.05× slower_ | **5.51 K ips**<br/>181.51 µs | **670.67 ips**<br/>1.49 ms |
| `Enum.max` | 211.63 K ips<br/>4.73 µs<br/>_22.07× slower_ | **462.43 K ips**<br/>2.16 µs | **52.13 K ips**<br/>19.18 µs | 5.51 K ips<br/>181.52 µs<br/>_1.00× slower_ | 663.01 ips<br/>1.51 ms<br/>_1.01× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.max` | **10.50 M ips**<br/>0.10 µs<br/>_2.25× faster than fastest list_ | **4.09 M ips**<br/>0.24 µs<br/>_8.84× faster than fastest list_ | **567.13 K ips**<br/>1.76 µs<br/>_10.88× faster than fastest list_ | **54.68 K ips**<br/>18.29 µs<br/>_9.92× faster than fastest list_ | **5.77 K ips**<br/>173.40 µs<br/>_8.60× faster than fastest list_ |

### member? (passthrough to Enum)

**List input**

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `Enum.member?` | **8.47 M ips**<br/>0.12 µs | 660.37 K ips<br/>1.51 µs<br/>_1.00× slower_ | **80.35 K ips**<br/>12.45 µs | **11.55 K ips**<br/>86.61 µs | **1.67 K ips**<br/>597.61 µs |
| `FEnum.member?` | 213.25 K ips<br/>4.69 µs<br/>_39.73× slower_ | **660.40 K ips**<br/>1.51 µs | 80.22 K ips<br/>12.47 µs<br/>_1.00× slower_ | 11.46 K ips<br/>87.28 µs<br/>_1.01× slower_ | 1.65 K ips<br/>607.76 µs<br/>_1.02× slower_ |

**Binary input** (uses NIF)

| Function | n = 100 | n = 1,000 | n = 10,000 | n = 100,000 | n = 1,000,000 |
|---|---|---|---|---|---|
| `FEnum.member?` | **10.85 M ips**<br/>0.09 µs<br/>_1.28× faster than fastest list_ | **5.19 M ips**<br/>0.19 µs<br/>_7.86× faster than fastest list_ | **852.70 K ips**<br/>1.17 µs<br/>_10.61× faster than fastest list_ | **82.46 K ips**<br/>12.13 µs<br/>_7.14× faster than fastest list_ | **6.92 K ips**<br/>144.47 µs<br/>_4.14× faster than fastest list_ |
