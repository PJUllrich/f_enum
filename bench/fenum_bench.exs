# FEnum Benchmark Suite
#
# Run all:        mix run bench/fenum_bench.exs
# Run specific:   mix run bench/fenum_bench.exs -- sort
#                 mix run bench/fenum_bench.exs -- chain
#                 mix run bench/fenum_bench.exs -- "sort" "uniq"
#                 mix run bench/fenum_bench.exs -- "filter placement"
#
# Filter matches against group titles (case-insensitive substring match).
#
# Each iteration receives a freshly generated random list via before_each
# to prevent any result caching across iterations.

size = 1_000_000
# Number of elements to randomize each iteration to prevent caching
jitter = 1_000

IO.puts("Generating #{size} random integers (#{jitter} elements refreshed each iteration)...")
base_tail = Enum.map(1..(size - jitter), fn _ -> :rand.uniform(size) end)
IO.puts("Data ready.\n")

gen_data = fn _ ->
  # Prepend fresh random values to the static tail — O(jitter) via cons
  list = Enum.reduce(1..jitter, base_tail, fn _, acc -> [:rand.uniform(size) | acc] end)
  sorted_list = Enum.sort(list)
  binary = for i <- list, into: <<>>, do: <<i::signed-native-64>>
  sorted_binary = for i <- sorted_list, into: <<>>, do: <<i::signed-native-64>>
  %{list: list, sorted_list: sorted_list, binary: binary, sorted_binary: sorted_binary}
end

# ---------------------------------------------------------------------------
# Define benchmarks — grouped so Benchee compares Enum vs FEnum per function
# ---------------------------------------------------------------------------

benchmarks = [
  {"sort",
   %{
     "Enum" => fn %{list: list} -> Enum.sort(list) end,
     "FEnum (list)" => fn %{list: list} -> FEnum.sort(list) end,
     "FEnum (binary)" => fn %{binary: binary} -> FEnum.sort(binary) end
   }},
  {"sort :desc",
   %{
     "Enum" => fn %{list: list} -> Enum.sort(list, :desc) end,
     "FEnum (list)" => fn %{list: list} -> FEnum.sort(list, :desc) end,
     "FEnum (binary)" => fn %{binary: binary} -> FEnum.sort(binary, :desc) end
   }},
  {"reverse",
   %{
     "Enum" => fn %{list: list} -> Enum.reverse(list) end,
     "FEnum (list)" => fn %{list: list} -> FEnum.reverse(list) end,
     "FEnum (binary)" => fn %{binary: binary} -> FEnum.reverse(binary) end
   }},
  {"dedup",
   %{
     "Enum" => fn %{sorted_list: sorted_list} -> Enum.dedup(sorted_list) end,
     "FEnum (list)" => fn %{sorted_list: sorted_list} -> FEnum.dedup(sorted_list) end,
     "FEnum (binary)" => fn %{sorted_binary: sorted_binary} -> FEnum.dedup(sorted_binary) end
   }},
  {"uniq",
   %{
     "Enum" => fn %{list: list} -> Enum.uniq(list) end,
     "FEnum (list)" => fn %{list: list} -> FEnum.uniq(list) end,
     "FEnum (binary)" => fn %{binary: binary} -> FEnum.uniq(binary) end
   }},
  {"sum",
   %{
     "Enum" => fn %{list: list} -> Enum.sum(list) end,
     "FEnum (list)" => fn %{list: list} -> FEnum.sum(list) end,
     "FEnum (binary)" => fn %{binary: binary} -> FEnum.sum(binary) end
   }},
  {"min",
   %{
     "Enum" => fn %{list: list} -> Enum.min(list) end,
     "FEnum (list)" => fn %{list: list} -> FEnum.min(list) end,
     "FEnum (binary)" => fn %{binary: binary} -> FEnum.min(binary) end
   }},
  {"max",
   %{
     "Enum" => fn %{list: list} -> Enum.max(list) end,
     "FEnum (list)" => fn %{list: list} -> FEnum.max(list) end,
     "FEnum (binary)" => fn %{binary: binary} -> FEnum.max(binary) end
   }},
  {"member?",
   %{
     "Enum" => fn %{list: list} -> Enum.member?(list, -1) end,
     "FEnum (list)" => fn %{list: list} -> FEnum.member?(list, -1) end,
     "FEnum (binary)" => fn %{binary: binary} -> FEnum.member?(binary, -1) end
   }},
  {"frequencies",
   %{
     "Enum" => fn %{list: list} -> Enum.frequencies(list) end,
     "FEnum (list)" => fn %{list: list} -> FEnum.frequencies(list) end,
     "FEnum (binary)" => fn %{binary: binary} -> FEnum.frequencies(binary) end
   }},
  {"chain: sort+dedup+take",
   %{
     "Enum" => fn %{list: list} ->
       list |> Enum.sort() |> Enum.dedup() |> Enum.take(100)
     end,
     "FEnum" => fn %{list: list} ->
       list |> FEnum.new() |> FEnum.sort() |> FEnum.dedup() |> FEnum.take(100) |> FEnum.run()
     end
   }},
  {"chain: sort+reverse+slice",
   %{
     "Enum" => fn %{list: list} ->
       list |> Enum.sort() |> Enum.reverse() |> Enum.slice(0..99)
     end,
     "FEnum" => fn %{list: list} ->
       list |> FEnum.new() |> FEnum.sort() |> FEnum.reverse() |> FEnum.slice(0..99) |> FEnum.run()
     end
   }},
  {"chain: sort+uniq+sum",
   %{
     "Enum" => fn %{list: list} ->
       list |> Enum.sort() |> Enum.uniq() |> Enum.sum()
     end,
     "FEnum" => fn %{list: list} ->
       list |> FEnum.new() |> FEnum.sort() |> FEnum.uniq() |> FEnum.sum()
     end
   }},
  {"chain: sort+dedup+freq",
   %{
     "Enum" => fn %{list: list} ->
       list |> Enum.sort() |> Enum.dedup() |> Enum.frequencies()
     end,
     "FEnum" => fn %{list: list} ->
       list |> FEnum.new() |> FEnum.sort() |> FEnum.dedup() |> FEnum.frequencies()
     end
   }},
  {"chain: filter+sort+uniq+sum",
   %{
     "Enum" => fn %{list: list} ->
       list |> Enum.filter(&(&1 > div(size, 2))) |> Enum.sort() |> Enum.uniq() |> Enum.sum()
     end,
     "FEnum (filter before new)" => fn %{list: list} ->
       list
       |> Enum.filter(&(&1 > div(size, 2)))
       |> FEnum.new()
       |> FEnum.sort()
       |> FEnum.uniq()
       |> FEnum.sum()
     end,
     "FEnum (filter after new)" => fn %{list: list} ->
       list
       |> FEnum.new()
       |> FEnum.filter(&(&1 > div(size, 2)))
       |> FEnum.sort()
       |> FEnum.uniq()
       |> FEnum.sum()
     end
   }}
]

# ---------------------------------------------------------------------------
# Filter by CLI args if provided
# ---------------------------------------------------------------------------

filters = System.argv()

benchmarks =
  if filters == [] do
    benchmarks
  else
    filtered =
      Enum.filter(benchmarks, fn {title, _} ->
        title_down = String.downcase(title)
        Enum.any?(filters, fn f -> String.contains?(title_down, String.downcase(f)) end)
      end)

    if filtered == [] do
      IO.puts("No benchmarks matched: #{inspect(filters)}")
      IO.puts("\nAvailable benchmarks:")
      Enum.each(benchmarks, fn {title, _} -> IO.puts("  #{title}") end)
      System.halt(1)
    end

    IO.puts("Running #{length(filtered)} benchmark(s):\n")
    filtered
  end

# ---------------------------------------------------------------------------
# Run — one Benchee.run per group for proper Enum vs FEnum comparisons
# ---------------------------------------------------------------------------

Enum.each(benchmarks, fn {title, scenarios} ->
  slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_") |> String.trim("_")

  Benchee.run(
    scenarios,
    title: "#{title} (#{size} integers)",
    warmup: 1,
    time: 3,
    memory_time: 1,
    before_each: gen_data,
    print: [configuration: false, benchmarking: true],
    formatters: [
      {Benchee.Formatters.Console, comparison: true, extended_statistics: false},
      {Benchee.Formatters.HTML, file: "bench/output/#{slug}/results.html", auto_open: false}
    ]
  )
end)

IO.puts("\nBenchmarks complete!")
