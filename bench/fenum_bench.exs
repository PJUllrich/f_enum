# FEnum Benchmark Suite
#
# Run all:        mix run bench/fenum_bench.exs
# Run specific:   mix run bench/fenum_bench.exs -- sort
#                 mix run bench/fenum_bench.exs -- chain
#                 mix run bench/fenum_bench.exs -- "sort" "uniq"
#                 mix run bench/fenum_bench.exs -- "filter placement"
#
# Filter matches against scenario names (case-insensitive substring match).

size = 1_000_000

IO.puts("Generating #{size} random integers...")
list = Enum.map(1..size, fn _ -> :rand.uniform(size) end)
sorted_list = Enum.sort(list)

binary = for i <- list, into: <<>>, do: <<i::signed-native-64>>
sorted_binary = for i <- sorted_list, into: <<>>, do: <<i::signed-native-64>>

IO.puts("Data ready: #{size} element list, #{byte_size(binary)} byte binary\n")

scenarios = %{
  # One-shot: sort
  "sort — Enum" => fn -> Enum.sort(list) end,
  "sort — FEnum (list)" => fn -> FEnum.sort(list) end,
  "sort — FEnum (binary)" => fn -> FEnum.sort(binary) end,

  # One-shot: sort desc
  "sort :desc — Enum" => fn -> Enum.sort(list, :desc) end,
  "sort :desc — FEnum (list)" => fn -> FEnum.sort(list, :desc) end,
  "sort :desc — FEnum (binary)" => fn -> FEnum.sort(binary, :desc) end,

  # One-shot: reverse
  "reverse — Enum" => fn -> Enum.reverse(list) end,
  "reverse — FEnum (list)" => fn -> FEnum.reverse(list) end,
  "reverse — FEnum (binary)" => fn -> FEnum.reverse(binary) end,

  # One-shot: dedup
  "dedup — Enum" => fn -> Enum.dedup(sorted_list) end,
  "dedup — FEnum (list)" => fn -> FEnum.dedup(sorted_list) end,
  "dedup — FEnum (binary)" => fn -> FEnum.dedup(sorted_binary) end,

  # One-shot: uniq
  "uniq — Enum" => fn -> Enum.uniq(list) end,
  "uniq — FEnum (list)" => fn -> FEnum.uniq(list) end,
  "uniq — FEnum (binary)" => fn -> FEnum.uniq(binary) end,

  # One-shot: sum
  "sum — Enum" => fn -> Enum.sum(list) end,
  "sum — FEnum (list)" => fn -> FEnum.sum(list) end,
  "sum — FEnum (binary)" => fn -> FEnum.sum(binary) end,

  # One-shot: min
  "min — Enum" => fn -> Enum.min(list) end,
  "min — FEnum (list)" => fn -> FEnum.min(list) end,
  "min — FEnum (binary)" => fn -> FEnum.min(binary) end,

  # One-shot: max
  "max — Enum" => fn -> Enum.max(list) end,
  "max — FEnum (list)" => fn -> FEnum.max(list) end,
  "max — FEnum (binary)" => fn -> FEnum.max(binary) end,

  # One-shot: member?
  "member? — Enum" => fn -> Enum.member?(list, -1) end,
  "member? — FEnum (list)" => fn -> FEnum.member?(list, -1) end,
  "member? — FEnum (binary)" => fn -> FEnum.member?(binary, -1) end,

  # One-shot: frequencies
  "frequencies — Enum" => fn -> Enum.frequencies(list) end,
  "frequencies — FEnum (list)" => fn -> FEnum.frequencies(list) end,
  "frequencies — FEnum (binary)" => fn -> FEnum.frequencies(binary) end,

  # Chain benchmarks
  "chain: sort+dedup+take — Enum" => fn ->
    list |> Enum.sort() |> Enum.dedup() |> Enum.take(100)
  end,
  "chain: sort+dedup+take — FEnum" => fn ->
    list |> FEnum.new() |> FEnum.sort() |> FEnum.dedup() |> FEnum.take(100) |> FEnum.run()
  end,
  "chain: sort+reverse+slice — Enum" => fn ->
    list |> Enum.sort() |> Enum.reverse() |> Enum.slice(0..99)
  end,
  "chain: sort+reverse+slice — FEnum" => fn ->
    list |> FEnum.new() |> FEnum.sort() |> FEnum.reverse() |> FEnum.slice(0..99) |> FEnum.run()
  end,
  "chain: sort+uniq+sum — Enum" => fn ->
    list |> Enum.sort() |> Enum.uniq() |> Enum.sum()
  end,
  "chain: sort+uniq+sum — FEnum" => fn ->
    list |> FEnum.new() |> FEnum.sort() |> FEnum.uniq() |> FEnum.sum()
  end,
  "chain: sort+dedup+freq — Enum" => fn ->
    list |> Enum.sort() |> Enum.dedup() |> Enum.frequencies()
  end,
  "chain: sort+dedup+freq — FEnum" => fn ->
    list |> FEnum.new() |> FEnum.sort() |> FEnum.dedup() |> FEnum.frequencies()
  end,

  # Filter placement
  "chain: filter+sort+uniq+sum — Enum" => fn ->
    list |> Enum.filter(&(&1 > div(size, 2))) |> Enum.sort() |> Enum.uniq() |> Enum.sum()
  end,
  "chain: filter+sort+uniq+sum — FEnum (filter before new)" => fn ->
    list
    |> Enum.filter(&(&1 > div(size, 2)))
    |> FEnum.new()
    |> FEnum.sort()
    |> FEnum.uniq()
    |> FEnum.sum()
  end,
  "chain: filter+sort+uniq+sum — FEnum (filter after new)" => fn ->
    list
    |> FEnum.new()
    |> FEnum.filter(&(&1 > div(size, 2)))
    |> FEnum.sort()
    |> FEnum.uniq()
    |> FEnum.sum()
  end
}

# ---------------------------------------------------------------------------
# Filter by CLI args if provided
# ---------------------------------------------------------------------------

filters = System.argv()

scenarios =
  if filters == [] do
    scenarios
  else
    filtered =
      Enum.filter(scenarios, fn {name, _} ->
        name_down = String.downcase(name)
        Enum.any?(filters, fn f -> String.contains?(name_down, String.downcase(f)) end)
      end)
      |> Map.new()

    if filtered == %{} do
      IO.puts("No scenarios matched: #{inspect(filters)}")
      IO.puts("\nAvailable scenarios:")
      scenarios |> Map.keys() |> Enum.sort() |> Enum.each(&IO.puts("  #{&1}"))
      System.halt(1)
    end

    IO.puts("Running #{map_size(filtered)} scenario(s):\n")
    filtered
  end

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

Benchee.run(
  scenarios,
  title: "FEnum Benchmarks (#{size} integers)",
  warmup: 1,
  time: 3,
  memory_time: 1,
  print: [configuration: true, benchmarking: true],
  formatters: [
    {Benchee.Formatters.Console, comparison: true, extended_statistics: false},
    {Benchee.Formatters.HTML, file: "bench/output/results.html", auto_open: false}
  ]
)

IO.puts("\nBenchmarks complete!")
