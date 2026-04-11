#!/usr/bin/env elixir
#
# Generate bench/rankings.md from the benchee HTML reports in bench/output/.
#
# Run from anywhere — paths are resolved relative to this script's location:
#
#     elixir bench/gen_rankings.exs
#
# The script parses the `var scenarios = [...]` JSON blob embedded in each
# `bench/output/<slug>/scaling_<size>_comparison.html` file produced by
# `mix run bench/scaling_bench.exs`, ranks the candidates per operation, and
# writes a markdown summary to `bench/rankings.md`.
#
# NOTE: invoke with plain `elixir`, not `mix run`. `Mix.install/1` refuses to
# run inside an already-loaded Mix project.

defmodule FEnum.BenchRankings do
  # The second element in each tuple is the directory slug under
  # `bench/output/`. `scaling_bench.exs` derives it from the op title with
  # `title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_") |> String.trim("_")`
  # and each op writes to `bench/output/{slug}/scaling_<size>_comparison.html`.
  @ops [
    {"sort", "sort"},
    {"sort :desc", "sort_desc"},
    {"reverse", "reverse"},
    {"dedup", "dedup"},
    {"uniq", "uniq"},
    {"sum", "sum"},
    {"min", "min"},
    {"max", "max"},
    {"member?", "member"},
    {"frequencies", "frequencies"},
    {"chain: sort+uniq+sum", "chain_sort_uniq_sum"}
  ]

  @sizes [100, 1_000, 10_000, 100_000, 1_000_000]
  @size_headers ["n = 100", "n = 1,000", "n = 10,000", "n = 100,000", "n = 1,000,000"]

  # Size used to determine the canonical (per-row) ranking. We use n=1M because
  # that's where measurement noise is smallest and the user-visible speedups
  # are largest — it lines up with the one-shot tables in README.md.
  @ranking_size 1_000_000

  # How FEnum handles each op on *list* input — an inline badge after the
  # section title. Binary input always goes through the NIF, so the badge
  # only describes the list path (the ambiguous one). Derived from the
  # clause order in `lib/f_enum.ex`: ops that have a `Native.nif_*_list`
  # clause use the NIF; the rest fall through to `Enum.*`.
  @paths %{
    "sort" => "uses NIF",
    "sort :desc" => "uses NIF",
    "reverse" => "passthrough to Enum",
    "dedup" => "passthrough to Enum",
    "uniq" => "uses NIF",
    "sum" => "passthrough to Enum",
    "min" => "passthrough to Enum",
    "max" => "passthrough to Enum",
    "member?" => "passthrough to Enum",
    "frequencies" => "uses NIF",
    "chain: sort+uniq+sum" => "uses NIF"
  }

  def run() do
    output_dir = "bench/output"
    rankings_path = "bench/rankings.md"

    unless File.dir?(output_dir) do
      IO.puts(
        :stderr,
        "expected benchee HTML reports in #{output_dir} — " <>
          "run `mix run bench/scaling_bench.exs` first"
      )

      System.halt(1)
    end

    results = collect_results(output_dir)
    markdown = render_markdown(results)
    File.write!(rankings_path, markdown)
    IO.puts("wrote #{Path.relative_to_cwd(rankings_path)}")
  end

  # ---------------------------------------------------------------------------
  # Extraction
  # ---------------------------------------------------------------------------

  defp collect_results(output_dir) do
    Map.new(@ops, fn {op_name, slug} ->
      by_function =
        Enum.reduce(@sizes, %{}, fn size, acc ->
          path =
            Path.join([output_dir, slug, "scaling_#{size}_comparison.html"])

          if File.exists?(path) do
            case extract_scenarios(path) do
              nil -> acc
              scenarios -> merge_scenarios(acc, scenarios, size)
            end
          else
            acc
          end
        end)

      {op_name, by_function}
    end)
  end

  # Parse `var scenarios = [...];` from a benchee HTML report into Elixir data.
  defp extract_scenarios(html_path) do
    text = File.read!(html_path)

    case Regex.run(~r/var scenarios\s*=\s*(\[.*?\]);\n/s, text, capture: :all_but_first) do
      [json] -> Jason.decode!(json)
      _ -> nil
    end
  end

  defp merge_scenarios(acc, scenarios, size) do
    Enum.reduce(scenarios, acc, fn scenario, acc ->
      name = scenario["job_name"]
      stats = scenario["run_time_data"]["statistics"]

      entry = %{
        median: stats["median"],
        average: stats["average"],
        ips: stats["ips"]
      }

      Map.update(acc, name, %{size => entry}, &Map.put(&1, size, entry))
    end)
  end

  # ---------------------------------------------------------------------------
  # Rendering
  # ---------------------------------------------------------------------------

  # Human-readable IPS formatting (Benchee-style).
  defp fmt_ips(ips) when ips >= 1_000_000,
    do: format_float(ips / 1_000_000) <> " M"

  defp fmt_ips(ips) when ips >= 1_000,
    do: format_float(ips / 1_000) <> " K"

  defp fmt_ips(ips),
    do: format_float(ips * 1.0)

  # Benchee stores run_time_data in nanoseconds. Show >=1 ms as ms, everything
  # else as µs (including sub-µs values like 0.09 µs — nothing in our sweep
  # needs a ns unit).
  defp fmt_time(ns) when ns >= 1_000_000,
    do: format_float(ns / 1_000_000) <> " ms"

  defp fmt_time(ns),
    do: format_float(ns / 1_000) <> " µs"

  defp format_float(value),
    do: :erlang.float_to_binary(value * 1.0, decimals: 2)

  # Returns [{name, ips}, ...] sorted fastest-first for the given input size.
  defp rank_by_size(op_data, size) do
    op_data
    |> Enum.flat_map(fn {name, by_size} ->
      case Map.get(by_size, size) do
        nil -> []
        entry -> [{name, entry.ips}]
      end
    end)
    |> Enum.sort_by(fn {_name, ips} -> ips end, :desc)
  end

  defp binary_variant?(name), do: String.contains?(name, "(binary)")

  # The `(list)` / `(binary)` suffixes are redundant once the tables are
  # already split by input type, so strip them for display. Identity (for
  # ranking and lookup) still uses the full internal name.
  defp display_name(name) do
    name
    |> String.replace(" (list)", "")
    |> String.replace(" (binary)", "")
  end

  # List-table cell: winner is bold, everyone else shows slowdown vs winner.
  # Each cell has the IPS on the first line and the average run time on the
  # second line; non-winners get a third italic line with the slowdown.
  defp format_list_cell(ips, average_ns, fastest_ips) do
    ips_str = fmt_ips(ips) <> " ips"
    time_str = fmt_time(average_ns)

    if ips >= fastest_ips do
      "**#{ips_str}**<br/>#{time_str}"
    else
      "#{ips_str}<br/>#{time_str}<br/>_#{format_float(fastest_ips / ips)}× slower_"
    end
  end

  # Binary-table cell: sole entry in its row, compared head-to-head against
  # the fastest list variant at that column so you can see the extra lift
  # from packing your integers into an i64 binary. Layout mirrors
  # format_list_cell: IPS line, time line, optional comparison line.
  defp format_binary_cell(ips, average_ns, nil) do
    "**#{fmt_ips(ips)} ips**<br/>#{fmt_time(average_ns)}"
  end

  defp format_binary_cell(ips, average_ns, fastest_list_ips) when ips >= fastest_list_ips do
    ratio = ips / fastest_list_ips

    "**#{fmt_ips(ips)} ips**<br/>#{fmt_time(average_ns)}<br/>" <>
      "_#{format_float(ratio)}× faster than fastest list_"
  end

  defp format_binary_cell(ips, average_ns, fastest_list_ips) do
    ratio = fastest_list_ips / ips

    "#{fmt_ips(ips)} ips<br/>#{fmt_time(average_ns)}<br/>" <>
      "_#{format_float(ratio)}× slower than fastest list_"
  end

  defp table_header do
    header = "| Function | " <> Enum.join(@size_headers, " | ") <> " |"
    sep = String.duplicate("|---", length(@size_headers) + 1) <> "|"
    {header, sep}
  end

  # Ranked list-input table (apples-to-apples: Enum vs FEnum list).
  defp render_list_table(list_data) do
    case rank_by_size(list_data, @ranking_size) do
      [] ->
        nil

      canonical ->
        {header, sep} = table_header()

        fastest_ips_by_size =
          Map.new(@sizes, fn size ->
            case rank_by_size(list_data, size) do
              [{_name, ips} | _] -> {size, ips}
              [] -> {size, 0.0}
            end
          end)

        rows =
          for {name, _ips} <- canonical do
            cells =
              ["`#{display_name(name)}`"] ++
                Enum.map(@sizes, fn size ->
                  case Map.get(list_data[name], size) do
                    nil ->
                      "—"

                    entry ->
                      format_list_cell(
                        entry.ips,
                        entry.average,
                        Map.fetch!(fastest_ips_by_size, size)
                      )
                  end
                end)

            "| " <> Enum.join(cells, " | ") <> " |"
          end

        Enum.join([header, sep | rows], "\n")
    end
  end

  # Binary-only table: one row per binary variant, each cell showing IPS
  # and the speedup (or slowdown) vs. the fastest list variant in that
  # column. `list_data` is used purely as the comparison reference.
  defp render_binary_table(binary_data, list_data) do
    case rank_by_size(binary_data, @ranking_size) do
      [] ->
        nil

      canonical ->
        {header, sep} = table_header()

        fastest_list_ips_by_size =
          Map.new(@sizes, fn size ->
            case rank_by_size(list_data, size) do
              [{_name, ips} | _] -> {size, ips}
              [] -> {size, nil}
            end
          end)

        rows =
          for {name, _ips} <- canonical do
            cells =
              ["`#{display_name(name)}`"] ++
                Enum.map(@sizes, fn size ->
                  case Map.get(binary_data[name], size) do
                    nil ->
                      "—"

                    entry ->
                      format_binary_cell(
                        entry.ips,
                        entry.average,
                        Map.get(fastest_list_ips_by_size, size)
                      )
                  end
                end)

            "| " <> Enum.join(cells, " | ") <> " |"
          end

        Enum.join([header, sep | rows], "\n")
    end
  end

  defp render_op(op_name, op_data) do
    # Two sub-tables per op:
    #   1. **List input** — Enum.<op> vs FEnum.<op> (list), ranked, slowdown
    #      vs the column winner. The honest "is FEnum worth it for my
    #      existing list pipelines?" comparison.
    #   2. **Binary input** — FEnum.<op> (binary) alone, with each cell
    #      reporting the speedup vs the fastest list variant at that size.
    # Ops with no binary variant (chain) only render the list table.
    {binary_data, list_data} =
      op_data
      |> Enum.split_with(fn {name, _} -> binary_variant?(name) end)
      |> then(fn {bin, lst} -> {Map.new(bin), Map.new(lst)} end)

    heading =
      case Map.get(@paths, op_name) do
        nil -> "### " <> op_name
        badge -> "### " <> op_name <> " (" <> badge <> ")"
      end

    list_section =
      case render_list_table(list_data) do
        nil -> []
        table -> ["**List input**", "", table, ""]
      end

    binary_section =
      if map_size(binary_data) > 0 do
        case render_binary_table(binary_data, list_data) do
          nil -> []
          # Binary input always goes through the NIF (every `is_binary(bin)`
          # clause in lib/f_enum.ex dispatches to Native.nif_*_binary/1), so
          # the badge is unconditional here.
          table -> ["**Binary input** (uses NIF)", "", table, ""]
        end
      else
        []
      end

    parts = [heading, ""] ++ list_section ++ binary_section

    case parts do
      [_heading, "" | []] -> nil
      _ -> Enum.join(parts, "\n")
    end
  end

  defp render_markdown(results) do
    intro = [
      "# FEnum scaling benchmarks — ranked by input size",
      "",
      "Each operation below has two sub-tables. **List input** compares `Enum.<op>` against `FEnum.<op>` on a list — the honest apples-to-apples comparison when your data is already a list and you can't change its layout. **Binary input** shows `FEnum.<op>` on a packed `i64` binary on its own, with each cell reporting how much faster (or slower) it is than the fastest list variant at the same size, so you can see the extra lift you get from binary storage. Ops with no binary path (the chain benchmark) only show the first table.",
      "",
      "The badge next to each section title shows how `FEnum` handles list input: **uses NIF** runs in Rust, **passthrough to Enum** just forwards to the standard library. The **Binary input** sub-header is always `(uses NIF)` — every binary clause dispatches to a Rust NIF.",
      "",
      "Each cell shows iterations-per-second on the first line (higher is better) and the average run time on the second line (lower is better). Rows in the list table are ordered by the winner at `n = 1,000,000`; the **bold** cell in each column is the fastest entry at that size, and row 2 gets a third italic line with its slowdown vs. the column's fastest.",
      "",
      "Source: `bench/scaling_bench.exs`, medians over warmup 1 s / runtime 3 s / memory 1 s on Apple M2 Pro (macOS, Elixir 1.19, Erlang/OTP 28). Regenerate the underlying HTML reports with `mix run bench/scaling_bench.exs`, then re-render this file with `elixir bench/gen_rankings.exs`.",
      "",
      "> **Noise note:** at `n = 100` the cheap operations (`reverse`, `sum`, `min`, `max`, `member?`, `dedup`) run in sub-microsecond territory, so the IPS numbers there are dominated by benchmark jitter — don't read too much into small rank swaps in that column (e.g. `FEnum.min` appearing to beat `Enum.min` by 22× at `n = 100` in the list table, even though `FEnum.min/1` unconditionally delegates to `Enum.min/1` for list input).",
      ""
    ]

    # Emit NIF-using ops first, then passthrough ops. `Enum.sort_by/3` is
    # stable, so within each group we preserve the original `@ops` order
    # (sort next to sort :desc, min next to max, etc.).
    sorted_ops =
      Enum.sort_by(@ops, fn {op_name, _slug} ->
        case Map.get(@paths, op_name) do
          "uses NIF" -> 0
          _ -> 1
        end
      end)

    op_sections =
      for {op_name, _slug} <- sorted_ops,
          op_data = Map.get(results, op_name, %{}),
          map_size(op_data) > 0,
          section = render_op(op_name, op_data),
          not is_nil(section) do
        section
      end

    Enum.join(intro ++ op_sections, "\n")
  end
end

FEnum.BenchRankings.run()
