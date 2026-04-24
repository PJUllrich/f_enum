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

  def sort(list) when is_list(list), do: Native.nif_sort_asc_list(list)
  def sort(list), do: Enum.sort(list)

  @doc "Sorts in the given order (`:asc` or `:desc`)."
  @spec sort(Ref.t() | list() | binary(), :asc | :desc) :: Ref.t() | list() | binary()
  def sort(%Ref{resource: r, length: len}, :asc),
    do: wrap_ref_same_len(Native.nif_sort_asc(r), len)

  def sort(%Ref{resource: r, length: len}, :desc),
    do: wrap_ref_same_len(Native.nif_sort_desc(r), len)

  def sort(bin, :asc) when is_binary(bin), do: Native.nif_sort_asc_binary(bin)
  def sort(bin, :desc) when is_binary(bin), do: Native.nif_sort_desc_binary(bin)

  def sort(list, :asc) when is_list(list), do: Native.nif_sort_asc_list(list)
  def sort(list, :desc) when is_list(list), do: Native.nif_sort_desc_list(list)

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

  def uniq(list) when is_list(list), do: Native.nif_uniq_list(list)
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

  def min_max(bin) when is_binary(bin),
    do: Native.nif_min_max_binary(bin) || raise(Enum.EmptyError)

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
  @spec concat(Ref.t() | list() | binary(), Ref.t() | list() | binary()) ::
          Ref.t() | list() | binary()
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
  @spec zip(Ref.t() | list() | binary(), Ref.t() | list() | binary()) ::
          list({integer(), integer()})
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
end
