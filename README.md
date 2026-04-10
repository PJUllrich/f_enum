# FEnum

A drop-in replacement for `Enum` backed by Rust NIFs. Simply rename `Enum` to `FEnum` and your integer-list code gets up to 20x faster. For chained operations, you can get even bigger speedups.

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
| sort | 9.12 | 55.60 | 18.0 ms | 6.10x | 218.34 MB | 0 B | ~100% |
| sort :desc | 9.45 | 55.47 | 18.0 ms | 5.87x | 233.59 MB | 0 B | ~100% |
| uniq | 4.11 | 81.60 | 12.3 ms | 19.86x | 374.16 MB | 0 B | ~100% |
| frequencies | 2.90 | 10.24 | 97.7 ms | 3.53x | 548.55 MB | 0.57 MB | 99.9% |
| reverse | 889.19 | 891.81 | 1.12 ms | =Enum | 11.01 MB | 11.01 MB | -- |
| dedup | 110.16 | 105.55 | 9.47 ms | =Enum | 16.87 MB | 16.87 MB | -- |
| sum | 608.91 | 613.01 | 1.63 ms | =Enum | 0 B | 0 B | -- |
| min | 623.59 | 623.84 | 1.60 ms | =Enum | 0 B | 0 B | -- |
| max | 622.94 | 622.35 | 1.61 ms | =Enum | 0 B | 0 B | -- |
| member? | 1,771 | 1,701 | 0.59 ms | =Enum | 0 B | 0 B | -- |

### One-shot: binary input

| Function | Enum ips | FEnum ips | Avg time | Speedup | Enum memory | FEnum memory | Mem reduction |
|---|---|---|---|---|---|---|---|
| sort | 9.12 | 88.10 | 11.4 ms | 9.66x | 218.34 MB | 64 B | ~100% |
| sort :desc | 9.45 | 89.73 | 11.2 ms | 9.50x | 233.59 MB | 64 B | ~100% |
| reverse | 889.19 | 2,430.39 | 0.41 ms | 2.73x | 11.01 MB | 64 B | ~100% |
| dedup | 110.16 | 390.24 | 2.56 ms | 3.54x | 16.87 MB | 64 B | ~100% |
| uniq | 4.11 | 146.86 | 6.81 ms | 35.73x | 374.16 MB | 64 B | ~100% |
| sum | 608.91 | 10,983.34 | 0.091 ms | 18.04x | 0 B | 0 B | -- |
| min | 623.59 | 6,475.15 | 0.154 ms | 10.38x | 0 B | 0 B | -- |
| max | 622.94 | 6,483.33 | 0.154 ms | 10.41x | 0 B | 0 B | -- |
| member? | 1,771 | 10,930.83 | 0.092 ms | 6.17x | 0 B | 0 B | -- |
| frequencies | 2.90 | 10.63 | 94.1 ms | 3.67x | 548.55 MB | 1.59 KB | ~100% |

### Chain mode

| Pipeline | Enum ips | FEnum ips | Enum avg | FEnum avg | Speedup | Enum memory | FEnum memory |
|---|---|---|---|---|---|---|---|
| sort + dedup + take | 8.59 | 52.81 | 116.4 ms | 18.9 ms | 6.15x | 236.45 MB | 0.002 MB |
| sort + reverse + slice | 9.44 | 59.37 | 106.0 ms | 16.8 ms | 6.29x | 233.44 MB | 0.002 MB |
| sort + uniq + sum | 2.80 | 35.29 | 357.2 ms | 28.3 ms | 12.61x | 592.79 MB | 0.0002 MB |
| sort + dedup + frequencies | 3.28 | 9.29 | 304.6 ms | 107.7 ms | 2.83x | 586.74 MB | 0.57 MB |

### Chain mode: filter placement matters

Functions that take an Elixir callback (like `filter/2`) cause a Ref→list→Ref round-trip in chain mode. Where you place them in the pipeline affects performance:

| Variant | ips | Avg time | Speedup vs Enum |
|---|---|---|---|
| `Enum.filter \|> FEnum.new \|> sort \|> uniq \|> sum` | 40.81 | 24.5 ms | 6.21x |
| `FEnum.new \|> FEnum.filter \|> sort \|> uniq \|> sum` | 32.58 | 30.7 ms | 4.96x |
| `Enum.filter \|> Enum.sort \|> Enum.uniq \|> Enum.sum` | 6.57 | 152.1 ms | -- |

Filtering **before** `new/1` is 25% faster than filtering **after** — it avoids the round-trip and feeds a smaller list into Rust. When your pipeline includes callback-based operations, keep them outside the chain boundaries where possible:

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
