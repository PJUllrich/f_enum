# FEnum

A drop-in replacement for `Enum` backed by Rust NIFs. Simply fename `Enum` to `FEnum` and your integer-list code gets up to 6x faster. For chained operations, you can get even bigger speedups.

## How it works

FEnum has three input modes. The same function handles all three via pattern matching:

```elixir
FEnum.sort(%FEnum.Ref{} = ref)   # Chain: Ref -> Ref (data stays in Rust)
FEnum.sort(<<_::binary>>)         # Binary: binary -> binary (near-zero copy to NIF)
FEnum.sort([3, 1, 2])             # List: uses NIF or delegates to Enum
FEnum.sort(1..10)                 # Fallback: delegates to Enum
```

**Lists** go through Rustler's list protocol for expensive operations (sort, uniq, frequencies) where the Rust algorithm beats the BEAM despite the decode cost. Simple traversals (sum, min, max, reverse, member?) delegate straight to `Enum` because the BEAM's JIT is already optimal for single-pass operations.

**Packed binaries** (`<<i::signed-native-64>>` format) are passed to the NIF by reference with near-zero copy. This is the fastest path.

**Chain mode** converts once at the boundaries with `new/1` and `run/1`. Between those calls, data stays in a Rust `Vec<i64>` behind a `ResourceArc` -- no conversion overhead between operations.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [{:f_enum, "~> 0.1.0"}]
end
```

Requires a Rust toolchain (`rustup`). Rustler compiles the NIF automatically on `mix compile`.

## Usage

### One-shot (drop-in replacement)

Same signatures as `Enum`. List in, list out:

```elixir
FEnum.sort([3, 1, 4, 1, 5])              #=> [1, 1, 3, 4, 5]
FEnum.sort([3, 1, 4], :desc)             #=> [4, 3, 1]
FEnum.uniq([3, 1, 2, 1, 3])             #=> [3, 1, 2]
FEnum.frequencies([1, 2, 1, 3, 2, 1])   #=> %{1 => 3, 2 => 2, 3 => 1}

# Simple operations delegate to Enum (BEAM JIT is faster)
FEnum.sum([1, 2, 3])                    #=> 6
FEnum.min([3, 1, 2])                    #=> 1
FEnum.reverse([1, 2, 3])               #=> [3, 2, 1]
```

### Binary input

If your data is already a packed binary of native-endian signed 64-bit integers, FEnum detects it automatically and skips the list protocol entirely:

```elixir
# Pack a list into binary format
binary = for i <- [3, 1, 4, 1, 5], into: <<>>, do: <<i::signed-native-64>>

# Sort returns a binary -- no list conversion overhead
sorted = FEnum.sort(binary)

# Unpack when you need a list
for <<i::signed-native-64 <- sorted>>, do: i
#=> [1, 1, 3, 4, 5]

# Scalars work too
FEnum.sum(binary)      #=> 14
FEnum.min(binary)      #=> 1
FEnum.max(binary)      #=> 5
```

### Chain mode

For multi-step pipelines, keep data in Rust between operations:

```elixir
[3, 1, 4, 1, 5, 9, 2, 6, 5, 3]
|> FEnum.new()        # list -> ResourceArc (one conversion)
|> FEnum.sort()       # Ref -> Ref (zero copy, operates in Rust)
|> FEnum.dedup()      # Ref -> Ref (zero copy)
|> FEnum.take(5)      # Ref -> Ref (zero copy)
|> FEnum.run()        # ResourceArc -> list (one conversion)
#=> [1, 2, 3, 4, 5]

# Scalar output -- no need for run/1
[1, 2, 3, 4, 5]
|> FEnum.new()
|> FEnum.filter(&(&1 > 2))
|> FEnum.sum()
#=> 12
```

### Fallback

Non-integer-list inputs (maps, ranges, MapSets, keyword lists) are forwarded to `Enum`, so FEnum is always safe to use:

```elixir
FEnum.sort(3..1//-1)            #=> [1, 2, 3]
FEnum.sum(1..100)               #=> 5050
FEnum.map(%{a: 1}, &elem(&1, 1))  #=> [1]
```

## Benchmarks

All benchmarks use 1M random integers. Run them yourself with `mix run bench/fenum_bench.exs`.

List input delegates to `Enum` for simple traversals (sum, min, max, reverse, member?, dedup) where the BEAM's JIT is already optimal, and uses Rust NIFs for expensive operations (sort, uniq, frequencies). Binary input always uses the NIF via zero-copy reference passing.

### One-shot: list input

| Function | Enum ips | FEnum ips | Avg time | Speedup | Enum memory | FEnum memory | Mem reduction |
|---|---|---|---|---|---|---|---|
| sort | 9.08 | 51.63 | 19.37 ms | 5.69x | 205.88 MB | 0 B | ~100% |
| sort :desc | 9.01 | 51.72 | 19.33 ms | 5.74x | 220.49 MB | 0 B | ~100% |
| uniq | 4.00 | 20.54 | 48.69 ms | 5.14x | 374.00 MB | 0 B | ~100% |
| frequencies | 2.71 | 8.57 | 116.65 ms | 3.16x | 547.89 MB | 0.56 MB | 99.9% |
| reverse | 900.98 | 882.30 | 1.13 ms | =Enum | 11.01 MB | 11.01 MB | -- |
| dedup | 132.57 | 135.79 | 7.36 ms | =Enum | 16.94 MB | 16.94 MB | -- |
| sum | 618.69 | 617.77 | 1.62 ms | =Enum | 0 B | 0 B | -- |
| min | 623.28 | 629.74 | 1.59 ms | =Enum | 0 B | 0 B | -- |
| max | 624.64 | 631.40 | 1.58 ms | =Enum | 0 B | 0 B | -- |
| member? | 1,680 | 1,730 | 576.86 μs | =Enum | 0 B | 0 B | -- |

### One-shot: binary input

| Function | Enum ips | FEnum ips | Avg time | Speedup | Enum memory | FEnum memory | Mem reduction |
|---|---|---|---|---|---|---|---|
| sort | 9.08 | 90.20 | 11.09 ms | 9.93x | 205.88 MB | 64 B | ~100% |
| sort :desc | 9.01 | 90.04 | 11.11 ms | 10.00x | 220.49 MB | 64 B | ~100% |
| reverse | 900.98 | 2,420.83 | 0.41 ms | 2.69x | 11.01 MB | 64 B | ~100% |
| dedup | 132.57 | 337.47 | 2.96 ms | 2.55x | 16.94 MB | 64 B | ~100% |
| uniq | 4.00 | 23.73 | 42.14 ms | 5.94x | 374.00 MB | 64 B | ~100% |
| sum | 618.69 | 4,708.02 | 0.21 ms | 7.61x | 0 B | 0 B | -- |
| min | 623.28 | 3,601.22 | 0.28 ms | 5.78x | 0 B | 0 B | -- |
| max | 624.64 | 3,594.59 | 0.28 ms | 5.75x | 0 B | 0 B | -- |
| member? | 1,680 | 4,700 | 212.64 μs | 2.80x | 0 B | 0 B | -- |
| frequencies | 2.71 | 8.82 | 113.43 ms | 3.25x | 547.89 MB | 1.59 KB | ~100% |

### Chain mode

| Pipeline | Enum ips | FEnum ips | Enum avg | FEnum avg | Speedup | Enum memory | FEnum memory |
|---|---|---|---|---|---|---|---|
| sort + dedup + take | 9.27 | 48.97 | 107.8 ms | 20.4 ms | 5.28x | 237.48 MB | 0.002 MB |
| sort + reverse + slice | 9.34 | 57.01 | 107.1 ms | 17.5 ms | 6.11x | 233.44 MB | 0.002 MB |
| sort + uniq + sum | 2.59 | 16.99 | 385.7 ms | 58.9 ms | 6.55x | 592.79 MB | 0.0002 MB |
| sort + dedup + frequencies | 2.91 | 8.60 | 343.6 ms | 116.2 ms | 2.96x | 586.74 MB | 0.56 MB |

### Chain mode: filter placement matters

Functions that take an Elixir callback (like `filter/2`) cause a Ref→list→Ref round-trip in chain mode. Where you place them in the pipeline affects performance:

| Variant | ips | Avg time | Speedup vs Enum |
|---|---|---|---|
| `Enum.filter \|> FEnum.new \|> sort \|> uniq \|> sum` | 25.70 | 38.9 ms | 4.56x |
| `FEnum.new \|> FEnum.filter \|> sort \|> uniq \|> sum` | 20.75 | 48.2 ms | 3.62x |
| `Enum.filter \|> Enum.sort \|> Enum.uniq \|> Enum.sum` | 5.63 | 177.5 ms | -- |

Filtering **before** `new/1` is 24% faster than filtering **after** — it avoids the round-trip and feeds a smaller list into Rust. When your pipeline includes callback-based operations, keep them outside the chain boundaries where possible:

```elixir
# Preferred: filter in Elixir, then enter the chain with less data
list
|> Enum.filter(&(&1 > threshold))
|> FEnum.new()
|> FEnum.sort()
|> FEnum.uniq()
|> FEnum.sum()

# Slower: filter inside the chain forces Ref -> list -> Ref
list
|> FEnum.new()
|> FEnum.filter(&(&1 > threshold))
|> FEnum.sort()
|> FEnum.uniq()
|> FEnum.sum()
```

## Supported functions

### Tier 1 -- Pure NIF (fastest)

Functions that run entirely in Rust with no Elixir callbacks:

`sort/1`, `sort/2`, `reverse/1`, `dedup/1`, `uniq/1`, `sum/1`, `product/1`, `min/1`, `max/1`, `min_max/1`, `count/1`, `at/2`, `fetch!/2`, `slice/2`, `take/2`, `drop/2`, `member?/2`, `empty?/1`, `concat/2`, `frequencies/1`, `join/2`, `with_index/1`, `zip/2`, `chunk_every/2`, `into/2`

### Tier 2 -- Hybrid (NIF + Elixir callback)

Functions that take an Elixir fun. In chain mode, data round-trips through Elixir for the callback step; Tier 1 steps before and after are still zero-copy:

`filter/2`, `reject/2`, `map/2`, `flat_map/2`, `reduce/3`, `map_reduce/3`, `scan/2`, `find/2`, `find_index/2`, `find_value/2`, `any?/2`, `all?/2`, `count/2`, `sort_by/2`, `each/2`, `group_by/2`

## Protocols

`FEnum.Ref` implements `Enumerable`, so standard `Enum` functions work on it:

```elixir
ref = FEnum.new([1, 2, 3])
Enum.to_list(ref)    #=> [1, 2, 3]
Enum.count(ref)      #=> 3
for x <- ref, do: x * 2  #=> [2, 4, 6]
```

`Inspect` is also implemented:

```elixir
FEnum.new([1, 2, 3])
#=> #FEnum.Ref<[1, 2, 3] i64, length: 3>

FEnum.new(Enum.to_list(1..1_000_000))
#=> #FEnum.Ref<[1, 2, 3, 4, 5, ...] i64, length: 1000000>
```

## Constraints

- **Integer lists only** (`i64`). Float support may come later.
- Rust toolchain required at compile time.
- The NIF list path only kicks in for operations where Rust beats the BEAM (sort, uniq, frequencies). Simple traversals delegate to `Enum`.

## License

MIT
