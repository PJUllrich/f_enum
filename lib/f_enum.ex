defmodule FEnum do
  @moduledoc """
  A drop-in replacement for `Enum` backed by Rust NIFs via Rustler.

  Operates on lists of integers (`i64`). Two API modes:

  1. **One-shot** -- same signatures as `Enum`. List in, list out.
  2. **Chain** -- data stays in Rust via `FEnum.Ref`. Convert once at
     the boundaries with `new/1` and `run/1`.

  All functions also accept packed binaries of native-endian signed 64-bit
  integers. When a binary is passed, it goes straight to the NIF by reference
  (near-zero copy) and the result stays as a binary — no conversion overhead.

  For non-integer-list enumerables, all functions fall back to `Enum`.
  """

  alias FEnum.{Native, Ref}

  # Exclude Kernel.max/2 and Kernel.min/2 so we can define our own max/2 and
  # min/2 that delegate to Enum (matching Enum's full API). The private helpers
  # below that need integer comparison use Kernel.max/Kernel.min explicitly.
  import Kernel, except: [max: 2, min: 2]

  # ---------------------------------------------------------------------------
  # Constructors / Terminators
  # ---------------------------------------------------------------------------

  @doc "Converts a list of integers (or packed i64 binary) into an `FEnum.Ref` for chain operations."
  @spec new(list(integer()) | binary()) :: Ref.t()
  def new(list) when is_list(list) do
    resource = Native.nif_new(list)
    %Ref{resource: resource, length: Native.nif_length(resource)}
  end

  def new(binary) when is_binary(binary) do
    resource = Native.nif_new_from_binary(binary)
    %Ref{resource: resource, length: div(byte_size(binary), 8)}
  end

  @doc "Materializes an `FEnum.Ref` back into a regular Elixir list."
  @spec run(Ref.t()) :: list(integer())
  def run(%Ref{resource: resource}), do: Native.nif_to_list(resource)

  @doc "Converts to a list. For `FEnum.Ref`, materializes from Rust. For other enumerables, delegates to `Enum.to_list/1`."
  @spec to_list(Ref.t() | Enumerable.t()) :: list()
  def to_list(%Ref{} = ref), do: run(ref)
  def to_list(enumerable), do: Enum.to_list(enumerable)

  # Helpers to wrap NIF results into a Ref.
  # Use wrap_ref_same_len when the operation preserves length (sort, reverse).
  # Use wrap_ref when the length may change (dedup, uniq, slice, take, drop).
  defp wrap_ref(resource) do
    %Ref{resource: resource, length: Native.nif_length(resource)}
  end

  defp wrap_ref_same_len(resource, len) do
    %Ref{resource: resource, length: len}
  end

  # ---------------------------------------------------------------------------
  # Sorting & Ordering
  # ---------------------------------------------------------------------------

  @doc "Sorts in ascending order."
  @spec sort(Ref.t() | list() | binary()) :: Ref.t() | list() | binary()
  def sort(%Ref{resource: r, length: len}), do: wrap_ref_same_len(Native.nif_sort_asc(r), len)
  def sort(bin) when is_binary(bin), do: Native.nif_sort_asc_binary(bin)
  def sort(list) when is_list(list) do
    Native.nif_sort_asc_list(list)
  rescue
    ArgumentError -> Enum.sort(list)
  end
  def sort(enumerable), do: Enum.sort(enumerable)

  @doc "Sorts in the given order (`:asc` or `:desc`)."
  @spec sort(Ref.t() | list() | binary(), :asc | :desc) :: Ref.t() | list() | binary()
  def sort(%Ref{resource: r, length: len}, :asc), do: wrap_ref_same_len(Native.nif_sort_asc(r), len)
  def sort(%Ref{resource: r, length: len}, :desc), do: wrap_ref_same_len(Native.nif_sort_desc(r), len)
  def sort(bin, :asc) when is_binary(bin), do: Native.nif_sort_asc_binary(bin)
  def sort(bin, :desc) when is_binary(bin), do: Native.nif_sort_desc_binary(bin)
  def sort(list, :asc) when is_list(list) do
    Native.nif_sort_asc_list(list)
  rescue
    ArgumentError -> Enum.sort(list, :asc)
  end

  def sort(list, :desc) when is_list(list) do
    Native.nif_sort_desc_list(list)
  rescue
    ArgumentError -> Enum.sort(list, :desc)
  end
  def sort(enumerable, order), do: Enum.sort(enumerable, order)

  @doc "Reverses the collection."
  @spec reverse(Ref.t() | list() | binary()) :: Ref.t() | list() | binary()
  def reverse(%Ref{resource: r, length: len}), do: wrap_ref_same_len(Native.nif_reverse(r), len)
  def reverse(bin) when is_binary(bin), do: Native.nif_reverse_binary(bin)
  def reverse(enumerable), do: Enum.reverse(enumerable)

  @doc "Removes consecutive duplicate elements."
  @spec dedup(Ref.t() | list() | binary()) :: Ref.t() | list() | binary()
  def dedup(%Ref{resource: r}), do: wrap_ref(Native.nif_dedup(r))
  def dedup(bin) when is_binary(bin), do: Native.nif_dedup_binary(bin)
  def dedup(enumerable), do: Enum.dedup(enumerable)

  @doc "Removes all duplicate elements, keeping first occurrence."
  @spec uniq(Ref.t() | list() | binary()) :: Ref.t() | list() | binary()
  def uniq(%Ref{resource: r}), do: wrap_ref(Native.nif_uniq(r))
  def uniq(bin) when is_binary(bin), do: Native.nif_uniq_binary(bin)
  def uniq(list) when is_list(list) do
    Native.nif_uniq_list(list)
  rescue
    ArgumentError -> Enum.uniq(list)
  end
  def uniq(enumerable), do: Enum.uniq(enumerable)

  # ---------------------------------------------------------------------------
  # Aggregation
  # ---------------------------------------------------------------------------

  @doc "Returns the sum of all elements."
  @spec sum(Ref.t() | list() | binary()) :: integer()
  def sum(%Ref{resource: r}), do: Native.nif_sum(r)
  def sum(bin) when is_binary(bin), do: Native.nif_sum_binary(bin)
  def sum(enumerable), do: Enum.sum(enumerable)

  @doc "Returns the product of all elements."
  @spec product(Ref.t() | list() | binary()) :: integer()
  def product(%Ref{resource: r}), do: Native.nif_product(r)
  def product(bin) when is_binary(bin), do: Native.nif_product_binary(bin)
  def product(enumerable), do: Enum.product(enumerable)

  @doc "Returns the minimum element. Raises `Enum.EmptyError` if empty."
  @spec min(Ref.t() | list() | binary()) :: integer()
  def min(%Ref{resource: r}), do: Native.nif_min(r) || raise(Enum.EmptyError)
  def min(bin) when is_binary(bin), do: Native.nif_min_binary(bin) || raise(Enum.EmptyError)
  def min(enumerable), do: Enum.min(enumerable)

  @doc "Returns the maximum element. Raises `Enum.EmptyError` if empty."
  @spec max(Ref.t() | list() | binary()) :: integer()
  def max(%Ref{resource: r}), do: Native.nif_max(r) || raise(Enum.EmptyError)
  def max(bin) when is_binary(bin), do: Native.nif_max_binary(bin) || raise(Enum.EmptyError)
  def max(enumerable), do: Enum.max(enumerable)

  @doc "Returns `{min, max}` tuple. Raises `Enum.EmptyError` if empty."
  @spec min_max(Ref.t() | list() | binary()) :: {integer(), integer()}
  def min_max(%Ref{resource: r}), do: Native.nif_min_max(r) || raise(Enum.EmptyError)
  def min_max(bin) when is_binary(bin), do: Native.nif_min_max_binary(bin) || raise(Enum.EmptyError)
  def min_max(enumerable), do: Enum.min_max(enumerable)

  @doc "Returns the count of elements."
  @spec count(Ref.t() | list() | binary()) :: non_neg_integer()
  def count(%Ref{length: len}), do: len
  def count(bin) when is_binary(bin), do: div(byte_size(bin), 8)
  def count(list) when is_list(list), do: length(list)
  def count(enumerable), do: Enum.count(enumerable)

  # ---------------------------------------------------------------------------
  # Access
  # ---------------------------------------------------------------------------

  @doc "Returns the element at `index`, or `nil` if out of bounds."
  @spec at(Ref.t() | list() | binary(), integer()) :: integer() | nil
  def at(%Ref{resource: r}, index), do: Native.nif_at(r, index)

  def at(bin, index) when is_binary(bin) and index >= 0 do
    offset = index * 8

    case bin do
      <<_::binary-size(offset), value::signed-native-64, _::binary>> -> value
      _ -> nil
    end
  end

  def at(bin, index) when is_binary(bin) do
    at(bin, div(byte_size(bin), 8) + index)
  end

  def at(enumerable, index), do: Enum.at(enumerable, index)

  @doc "Returns the element at `index`. Raises `Enum.OutOfBoundsError` if out of bounds."
  @spec fetch!(Ref.t() | list() | binary(), integer()) :: integer()
  def fetch!(%Ref{} = ref, index) do
    case at(ref, index) do
      nil -> raise Enum.OutOfBoundsError
      val -> val
    end
  end

  def fetch!(bin, index) when is_binary(bin) do
    case at(bin, index) do
      nil -> raise Enum.OutOfBoundsError
      val -> val
    end
  end

  def fetch!(enumerable, index), do: Enum.fetch!(enumerable, index)

  @doc "Returns a subset of the collection."
  @spec slice(Ref.t() | list() | binary(), Range.t()) :: Ref.t() | list() | binary()
  def slice(%Ref{resource: r, length: len}, first..last//step) do
    {start, count} = range_to_start_count(first, last, step, len)
    wrap_ref_same_len(Native.nif_slice(r, start, count), count)
  end

  def slice(bin, first..last//step) when is_binary(bin) do
    len = div(byte_size(bin), 8)
    {start, count} = range_to_start_count(first, last, step, len)
    binary_part(bin, start * 8, count * 8)
  end

  def slice(enumerable, range), do: Enum.slice(enumerable, range)

  defp range_to_start_count(first, last, _step, len) do
    first = if first < 0, do: Kernel.max(len + first, 0), else: first
    last = if last < 0, do: len + last, else: last
    count = Kernel.max(last - first + 1, 0)
    {first, count}
  end

  @doc "Takes `count` elements from the beginning (positive) or end (negative)."
  @spec take(Ref.t() | list() | binary(), integer()) :: Ref.t() | list() | binary()
  def take(%Ref{resource: r, length: len}, count) do
    out_len = Kernel.min(if(count >= 0, do: count, else: -count), len)
    wrap_ref_same_len(Native.nif_take(r, count), out_len)
  end

  def take(bin, count) when is_binary(bin) and count >= 0 do
    n = Kernel.min(count * 8, byte_size(bin))
    binary_part(bin, 0, n)
  end

  def take(bin, count) when is_binary(bin) do
    n = Kernel.min(-count * 8, byte_size(bin))
    binary_part(bin, byte_size(bin) - n, n)
  end

  def take(enumerable, count), do: Enum.take(enumerable, count)

  @doc "Drops `count` elements from the beginning (positive) or end (negative)."
  @spec drop(Ref.t() | list() | binary(), integer()) :: Ref.t() | list() | binary()
  def drop(%Ref{resource: r, length: len}, count) do
    out_len = Kernel.max(len - Kernel.min(if(count >= 0, do: count, else: -count), len), 0)
    wrap_ref_same_len(Native.nif_drop(r, count), out_len)
  end

  def drop(bin, count) when is_binary(bin) and count >= 0 do
    n = Kernel.min(count * 8, byte_size(bin))
    binary_part(bin, n, byte_size(bin) - n)
  end

  def drop(bin, count) when is_binary(bin) do
    n = Kernel.min(-count * 8, byte_size(bin))
    binary_part(bin, 0, byte_size(bin) - n)
  end

  def drop(enumerable, count), do: Enum.drop(enumerable, count)

  @doc "Checks if `value` exists in the collection."
  @spec member?(Ref.t() | list() | binary(), integer()) :: boolean()
  def member?(%Ref{resource: r}, value), do: Native.nif_member(r, value)
  def member?(bin, value) when is_binary(bin), do: Native.nif_member_binary(bin, value)
  def member?(enumerable, value), do: Enum.member?(enumerable, value)

  @doc "Returns `true` if the collection is empty."
  @spec empty?(Ref.t() | list() | binary()) :: boolean()
  def empty?(%Ref{length: 0}), do: true
  def empty?(%Ref{}), do: false
  def empty?(<<>>), do: true
  def empty?(bin) when is_binary(bin), do: false
  def empty?([]), do: true
  def empty?(list) when is_list(list), do: false
  def empty?(enumerable), do: Enum.empty?(enumerable)

  # ---------------------------------------------------------------------------
  # Combination & Transformation
  # ---------------------------------------------------------------------------

  @doc "Concatenates two collections."
  @spec concat(Ref.t() | list() | binary(), Ref.t() | list() | binary()) :: Ref.t() | list() | binary()
  def concat(%Ref{resource: r1, length: l1}, %Ref{resource: r2, length: l2}),
    do: wrap_ref_same_len(Native.nif_concat(r1, r2), l1 + l2)

  def concat(%Ref{} = ref, list) when is_list(list),
    do: concat(ref, new(list))

  def concat(list, %Ref{} = ref) when is_list(list),
    do: concat(new(list), ref)

  def concat(bin1, bin2) when is_binary(bin1) and is_binary(bin2),
    do: <<bin1::binary, bin2::binary>>

  def concat(list1, list2) when is_list(list1) and is_list(list2),
    do: list1 ++ list2

  def concat(enum1, enum2), do: Enum.concat(enum1, enum2)

  @doc "Returns a map with keys as unique elements and values as counts."
  @spec frequencies(Ref.t() | list() | binary()) :: map()
  def frequencies(%Ref{resource: r}), do: Native.nif_frequencies(r)
  def frequencies(bin) when is_binary(bin), do: Native.nif_frequencies_binary(bin)
  def frequencies(list) when is_list(list) do
    Native.nif_frequencies_list(list)
  rescue
    ArgumentError -> Enum.frequencies(list)
  end
  def frequencies(enumerable), do: Enum.frequencies(enumerable)

  @doc "Joins elements into a string with the given separator."
  @spec join(Ref.t() | list() | binary(), String.t()) :: String.t()
  def join(collection, joiner \\ "")
  def join(%Ref{resource: r}, joiner), do: Native.nif_join(r, joiner)
  def join(bin, joiner) when is_binary(bin), do: Native.nif_join_binary(bin, joiner)
  def join(enumerable, joiner), do: Enum.join(enumerable, joiner)

  @doc "Returns each element with its index as `{element, index}` tuples."
  @spec with_index(Ref.t() | list() | binary(), integer()) :: list({integer(), integer()})
  def with_index(collection, offset \\ 0)
  def with_index(%Ref{resource: r}, offset), do: Native.nif_with_index(r, offset)
  def with_index(bin, offset) when is_binary(bin), do: Native.nif_with_index_binary(bin, offset)
  def with_index(enumerable, offset), do: Enum.with_index(enumerable, offset)

  @doc "Zips two collections into a list of `{a, b}` tuples."
  @spec zip(Ref.t() | list() | binary(), Ref.t() | list() | binary()) :: list({integer(), integer()})
  def zip(%Ref{resource: r1}, %Ref{resource: r2}), do: Native.nif_zip(r1, r2)

  def zip(%Ref{} = ref, list) when is_list(list),
    do: zip(ref, new(list))

  def zip(list, %Ref{} = ref) when is_list(list),
    do: zip(new(list), ref)

  def zip(bin1, bin2) when is_binary(bin1) and is_binary(bin2),
    do: Native.nif_zip_binary(bin1, bin2)

  def zip(enum1, enum2), do: Enum.zip(enum1, enum2)

  @doc "Splits the collection into chunks of `count` elements."
  @spec chunk_every(Ref.t() | list() | binary(), pos_integer()) :: list(list())
  def chunk_every(%Ref{resource: r}, count), do: Native.nif_chunk_every(r, count)
  def chunk_every(bin, count) when is_binary(bin), do: Native.nif_chunk_every_binary(bin, count)
  def chunk_every(enumerable, count), do: Enum.chunk_every(enumerable, count)

  @doc "Inserts the given collection into the given collectable."
  @spec into(Ref.t() | list(), Collectable.t()) :: Collectable.t()
  def into(%Ref{} = ref, collectable), do: Enum.into(run(ref), collectable)
  def into(list, collectable) when is_list(list), do: Enum.into(list, collectable)
  def into(enumerable, collectable), do: Enum.into(enumerable, collectable)

  # ---------------------------------------------------------------------------
  # Tier 2: Hybrid NIF + Callback
  # ---------------------------------------------------------------------------

  @doc "Filters elements by the given function."
  @spec filter(Ref.t() | list(), (integer() -> boolean())) :: Ref.t() | list()
  def filter(%Ref{} = ref, fun), do: ref |> run() |> Enum.filter(fun) |> new()
  def filter(list, fun) when is_list(list), do: Enum.filter(list, fun)
  def filter(enumerable, fun), do: Enum.filter(enumerable, fun)

  @doc "Rejects elements for which `fun` returns a truthy value."
  @spec reject(Ref.t() | list(), (integer() -> boolean())) :: Ref.t() | list()
  def reject(%Ref{} = ref, fun), do: ref |> run() |> Enum.reject(fun) |> new()
  def reject(list, fun) when is_list(list), do: Enum.reject(list, fun)
  def reject(enumerable, fun), do: Enum.reject(enumerable, fun)

  @doc "Maps each element with the given function."
  @spec map(Ref.t() | list(), (integer() -> integer())) :: Ref.t() | list()
  def map(%Ref{} = ref, fun), do: ref |> run() |> Enum.map(fun) |> new()
  def map(list, fun) when is_list(list), do: Enum.map(list, fun)
  def map(enumerable, fun), do: Enum.map(enumerable, fun)

  @doc "Maps and flattens the result."
  @spec flat_map(Ref.t() | list(), (integer() -> list())) :: Ref.t() | list()
  def flat_map(%Ref{} = ref, fun), do: ref |> run() |> Enum.flat_map(fun) |> new()
  def flat_map(list, fun) when is_list(list), do: Enum.flat_map(list, fun)
  def flat_map(enumerable, fun), do: Enum.flat_map(enumerable, fun)

  @doc "Reduces the collection with an accumulator."
  @spec reduce(Ref.t() | list(), term(), (integer(), term() -> term())) :: term()
  def reduce(%Ref{} = ref, acc, fun), do: ref |> run() |> Enum.reduce(acc, fun)
  def reduce(list, acc, fun) when is_list(list), do: Enum.reduce(list, acc, fun)
  def reduce(enumerable, acc, fun), do: Enum.reduce(enumerable, acc, fun)

  @doc "Applies `fun` to each element, accumulating results and a final accumulator."
  @spec map_reduce(Ref.t() | list(), term(), (integer(), term() -> {term(), term()})) :: {list(), term()}
  def map_reduce(%Ref{} = ref, acc, fun), do: ref |> run() |> Enum.map_reduce(acc, fun)
  def map_reduce(list, acc, fun) when is_list(list), do: Enum.map_reduce(list, acc, fun)
  def map_reduce(enumerable, acc, fun), do: Enum.map_reduce(enumerable, acc, fun)

  @doc "Applies `fun` to each element, returning running accumulation."
  @spec scan(Ref.t() | list(), (integer(), integer() -> integer())) :: Ref.t() | list()
  def scan(%Ref{} = ref, fun), do: ref |> run() |> Enum.scan(fun) |> new()
  def scan(list, fun) when is_list(list), do: Enum.scan(list, fun)
  def scan(enumerable, fun), do: Enum.scan(enumerable, fun)

  @doc "Finds the first element for which `fun` returns a truthy value."
  @spec find(Ref.t() | list(), (integer() -> boolean())) :: integer() | nil
  def find(%Ref{} = ref, fun), do: ref |> run() |> Enum.find(fun)
  def find(list, fun) when is_list(list), do: Enum.find(list, fun)
  def find(enumerable, fun), do: Enum.find(enumerable, fun)

  @doc "Returns the index of the first element for which `fun` returns a truthy value."
  @spec find_index(Ref.t() | list(), (integer() -> boolean())) :: non_neg_integer() | nil
  def find_index(%Ref{} = ref, fun), do: ref |> run() |> Enum.find_index(fun)
  def find_index(list, fun) when is_list(list), do: Enum.find_index(list, fun)
  def find_index(enumerable, fun), do: Enum.find_index(enumerable, fun)

  @doc "Returns the first truthy value returned by `fun`."
  @spec find_value(Ref.t() | list(), (integer() -> term())) :: term() | nil
  def find_value(%Ref{} = ref, fun), do: ref |> run() |> Enum.find_value(fun)
  def find_value(list, fun) when is_list(list), do: Enum.find_value(list, fun)
  def find_value(enumerable, fun), do: Enum.find_value(enumerable, fun)

  @doc "Returns `true` if `fun` returns a truthy value for any element."
  @spec any?(Ref.t() | list(), (integer() -> boolean())) :: boolean()
  def any?(%Ref{} = ref, fun), do: ref |> run() |> Enum.any?(fun)
  def any?(list, fun) when is_list(list), do: Enum.any?(list, fun)
  def any?(enumerable, fun), do: Enum.any?(enumerable, fun)

  @doc "Returns `true` if `fun` returns a truthy value for all elements."
  @spec all?(Ref.t() | list(), (integer() -> boolean())) :: boolean()
  def all?(%Ref{} = ref, fun), do: ref |> run() |> Enum.all?(fun)
  def all?(list, fun) when is_list(list), do: Enum.all?(list, fun)
  def all?(enumerable, fun), do: Enum.all?(enumerable, fun)

  @doc "Counts elements for which `fun` returns a truthy value."
  @spec count(Ref.t() | list(), (integer() -> boolean())) :: non_neg_integer()
  def count(%Ref{} = ref, fun), do: ref |> run() |> Enum.count(fun)
  def count(list, fun) when is_list(list), do: Enum.count(list, fun)
  def count(enumerable, fun), do: Enum.count(enumerable, fun)

  @doc "Sorts by the result of applying `fun` to each element."
  @spec sort_by(Ref.t() | list(), (integer() -> term())) :: Ref.t() | list()
  def sort_by(%Ref{} = ref, fun), do: ref |> run() |> Enum.sort_by(fun) |> new()
  def sort_by(list, fun) when is_list(list), do: Enum.sort_by(list, fun)
  def sort_by(enumerable, fun), do: Enum.sort_by(enumerable, fun)

  @doc "Invokes `fun` for each element (side effects only). Returns `:ok`."
  @spec each(Ref.t() | list(), (integer() -> term())) :: :ok
  def each(%Ref{} = ref, fun), do: ref |> run() |> Enum.each(fun)
  def each(list, fun) when is_list(list), do: Enum.each(list, fun)
  def each(enumerable, fun), do: Enum.each(enumerable, fun)

  @doc "Groups elements by the result of `fun`."
  @spec group_by(Ref.t() | list(), (integer() -> term())) :: map()
  def group_by(%Ref{} = ref, fun), do: ref |> run() |> Enum.group_by(fun)
  def group_by(list, fun) when is_list(list), do: Enum.group_by(list, fun)
  def group_by(enumerable, fun), do: Enum.group_by(enumerable, fun)

  # ---------------------------------------------------------------------------
  # Delegated to Enum (full API compatibility)
  # ---------------------------------------------------------------------------

  @doc "Returns `true` if all elements are truthy."
  defdelegate all?(enumerable), to: Enum

  @doc "Returns `true` if any element is truthy."
  defdelegate any?(enumerable), to: Enum

  @doc "Returns the element at `index`, or `default` if out of bounds."
  defdelegate at(enumerable, index, default), to: Enum

  @doc "Splits the collection into chunks based on `fun` return value changes."
  defdelegate chunk_by(enumerable, fun), to: Enum

  @doc "Splits into chunks of `count` with `step` stride."
  defdelegate chunk_every(enumerable, count, step), to: Enum

  @doc "Splits into chunks of `count` with `step` stride and optional leftover padding."
  defdelegate chunk_every(enumerable, count, step, leftover), to: Enum

  @doc "Chunks the enumerable with before/after callbacks."
  defdelegate chunk_while(enumerable, acc, chunk_fun, after_fun), to: Enum

  @doc "Concatenates a list of enumerables into one list."
  defdelegate concat(enumerables), to: Enum

  @doc "Counts elements up to `limit`."
  defdelegate count_until(enumerable, limit), to: Enum

  @doc "Counts elements satisfying `fun` up to `limit`."
  defdelegate count_until(enumerable, fun, limit), to: Enum

  @doc "Removes consecutive duplicate elements as determined by `fun`."
  defdelegate dedup_by(enumerable, fun), to: Enum

  @doc "Drops every `nth` element."
  defdelegate drop_every(enumerable, nth), to: Enum

  @doc "Drops elements while `fun` returns a truthy value."
  defdelegate drop_while(enumerable, fun), to: Enum

  @doc "Returns `{:ok, element}` or `:error` for the element at `index`."
  defdelegate fetch(enumerable, index), to: Enum

  @doc "Finds the first element for which `fun` returns truthy, or `default`."
  defdelegate find(enumerable, default, fun), to: Enum

  @doc "Returns the first truthy value returned by `fun`, or `default`."
  defdelegate find_value(enumerable, default, fun), to: Enum

  @doc "Maps and reduces simultaneously, returning `{mapped_list, acc}`."
  defdelegate flat_map_reduce(enumerable, acc, fun), to: Enum

  @doc "Returns a map with keys from `key_fun` and values as counts."
  defdelegate frequencies_by(enumerable, key_fun), to: Enum

  @doc "Groups elements by `key_fun`, mapping values with `value_fun`."
  defdelegate group_by(enumerable, key_fun, value_fun), to: Enum

  @doc "Intersperses `separator` between each element."
  defdelegate intersperse(enumerable, separator), to: Enum

  @doc "Inserts each element of `enumerable` into `collectable` via `transform`."
  defdelegate into(enumerable, collectable, transform), to: Enum

  @doc "Maps every `nth` element with `fun`, passing others through unchanged."
  defdelegate map_every(enumerable, nth, fun), to: Enum

  @doc "Maps each element with `fun` and intersperses `separator` between results."
  defdelegate map_intersperse(enumerable, separator, mapper), to: Enum

  @doc "Maps each element with `mapper` and joins the result with default separator."
  defdelegate map_join(enumerable, mapper), to: Enum

  @doc "Maps each element with `mapper` and joins the result with `joiner`."
  defdelegate map_join(enumerable, joiner, mapper), to: Enum

  @doc "Returns the maximum element using `empty_fallback` if empty."
  def max(enumerable, empty_fallback), do: Enum.max(enumerable, empty_fallback)

  @doc "Returns the maximum element using `sorter` and `empty_fallback`."
  def max(enumerable, sorter, empty_fallback), do: Enum.max(enumerable, sorter, empty_fallback)

  @doc "Returns the element for which `fun` returns the largest value."
  defdelegate max_by(enumerable, fun), to: Enum

  @doc "Returns the element for which `fun` returns the largest value, using `sorter`."
  defdelegate max_by(enumerable, fun, sorter), to: Enum

  @doc "Returns the element for which `fun` returns the largest value, using `sorter` and `empty_fallback`."
  defdelegate max_by(enumerable, fun, sorter, empty_fallback), to: Enum

  @doc "Returns the minimum element using `empty_fallback` if empty."
  def min(enumerable, empty_fallback), do: Enum.min(enumerable, empty_fallback)

  @doc "Returns the minimum element using `sorter` and `empty_fallback`."
  def min(enumerable, sorter, empty_fallback), do: Enum.min(enumerable, sorter, empty_fallback)

  @doc "Returns the element for which `fun` returns the smallest value."
  defdelegate min_by(enumerable, fun), to: Enum

  @doc "Returns the element for which `fun` returns the smallest value, using `sorter`."
  defdelegate min_by(enumerable, fun, sorter), to: Enum

  @doc "Returns the element for which `fun` returns the smallest value, using `sorter` and `empty_fallback`."
  defdelegate min_by(enumerable, fun, sorter, empty_fallback), to: Enum

  @doc "Returns `{min, max}` tuple using `empty_fallback` if empty."
  defdelegate min_max(enumerable, empty_fallback), to: Enum

  @doc "Returns `{min_element, max_element}` where min/max are determined by `fun`."
  defdelegate min_max_by(enumerable, fun), to: Enum

  @doc "Returns `{min_element, max_element}` using `sorter`."
  defdelegate min_max_by(enumerable, fun, sorter), to: Enum

  @doc "Returns `{min_element, max_element}` using `sorter` and `empty_fallback`."
  defdelegate min_max_by(enumerable, fun, sorter, empty_fallback), to: Enum

  @doc "Returns the product of elements mapped through `fun`."
  defdelegate product_by(enumerable, fun), to: Enum

  @doc "Returns a random element from the enumerable."
  defdelegate random(enumerable), to: Enum

  @doc "Reduces the collection without an initial accumulator."
  defdelegate reduce(enumerable, fun), to: Enum

  @doc "Reduces while `fun` returns `{:cont, acc}`; stops on `{:halt, acc}`."
  defdelegate reduce_while(enumerable, acc, fun), to: Enum

  @doc "Reverses the collection, appending `tail` at the end."
  defdelegate reverse(enumerable, tail), to: Enum

  @doc "Reverses `count` elements starting at `start_index`."
  defdelegate reverse_slice(enumerable, start_index, count), to: Enum

  @doc "Applies running accumulation with `fun` starting from `acc`."
  defdelegate scan(enumerable, acc, fun), to: Enum

  @doc "Returns a shuffled list of the enumerable."
  defdelegate shuffle(enumerable), to: Enum

  @doc "Returns a subset starting at `start_index` for `amount` elements."
  defdelegate slice(enumerable, start_index, amount), to: Enum

  @doc "Moves elements at `range_or_single_index` to `insertion_index`."
  defdelegate slide(enumerable, range_or_single_index, insertion_index), to: Enum

  @doc "Sorts using the given `sorter` function."
  defdelegate sort_by(enumerable, mapper, sorter), to: Enum

  @doc "Splits into two lists at position `count`."
  defdelegate split(enumerable, count), to: Enum

  @doc "Splits into two lists at the first element for which `fun` returns false."
  defdelegate split_while(enumerable, fun), to: Enum

  @doc "Splits into `{truthy, falsy}` lists based on `fun`."
  defdelegate split_with(enumerable, fun), to: Enum

  @doc "Returns the sum of elements mapped through `fun`."
  defdelegate sum_by(enumerable, fun), to: Enum

  @doc "Takes every `nth` element."
  defdelegate take_every(enumerable, nth), to: Enum

  @doc "Takes `count` random elements from the enumerable."
  defdelegate take_random(enumerable, count), to: Enum

  @doc "Takes elements while `fun` returns a truthy value."
  defdelegate take_while(enumerable, fun), to: Enum

  @doc "Removes duplicate elements as determined by `fun`."
  defdelegate uniq_by(enumerable, fun), to: Enum

  @doc "Unzips a list of `{a, b}` tuples into `{[a], [b]}`."
  defdelegate unzip(enumerable), to: Enum

  @doc "Zips corresponding elements of a list of enumerables into tuples."
  defdelegate zip(enumerables), to: Enum

  @doc "Reduces over zipped enumerables with accumulator `acc`."
  defdelegate zip_reduce(enumerables, acc, fun), to: Enum

  @doc "Reduces over two enumerables zipped together with accumulator `acc`."
  defdelegate zip_reduce(left, right, acc, fun), to: Enum

  @doc "Zips enumerables and maps each tuple with `zip_fun`."
  defdelegate zip_with(enumerables, zip_fun), to: Enum

  @doc "Zips two enumerables and maps each pair with `zip_fun`."
  defdelegate zip_with(enumerable1, enumerable2, zip_fun), to: Enum
end
