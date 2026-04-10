# Changelog

## v0.1.1

### True drop-in replacement for Enum

FEnum now delegates every `Enum` function, so `FEnum.X` works for any `X` that `Enum` supports. Functions without NIF acceleration transparently forward to `Enum`. Non-integer lists (strings, tuples, atoms) automatically fall back to `Enum` when the NIF can't handle them.

### Binary input support

All functions now accept packed binaries (`<<i::signed-native-64>>` format) in addition to lists and `FEnum.Ref`. When a binary is passed, it goes to the NIF by reference with near-zero copy -- no Rustler list protocol overhead. This is the fastest path:

- **sort**: 9.6x faster than Enum (binary) vs 5.7x (list)
- **uniq**: 38.9x faster than Enum (binary) vs 19.1x (list)
- **sum**: 18.4x faster than Enum (binary), delegates to Enum for lists
- **min/max**: 10.4x faster than Enum (binary), delegates to Enum for lists

### Rust NIF optimizations

- **Lock-free resource storage**: Replaced `RwLock<Vec<i64>>` with `Box<[i64]>`. The data is immutable after creation, so the atomic CAS on every read was pure overhead.
- **FxHash for uniq and frequencies**: Replaced std `HashMap`/`HashSet` (SipHash) with `rustc-hash` FxHash. 4x faster for uniq on lists, 6x on binaries.
- **Zero-copy binary reads**: Aggregations (sum, min, max, member?, etc.) no longer copy the binary into a Vec. They read the bytes in-place via a macro that reinterprets the binary pointer.
- **Custom Encoder for FrequencyMap**: Encodes directly to an Erlang map term via `Term::map_from_term_arrays`, skipping the O(n) FxHashMap-to-std-HashMap rehash conversion.
- **itoa for join**: Replaced `write!("{}", v)` formatting with the `itoa` crate for ~3x faster integer-to-string conversion.
- **Single-pass minmax**: One loop instead of separate `.min()` + `.max()` calls.
- **Cache-friendly reverse**: `memcpy` + in-place swap instead of backwards reads that cause prefetcher misses.
- **Pre-sized allocations**: `Vec::with_capacity`, `HashMap::with_capacity`, `String::with_capacity` throughout.
- **Raw pointer writes for with_index/zip**: Enables auto-vectorization by removing per-element capacity checks.
- **`get_unchecked` for at/zip**: Bounds already validated, so the redundant check is removed.
- **Cargo.toml**: `lto = "fat"`, `codegen-units = 1`, `panic = "abort"` for maximum link-time optimization.

### Elixir-side optimizations

- **Skip NIF calls for length-preserving chain ops**: `sort`, `reverse`, `concat`, `slice`, `take`, `drop` compute the output length from the input length in pure Elixir arithmetic instead of calling `nif_length`.
- **Pure Elixir binary operations**: `at`, `slice`, `take`, `drop`, `count`, `concat` for binaries use `binary_part`/pattern matching instead of NIF calls. O(1) sub-binary references with zero allocation.
- **Removed O(n) `length(list)` from `new/1`**: Uses `nif_length` (O(1) field read) instead.
- **Smart delegation**: Simple traversals (sum, min, max, reverse, member?, dedup) delegate to `Enum` for lists since the BEAM's JIT is already optimal. NIF path only activates for operations where Rust genuinely wins (sort, uniq, frequencies).

### Testing

- Full compatibility with Elixir v1.19's official Enum test suite (227 tests, 0 failures).
- 422 total tests across FEnum-specific and Enum compatibility suites.

## v0.1.0

Initial release with core FEnum functionality:

- One-shot mode (list in, list out) for sort, reverse, dedup, uniq, sum, product, min, max, min_max, count, at, fetch!, slice, take, drop, member?, empty?, concat, frequencies, join, with_index, zip, chunk_every, into.
- Chain mode via `FEnum.new/1` and `FEnum.run/1` keeping data in Rust between operations.
- Tier 2 hybrid functions (filter, reject, map, flat_map, reduce, map_reduce, scan, find, find_index, find_value, any?, all?, count/2, sort_by, each, group_by).
- Enumerable and Inspect protocol implementations for `FEnum.Ref`.
- Fallback to `Enum` for non-list enumerables.
