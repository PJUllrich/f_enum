defmodule FEnum.BinaryTest do
  use ExUnit.Case, async: true

  # Helper: pack a list into native-endian i64 binary
  defp pack(list), do: for(i <- list, into: <<>>, do: <<i::signed-native-64>>)
  defp unpack(bin), do: for(<<i::signed-native-64 <- bin>>, do: i)

  describe "binary input: sorting & ordering" do
    test "sort/1" do
      assert unpack(FEnum.sort(pack([3, 1, 4, 1, 5]))) == [1, 1, 3, 4, 5]
    end

    test "sort/2 asc and desc" do
      assert unpack(FEnum.sort(pack([3, 1, 2]), :asc)) == [1, 2, 3]
      assert unpack(FEnum.sort(pack([3, 1, 2]), :desc)) == [3, 2, 1]
    end

    test "reverse/1" do
      assert unpack(FEnum.reverse(pack([1, 2, 3]))) == [3, 2, 1]
    end

    test "dedup/1" do
      assert unpack(FEnum.dedup(pack([1, 1, 2, 2, 3]))) == [1, 2, 3]
    end

    test "uniq/1" do
      assert unpack(FEnum.uniq(pack([3, 1, 2, 1, 3]))) == [3, 1, 2]
    end
  end

  describe "binary input: aggregation" do
    test "sum/1" do
      assert FEnum.sum(pack([1, 2, 3])) == 6
    end

    test "product/1" do
      assert FEnum.product(pack([2, 3, 4])) == 24
    end

    test "min/1" do
      assert FEnum.min(pack([3, 1, 2])) == 1
    end

    test "max/1" do
      assert FEnum.max(pack([3, 1, 2])) == 3
    end

    test "min_max/1" do
      assert FEnum.min_max(pack([3, 1, 2])) == {1, 3}
    end

    test "count/1" do
      assert FEnum.count(pack([1, 2, 3])) == 3
    end

    test "empty?/1" do
      assert FEnum.empty?(<<>>) == true
      assert FEnum.empty?(pack([1])) == false
    end
  end

  describe "binary input: access" do
    test "at/2" do
      assert FEnum.at(pack([10, 20, 30]), 1) == 20
      assert FEnum.at(pack([10, 20, 30]), -1) == 30
      assert FEnum.at(pack([10, 20]), 5) == nil
    end

    test "fetch!/2" do
      assert FEnum.fetch!(pack([10, 20, 30]), 1) == 20
      assert_raise Enum.OutOfBoundsError, fn -> FEnum.fetch!(pack([1, 2]), 5) end
    end

    test "slice/2" do
      assert unpack(FEnum.slice(pack([1, 2, 3, 4, 5]), 1..3)) == [2, 3, 4]
    end

    test "take/2" do
      assert unpack(FEnum.take(pack([1, 2, 3, 4]), 2)) == [1, 2]
      assert unpack(FEnum.take(pack([1, 2, 3, 4]), -2)) == [3, 4]
    end

    test "drop/2" do
      assert unpack(FEnum.drop(pack([1, 2, 3, 4]), 2)) == [3, 4]
    end

    test "member?/2" do
      assert FEnum.member?(pack([1, 2, 3]), 2) == true
      assert FEnum.member?(pack([1, 2, 3]), 4) == false
    end
  end

  describe "binary input: combination" do
    test "concat/2" do
      result = FEnum.concat(pack([1, 2]), pack([3, 4]))
      assert unpack(result) == [1, 2, 3, 4]
    end

    test "frequencies/1" do
      assert FEnum.frequencies(pack([1, 2, 1, 3, 2, 1])) == %{1 => 3, 2 => 2, 3 => 1}
    end

    test "join/2" do
      assert FEnum.join(pack([1, 2, 3]), ",") == "1,2,3"
    end

    test "with_index/1" do
      assert FEnum.with_index(pack([10, 20, 30])) == [{10, 0}, {20, 1}, {30, 2}]
    end

    test "zip/2" do
      assert FEnum.zip(pack([1, 2]), pack([3, 4])) == [{1, 3}, {2, 4}]
    end

    test "chunk_every/2" do
      assert FEnum.chunk_every(pack([1, 2, 3, 4]), 2) == [[1, 2], [3, 4]]
    end
  end

  describe "binary input: new/1 chain" do
    test "creates a Ref from binary and runs chain" do
      result =
        pack([3, 1, 4, 1, 5])
        |> FEnum.new()
        |> FEnum.sort()
        |> FEnum.dedup()
        |> FEnum.take(3)
        |> FEnum.run()

      assert result == [1, 3, 4]
    end
  end
end
