defmodule FEnum.OrderingTest do
  use ExUnit.Case, async: true

  describe "sort/1" do
    test "sorts a list ascending" do
      assert FEnum.sort([3, 1, 4, 1, 5]) == [1, 1, 3, 4, 5]
    end

    test "chain mode returns sorted Ref" do
      result = [3, 1, 4] |> FEnum.new() |> FEnum.sort() |> FEnum.run()
      assert result == [1, 3, 4]
    end

    test "empty list" do
      assert FEnum.sort([]) == []
    end

    test "already sorted" do
      assert FEnum.sort([1, 2, 3]) == [1, 2, 3]
    end

    test "fallback for non-list" do
      assert FEnum.sort(3..1//-1) == [1, 2, 3]
    end
  end

  describe "sort/2" do
    test "ascending" do
      assert FEnum.sort([3, 1, 2], :asc) == [1, 2, 3]
    end

    test "descending" do
      assert FEnum.sort([3, 1, 4], :desc) == [4, 3, 1]
    end

    test "chain mode desc" do
      result = [5, 2, 8] |> FEnum.new() |> FEnum.sort(:desc) |> FEnum.run()
      assert result == [8, 5, 2]
    end

    test "fallback for non-list" do
      assert FEnum.sort(1..3, :desc) == [3, 2, 1]
    end
  end

  describe "reverse/1" do
    test "reverses a list" do
      assert FEnum.reverse([1, 2, 3]) == [3, 2, 1]
    end

    test "chain mode" do
      result = [1, 2, 3] |> FEnum.new() |> FEnum.reverse() |> FEnum.run()
      assert result == [3, 2, 1]
    end

    test "empty list" do
      assert FEnum.reverse([]) == []
    end

    test "fallback" do
      assert FEnum.reverse(1..3) == [3, 2, 1]
    end
  end

  describe "dedup/1" do
    test "removes consecutive duplicates" do
      assert FEnum.dedup([1, 1, 2, 2, 3]) == [1, 2, 3]
    end

    test "non-consecutive duplicates preserved" do
      assert FEnum.dedup([1, 2, 1]) == [1, 2, 1]
    end

    test "chain mode" do
      result = [1, 1, 2, 2] |> FEnum.new() |> FEnum.dedup() |> FEnum.run()
      assert result == [1, 2]
    end

    test "empty list" do
      assert FEnum.dedup([]) == []
    end

    test "fallback" do
      assert FEnum.dedup(MapSet.new([1, 2, 3])) == Enum.dedup(MapSet.new([1, 2, 3]))
    end
  end

  describe "uniq/1" do
    test "removes all duplicates keeping first" do
      assert FEnum.uniq([3, 1, 2, 1, 3]) == [3, 1, 2]
    end

    test "chain mode" do
      result = [1, 2, 1, 3, 2] |> FEnum.new() |> FEnum.uniq() |> FEnum.run()
      assert result == [1, 2, 3]
    end

    test "no duplicates" do
      assert FEnum.uniq([1, 2, 3]) == [1, 2, 3]
    end

    test "empty list" do
      assert FEnum.uniq([]) == []
    end

    test "fallback" do
      assert FEnum.uniq(1..3) == [1, 2, 3]
    end
  end
end
