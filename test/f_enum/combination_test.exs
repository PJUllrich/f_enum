defmodule FEnum.CombinationTest do
  use ExUnit.Case, async: true

  describe "concat/2" do
    test "concatenates two lists" do
      assert FEnum.concat([1, 2], [3, 4]) == [1, 2, 3, 4]
    end

    test "chain mode (both refs)" do
      r1 = FEnum.new([1, 2])
      r2 = FEnum.new([3, 4])
      assert FEnum.concat(r1, r2) |> FEnum.run() == [1, 2, 3, 4]
    end

    test "mixed ref and list" do
      ref = FEnum.new([1, 2])
      assert FEnum.concat(ref, [3, 4]) |> FEnum.run() == [1, 2, 3, 4]
      assert FEnum.concat([1, 2], ref) |> FEnum.run() == [1, 2, 1, 2]
    end

    test "empty lists" do
      assert FEnum.concat([], [1, 2]) == [1, 2]
      assert FEnum.concat([1, 2], []) == [1, 2]
    end

    test "fallback" do
      assert FEnum.concat(1..3, 4..6) == [1, 2, 3, 4, 5, 6]
    end
  end

  describe "frequencies/1" do
    test "counts occurrences" do
      assert FEnum.frequencies([1, 2, 1, 3, 2, 1]) == %{1 => 3, 2 => 2, 3 => 1}
    end

    test "chain mode" do
      result = [1, 1, 2] |> FEnum.new() |> FEnum.frequencies()
      assert result == %{1 => 2, 2 => 1}
    end

    test "empty list" do
      assert FEnum.frequencies([]) == %{}
    end

    test "fallback" do
      assert FEnum.frequencies(1..3) == %{1 => 1, 2 => 1, 3 => 1}
    end
  end

  describe "join/2" do
    test "joins with separator" do
      assert FEnum.join([1, 2, 3], ",") == "1,2,3"
    end

    test "joins with default separator" do
      assert FEnum.join([1, 2, 3]) == "1,2,3"
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.join("-") == "1-2-3"
    end

    test "empty list" do
      assert FEnum.join([], ",") == ""
    end

    test "single element" do
      assert FEnum.join([42], ",") == "42"
    end
  end

  describe "with_index/1" do
    test "adds indices" do
      assert FEnum.with_index([10, 20, 30]) == [{10, 0}, {20, 1}, {30, 2}]
    end

    test "with offset" do
      assert FEnum.with_index([10, 20], 5) == [{10, 5}, {20, 6}]
    end

    test "chain mode" do
      result = [10, 20] |> FEnum.new() |> FEnum.with_index()
      assert result == [{10, 0}, {20, 1}]
    end

    test "empty" do
      assert FEnum.with_index([]) == []
    end
  end

  describe "zip/2" do
    test "zips two lists" do
      assert FEnum.zip([1, 2], [3, 4]) == [{1, 3}, {2, 4}]
    end

    test "different lengths truncates" do
      assert FEnum.zip([1, 2, 3], [4, 5]) == [{1, 4}, {2, 5}]
    end

    test "chain mode" do
      r1 = FEnum.new([1, 2])
      r2 = FEnum.new([3, 4])
      assert FEnum.zip(r1, r2) == [{1, 3}, {2, 4}]
    end

    test "empty" do
      assert FEnum.zip([], [1, 2]) == []
    end
  end

  describe "chunk_every/2" do
    test "chunks evenly" do
      assert FEnum.chunk_every([1, 2, 3, 4], 2) == [[1, 2], [3, 4]]
    end

    test "last chunk smaller" do
      assert FEnum.chunk_every([1, 2, 3, 4, 5], 2) == [[1, 2], [3, 4], [5]]
    end

    test "chain mode" do
      result = [1, 2, 3, 4] |> FEnum.new() |> FEnum.chunk_every(2)
      assert result == [[1, 2], [3, 4]]
    end

    test "empty" do
      assert FEnum.chunk_every([], 3) == []
    end
  end

  describe "into/2" do
    test "into MapSet" do
      result = FEnum.into([1, 2, 3], MapSet.new())
      assert result == MapSet.new([1, 2, 3])
    end

    test "chain mode into MapSet" do
      result = [1, 2, 3] |> FEnum.new() |> FEnum.into(MapSet.new())
      assert result == MapSet.new([1, 2, 3])
    end
  end
end
