# FEnum Scaling Benchmark
#
# Tests how speedups change with input size.
#
# Run all:        mix run bench/scaling_bench.exs
# Run specific:   mix run bench/scaling_bench.exs -- sort
#                 mix run bench/scaling_bench.exs -- "sort" "uniq"
#
# Each iteration receives freshly generated random data via before_each
# to prevent any result caching across iterations.

sizes = [100, 1_000, 10_000, 100_000, 1_000_000]

# Common Benchee options (before_each added per-run below)
base_opts = [
  warmup: 1,
  time: 3,
  memory_time: 1,
  print: [configuration: true, benchmarking: true],
  formatters: [
    {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
  ]
]

# Number of elements to randomize each iteration to prevent caching
jitter = 1_000

# Pre-generate static tails for each size (size - jitter elements, or empty for small sizes)
base_tails =
  Map.new(sizes, fn size ->
    tail_size = max(size - jitter, 0)
    {size, Enum.map(1..max(tail_size, 1)//1, fn _ -> :rand.uniform(size) end)}
  end)

# Inputs pass the size so before_each can look up the tail and prepend fresh values
inputs = Map.new(sizes, fn size -> {"#{size}", size} end)

gen_data = fn size ->
  j = min(jitter, size)
  tail = base_tails[size]

  # Prepend fresh random values to the static tail — O(jitter) via cons
  list = Enum.reduce(1..j, tail, fn _, acc -> [:rand.uniform(size) | acc] end)

  binary = for i <- list, into: <<>>, do: <<i::signed-native-64>>
  %{list: list, binary: binary}
end

IO.puts(
  "Data generated for sizes: #{Enum.join(sizes, ", ")} (up to #{jitter} elements refreshed each iteration)\n"
)

# ---------------------------------------------------------------------------
# Define benchmarks
# ---------------------------------------------------------------------------

benchmarks = [
  {"sort",
   %{
     "Enum.sort" => fn %{list: list} -> Enum.sort(list) end,
     "FEnum.sort (list)" => fn %{list: list} -> FEnum.sort(list) end,
     "FEnum.sort (binary)" => fn %{binary: bin} -> FEnum.sort(bin) end
   }},
  {"sort :desc",
   %{
     "Enum.sort :desc" => fn %{list: list} -> Enum.sort(list, :desc) end,
     "FEnum.sort :desc (list)" => fn %{list: list} -> FEnum.sort(list, :desc) end,
     "FEnum.sort :desc (binary)" => fn %{binary: bin} -> FEnum.sort(bin, :desc) end
   }},
  {"reverse",
   %{
     "Enum.reverse" => fn %{list: list} -> Enum.reverse(list) end,
     "FEnum.reverse (list)" => fn %{list: list} -> FEnum.reverse(list) end,
     "FEnum.reverse (binary)" => fn %{binary: bin} -> FEnum.reverse(bin) end
   }},
  {"dedup",
   %{
     "Enum.dedup" => fn %{list: list} -> Enum.dedup(list) end,
     "FEnum.dedup (list)" => fn %{list: list} -> FEnum.dedup(list) end,
     "FEnum.dedup (binary)" => fn %{binary: bin} -> FEnum.dedup(bin) end
   }},
  {"uniq",
   %{
     "Enum.uniq" => fn %{list: list} -> Enum.uniq(list) end,
     "FEnum.uniq (list)" => fn %{list: list} -> FEnum.uniq(list) end,
     "FEnum.uniq (binary)" => fn %{binary: bin} -> FEnum.uniq(bin) end
   }},
  {"sum",
   %{
     "Enum.sum" => fn %{list: list} -> Enum.sum(list) end,
     "FEnum.sum (list)" => fn %{list: list} -> FEnum.sum(list) end,
     "FEnum.sum (binary)" => fn %{binary: bin} -> FEnum.sum(bin) end
   }},
  {"min",
   %{
     "Enum.min" => fn %{list: list} -> Enum.min(list) end,
     "FEnum.min (list)" => fn %{list: list} -> FEnum.min(list) end,
     "FEnum.min (binary)" => fn %{binary: bin} -> FEnum.min(bin) end
   }},
  {"max",
   %{
     "Enum.max" => fn %{list: list} -> Enum.max(list) end,
     "FEnum.max (list)" => fn %{list: list} -> FEnum.max(list) end,
     "FEnum.max (binary)" => fn %{binary: bin} -> FEnum.max(bin) end
   }},
  {"member?",
   %{
     "Enum.member?" => fn %{list: list} -> Enum.member?(list, -1) end,
     "FEnum.member? (list)" => fn %{list: list} -> FEnum.member?(list, -1) end,
     "FEnum.member? (binary)" => fn %{binary: bin} -> FEnum.member?(bin, -1) end
   }},
  {"frequencies",
   %{
     "Enum.frequencies" => fn %{list: list} -> Enum.frequencies(list) end,
     "FEnum.frequencies (list)" => fn %{list: list} -> FEnum.frequencies(list) end,
     "FEnum.frequencies (binary)" => fn %{binary: bin} -> FEnum.frequencies(bin) end
   }},
  {"chain: sort + uniq + sum",
   %{
     "Enum pipeline" => fn %{list: list} ->
       list |> Enum.sort() |> Enum.uniq() |> Enum.sum()
     end,
     "FEnum chain" => fn %{list: list} ->
       list |> FEnum.new() |> FEnum.sort() |> FEnum.uniq() |> FEnum.sum()
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
# Run
# ---------------------------------------------------------------------------

Enum.each(benchmarks, fn {title, scenarios} ->
  slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_") |> String.trim("_")

  opts =
    base_opts ++
      [
        title: title,
        inputs: inputs,
        before_each: gen_data,
        print: [configuration: false, benchmarking: true],
        formatters:
          base_opts[:formatters] ++
            [
              {Benchee.Formatters.HTML,
               file: "bench/output/#{slug}/scaling.html", auto_open: false}
            ]
      ]

  Benchee.run(scenarios, opts)
end)

IO.puts("\nScaling benchmarks complete!")
