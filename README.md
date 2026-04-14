# Faster Enum

A drop-in replacement for `Enum` backed by Rust NIFs. Simply rename `Enum` to `FEnum` and your integer-list code gets up to 20x faster. For chained operations, you can get even bigger speedups.

This library shines on larger collections, but many functions are faster than `Enum` even at n = 100.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [{:f_enum, "~> 0.1.0"}]
end
```

## Benchmarks

All benchmarks use 1,000,000 random integers. Run them yourself with `mix run bench/fenum_bench.exs`.

### One-shot: list input

| Function | Enum ips | FEnum ips | Speedup | Avg time |
|---|---|---|---|---|
| sort | 9.61 | 54.39 | 5.66x | 18.4 ms |
| sort :desc | 9.54 | 54.30 | 5.69x | 18.4 ms |
| uniq | 4.08 | 78.11 | 19.14x | 12.8 ms |
| frequencies | 2.90 | 12.03 | 4.15x | 83.1 ms |
| reverse | 893.89 | 877.78 | =Enum | 1.14 ms |
| dedup | 131.75 | 131.31 | =Enum | 7.62 ms |
| sum | 614.94 | 615.51 | =Enum | 1.62 ms |
| min | 628.59 | 629.53 | =Enum | 1.59 ms |
| max | 630.67 | 626.66 | =Enum | 1.60 ms |
| member? | 1,952 | 1,910 | =Enum | 0.52 ms |

### One-shot: binary input

| Function | Enum ips | FEnum ips | Speedup | Avg time |
|---|---|---|---|---|
| sort | 9.61 | 89.68 | 9.33x | 11.2 ms |
| sort :desc | 9.54 | 90.33 | 9.47x | 11.1 ms |
| reverse | 893.89 | 2,432.77 | 2.72x | 0.41 ms |
| dedup | 131.75 | 391.13 | 2.97x | 2.56 ms |
| uniq | 4.08 | 158.62 | 38.88x | 6.30 ms |
| sum | 614.94 | 11,291.10 | 18.36x | 0.089 ms |
| min | 628.59 | 6,581.04 | 10.47x | 0.152 ms |
| max | 630.67 | 6,565.04 | 10.41x | 0.152 ms |
| member? | 1,952 | 10,951.10 | 5.61x | 0.091 ms |
| frequencies | 2.90 | 12.77 | 4.40x | 78.3 ms |

### Chain mode

| Pipeline | Enum ips | FEnum ips | Speedup | Enum avg | FEnum avg |
|---|---|---|---|---|---|
| sort + dedup + take | 8.29 | 53.50 | 6.45x | 120.7 ms | 18.7 ms |
| sort + reverse + slice | 9.78 | 59.82 | 6.12x | 102.3 ms | 16.7 ms |
| sort + uniq + sum | 2.87 | 36.43 | 12.70x | 348.8 ms | 27.5 ms |
| sort + dedup + frequencies | 3.20 | 10.89 | 3.40x | 312.3 ms | 91.8 ms |

### Full scaling tables

For the full data see [`bench/rankings.md`](bench/rankings.md). Regenerate it with `mix run bench/scaling_bench.exs` followed by `mix run bench/gen_rankings.exs`.

## Usage

### One-shot (drop-in replacement)

Just replace `Enum` with `FEnum`. It has all functions that Enum also offers.

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

Start a chain with `FEnum.new/1` and finish it with `FEnum.run/1`. Every operation in between passes only a reference to the data (kept in Rust), not the data itself — so there is no conversion overhead between steps.

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

### Which functions FEnum actually speeds up

FEnum only reaches for Rust when the BEAM's JIT can't keep up, so not every function in the module is meaningfully faster than `Enum`.

**For list input**, only these four go through a NIF:

- `sort/1`, `sort/2`
- `uniq/1`
- `frequencies/1`
- any of the above in a chain pipeline (everything after `FEnum.new/1`)

Every other one-shot that takes a list — `reverse/1`, `dedup/1`, `sum/1`, `product/1`, `min/1`, `max/1`, `min_max/1`, `member?/2`, and the access/slicing helpers (`at/2`, `slice/2`, `take/2`, `drop/2`, `count/1`, `join/2`, `with_index/1`, `zip/2`, `chunk_every/2`, `into/2`) — unconditionally forwards to `Enum`. Calling `FEnum.sum([1, 2, 3])` is literally `Enum.sum([1, 2, 3])` with one extra function dispatch. If your op isn't in the list above and your input is a list, `FEnum` is just a wrapper and there's no speedup to be had — stick with `Enum`, or enter chain mode with `FEnum.new/1`, or pack your integers into an `<<i::signed-native-64>>` binary.

**For binary input**, every op uses a NIF and beats calling `Enum` after unpacking. This is the fastest path across the board.

### Chain mode: filter placement matters

Functions that take an Elixir callback (like `filter/2`) cause a Ref→list→Ref round-trip in chain mode. Where you place them in the pipeline affects performance:

| Variant | ips | Avg time | Speedup vs Enum |
|---|---|---|---|
| `Enum.filter \|> FEnum.new \|> sort \|> uniq \|> sum` | 41.34 | 24.2 ms | 6.51x |
| `FEnum.new \|> FEnum.filter \|> sort \|> uniq \|> sum` | 33.24 | 30.1 ms | 5.23x |
| `Enum.filter \|> Enum.sort \|> Enum.uniq \|> Enum.sum` | 6.35 | 157.6 ms | -- |

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

## How it works

FEnum has three input modes. The same function handles all three via pattern matching:

```elixir
FEnum.sort([3, 1, 2])             # List: uses NIF or delegates to Enum
FEnum.sort(<<_::binary>>)         # Binary: binary -> binary (near-zero copy to NIF)
FEnum.sort(%FEnum.Ref{} = ref)   # Chain: Ref -> Ref (data stays in Rust)
FEnum.sort(1..10)                 # Fallback: delegates to Enum
```

**Lists** go through Rustler's list protocol for expensive operations (sort, uniq, frequencies) where the Rust algorithm beats the BEAM despite the decode cost. Simple traversals (sum, min, max, reverse, member?) delegate straight to `Enum` because the BEAM's JIT is already optimal for single-pass operations.

**Packed binaries** (`<<i::signed-native-64>>` format) are passed to the NIF by reference with near-zero copy. This is the fastest path.

**Chain mode** converts once at the boundaries with `new/1` and `run/1`. Between those calls, data stays in a Rust `Vec<i64>` behind a `ResourceArc` -- no conversion overhead between operations.

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
