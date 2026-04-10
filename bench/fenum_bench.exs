# FEnum Benchmark Suite
#
# Run all:        mix run bench/fenum_bench.exs
# Run specific:   mix run bench/fenum_bench.exs -- sort
#                 mix run bench/fenum_bench.exs -- chain
#                 mix run bench/fenum_bench.exs -- "sort" "uniq"
#                 mix run bench/fenum_bench.exs -- "filter placement"
#
# Filter matches against benchmark titles (case-insensitive substring match).

size = 1_000_000

IO.puts("Generating #{size} random integers...")
list = Enum.map(1..size, fn _ -> :rand.uniform(size) end)
sorted_list = Enum.sort(list)

binary = for i <- list, into: <<>>, do: <<i::signed-native-64>>
sorted_binary = for i <- sorted_list, into: <<>>, do: <<i::signed-native-64>>

IO.puts("Data ready: #{size} element list, #{byte_size(binary)} byte binary\n")

# Common Benchee options: suppress verbose output
opts = [
  warmup: 1,
  time: 3,
  memory_time: 1,
  print: [configuration: false, benchmarking: false],
  formatters: [
    {Benchee.Formatters.Console, comparison: true, extended_statistics: false},
    {Benchee.Formatters.HTML, file: "bench/output/results.html", auto_open: false}
  ]
]

# ---------------------------------------------------------------------------
# Define all benchmarks as {title, scenarios} tuples
# ---------------------------------------------------------------------------

benchmarks = [
  {"sort (#{size} integers)",
   %{
     "Enum.sort/1" => fn -> Enum.sort(list) end,
     "FEnum.sort/1 (list)" => fn -> FEnum.sort(list) end,
     "FEnum.sort/1 (binary)" => fn -> FEnum.sort(binary) end
   }},
  {"sort :desc (#{size} integers)",
   %{
     "Enum.sort/desc" => fn -> Enum.sort(list, :desc) end,
     "FEnum.sort/desc (list)" => fn -> FEnum.sort(list, :desc) end,
     "FEnum.sort/desc (binary)" => fn -> FEnum.sort(binary, :desc) end
   }},
  {"reverse (#{size} integers)",
   %{
     "Enum.reverse/1" => fn -> Enum.reverse(list) end,
     "FEnum.reverse/1 (list)" => fn -> FEnum.reverse(list) end,
     "FEnum.reverse/1 (binary)" => fn -> FEnum.reverse(binary) end
   }},
  {"dedup (#{size} sorted integers)",
   %{
     "Enum.dedup/1" => fn -> Enum.dedup(sorted_list) end,
     "FEnum.dedup/1 (list)" => fn -> FEnum.dedup(sorted_list) end,
     "FEnum.dedup/1 (binary)" => fn -> FEnum.dedup(sorted_binary) end
   }},
  {"uniq (#{size} integers)",
   %{
     "Enum.uniq/1" => fn -> Enum.uniq(list) end,
     "FEnum.uniq/1 (list)" => fn -> FEnum.uniq(list) end,
     "FEnum.uniq/1 (binary)" => fn -> FEnum.uniq(binary) end
   }},
  {"sum (#{size} integers)",
   %{
     "Enum.sum/1" => fn -> Enum.sum(list) end,
     "FEnum.sum/1 (list)" => fn -> FEnum.sum(list) end,
     "FEnum.sum/1 (binary)" => fn -> FEnum.sum(binary) end
   }},
  {"min (#{size} integers)",
   %{
     "Enum.min/1" => fn -> Enum.min(list) end,
     "FEnum.min/1 (list)" => fn -> FEnum.min(list) end,
     "FEnum.min/1 (binary)" => fn -> FEnum.min(binary) end
   }},
  {"max (#{size} integers)",
   %{
     "Enum.max/1" => fn -> Enum.max(list) end,
     "FEnum.max/1 (list)" => fn -> FEnum.max(list) end,
     "FEnum.max/1 (binary)" => fn -> FEnum.max(binary) end
   }},
  {"member? worst case (#{size} integers)",
   %{
     "Enum.member?/2 (worst)" => fn -> Enum.member?(list, -1) end,
     "FEnum.member?/2 (list)" => fn -> FEnum.member?(list, -1) end,
     "FEnum.member?/2 (binary)" => fn -> FEnum.member?(binary, -1) end
   }},
  {"frequencies (#{size} integers)",
   %{
     "Enum.frequencies/1" => fn -> Enum.frequencies(list) end,
     "FEnum.frequencies/1 (list)" => fn -> FEnum.frequencies(list) end,
     "FEnum.frequencies/1 (binary)" => fn -> FEnum.frequencies(binary) end
   }},

  # Chain benchmarks
  {"Chain: sort + dedup + take(100)",
   %{
     "Enum pipeline (sort+dedup+take)" => fn ->
       list |> Enum.sort() |> Enum.dedup() |> Enum.take(100)
     end,
     "FEnum chain (sort+dedup+take)" => fn ->
       list |> FEnum.new() |> FEnum.sort() |> FEnum.dedup() |> FEnum.take(100) |> FEnum.run()
     end
   }},
  {"Chain: sort + reverse + slice(0..99)",
   %{
     "Enum pipeline (sort+reverse+slice)" => fn ->
       list |> Enum.sort() |> Enum.reverse() |> Enum.slice(0..99)
     end,
     "FEnum chain (sort+reverse+slice)" => fn ->
       list |> FEnum.new() |> FEnum.sort() |> FEnum.reverse() |> FEnum.slice(0..99) |> FEnum.run()
     end
   }},
  {"Chain: sort + uniq + sum",
   %{
     "Enum pipeline (sort+uniq+sum)" => fn ->
       list |> Enum.sort() |> Enum.uniq() |> Enum.sum()
     end,
     "FEnum chain (sort+uniq+sum)" => fn ->
       list |> FEnum.new() |> FEnum.sort() |> FEnum.uniq() |> FEnum.sum()
     end
   }},
  {"Chain: sort + dedup + frequencies",
   %{
     "Enum pipeline (sort+dedup+frequencies)" => fn ->
       list |> Enum.sort() |> Enum.dedup() |> Enum.frequencies()
     end,
     "FEnum chain (sort+dedup+frequencies)" => fn ->
       list |> FEnum.new() |> FEnum.sort() |> FEnum.dedup() |> FEnum.frequencies()
     end
   }},
  {"Chain: filter + sort + uniq + sum (filter placement)",
   %{
     "Enum pipeline" => fn ->
       list |> Enum.filter(&(&1 > div(size, 2))) |> Enum.sort() |> Enum.uniq() |> Enum.sum()
     end,
     "FEnum filter before new" => fn ->
       list |> Enum.filter(&(&1 > div(size, 2))) |> FEnum.new() |> FEnum.sort() |> FEnum.uniq() |> FEnum.sum()
     end,
     "FEnum filter after new" => fn ->
       list |> FEnum.new() |> FEnum.filter(&(&1 > div(size, 2))) |> FEnum.sort() |> FEnum.uniq() |> FEnum.sum()
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
# Run selected benchmarks
# ---------------------------------------------------------------------------

Enum.each(benchmarks, fn {title, scenarios} ->
  Benchee.run(scenarios, [title: title] ++ opts)
end)

IO.puts("\nBenchmarks complete!")
