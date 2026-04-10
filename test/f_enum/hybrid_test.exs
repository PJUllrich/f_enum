defmodule FEnum.HybridTest do
  use ExUnit.Case, async: true

  describe "filter/2" do
    test "filters elements" do
      assert FEnum.filter([1, 2, 3, 4], &(&1 > 2)) == [3, 4]
    end

    test "chain mode returns Ref" do
      result = [1, 2, 3, 4] |> FEnum.new() |> FEnum.filter(&(&1 > 2)) |> FEnum.run()
      assert result == [3, 4]
    end

    test "fallback" do
      assert FEnum.filter(1..5, &(&1 > 3)) == [4, 5]
    end
  end

  describe "reject/2" do
    test "rejects elements" do
      assert FEnum.reject([1, 2, 3, 4], &(&1 > 2)) == [1, 2]
    end

    test "chain mode" do
      result = [1, 2, 3, 4] |> FEnum.new() |> FEnum.reject(&(&1 > 2)) |> FEnum.run()
      assert result == [1, 2]
    end
  end

  describe "map/2" do
    test "maps elements" do
      assert FEnum.map([1, 2, 3], &(&1 * 2)) == [2, 4, 6]
    end

    test "chain mode" do
      result = [1, 2, 3] |> FEnum.new() |> FEnum.map(&(&1 * 2)) |> FEnum.run()
      assert result == [2, 4, 6]
    end

    test "fallback" do
      assert FEnum.map(1..3, &(&1 * 2)) == [2, 4, 6]
    end
  end

  describe "flat_map/2" do
    test "flat maps" do
      assert FEnum.flat_map([1, 2], &[&1, &1 * 10]) == [1, 10, 2, 20]
    end

    test "chain mode" do
      result = [1, 2] |> FEnum.new() |> FEnum.flat_map(&[&1, &1 * 10]) |> FEnum.run()
      assert result == [1, 10, 2, 20]
    end
  end

  describe "reduce/3" do
    test "reduces with accumulator" do
      assert FEnum.reduce([1, 2, 3], 0, &(&1 + &2)) == 6
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.reduce(0, &(&1 + &2)) == 6
    end

    test "fallback" do
      assert FEnum.reduce(1..3, 0, &(&1 + &2)) == 6
    end
  end

  describe "map_reduce/3" do
    test "maps and reduces" do
      assert FEnum.map_reduce([1, 2, 3], 0, fn x, acc -> {x * 2, acc + x} end) == {[2, 4, 6], 6}
    end

    test "chain mode" do
      result = [1, 2, 3] |> FEnum.new() |> FEnum.map_reduce(0, fn x, acc -> {x * 2, acc + x} end)
      assert result == {[2, 4, 6], 6}
    end
  end

  describe "scan/2" do
    test "running accumulation" do
      assert FEnum.scan([1, 2, 3], &(&1 + &2)) == [1, 3, 6]
    end

    test "chain mode" do
      result = [1, 2, 3] |> FEnum.new() |> FEnum.scan(&(&1 + &2)) |> FEnum.run()
      assert result == [1, 3, 6]
    end
  end

  describe "find/2" do
    test "finds first match" do
      assert FEnum.find([1, 2, 3], &(&1 > 1)) == 2
    end

    test "returns nil when not found" do
      assert FEnum.find([1, 2, 3], &(&1 > 5)) == nil
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.find(&(&1 > 1)) == 2
    end
  end

  describe "find_index/2" do
    test "finds index of first match" do
      assert FEnum.find_index([1, 2, 3], &(&1 > 1)) == 1
    end

    test "returns nil when not found" do
      assert FEnum.find_index([1, 2, 3], &(&1 > 5)) == nil
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.find_index(&(&1 > 1)) == 1
    end
  end

  describe "find_value/2" do
    test "returns first truthy value" do
      assert FEnum.find_value([1, 2, 3], &if(&1 > 1, do: &1 * 10)) == 20
    end

    test "returns nil when none match" do
      assert FEnum.find_value([1, 2, 3], &if(&1 > 5, do: &1)) == nil
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.find_value(&if(&1 > 1, do: &1 * 10)) == 20
    end
  end

  describe "any?/2" do
    test "returns true when any match" do
      assert FEnum.any?([1, 2, 3], &(&1 > 2)) == true
    end

    test "returns false when none match" do
      assert FEnum.any?([1, 2, 3], &(&1 > 5)) == false
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.any?(&(&1 > 2)) == true
    end
  end

  describe "all?/2" do
    test "returns true when all match" do
      assert FEnum.all?([1, 2, 3], &(&1 > 0)) == true
    end

    test "returns false when any doesn't match" do
      assert FEnum.all?([1, 2, 3], &(&1 > 1)) == false
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.all?(&(&1 > 0)) == true
    end
  end

  describe "count/2" do
    test "counts matching elements" do
      assert FEnum.count([1, 2, 3], &(&1 > 1)) == 2
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.count(&(&1 > 1)) == 2
    end
  end

  describe "sort_by/2" do
    test "sorts by function result" do
      assert FEnum.sort_by([3, -1, 2], &abs/1) == [-1, 2, 3]
    end

    test "chain mode" do
      result = [3, -1, 2] |> FEnum.new() |> FEnum.sort_by(&abs/1) |> FEnum.run()
      assert result == [-1, 2, 3]
    end
  end

  describe "each/2" do
    test "returns :ok" do
      assert FEnum.each([1, 2, 3], fn _ -> nil end) == :ok
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.each(fn _ -> nil end) == :ok
    end
  end

  describe "group_by/2" do
    test "groups by function" do
      assert FEnum.group_by([1, 2, 3, 4], &rem(&1, 2)) == %{0 => [2, 4], 1 => [1, 3]}
    end

    test "chain mode" do
      result = [1, 2, 3, 4] |> FEnum.new() |> FEnum.group_by(&rem(&1, 2))
      assert result == %{0 => [2, 4], 1 => [1, 3]}
    end
  end
end
