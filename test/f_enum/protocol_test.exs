defmodule FEnum.ProtocolTest do
  use ExUnit.Case, async: true

  describe "Enumerable protocol" do
    test "Enum.to_list/1" do
      ref = FEnum.new([1, 2, 3])
      assert Enum.to_list(ref) == [1, 2, 3]
    end

    test "Enum.count/1" do
      ref = FEnum.new([1, 2, 3])
      assert Enum.count(ref) == 3
    end

    test "Enum.member?/2" do
      ref = FEnum.new([1, 2, 3])
      assert Enum.member?(ref, 2) == true
      assert Enum.member?(ref, 5) == false
    end

    test "Enum.slice/2" do
      ref = FEnum.new([10, 20, 30, 40, 50])
      assert Enum.slice(ref, 1..3) == [20, 30, 40]
    end

    test "Enum.reduce/3" do
      ref = FEnum.new([1, 2, 3])
      assert Enum.reduce(ref, 0, &(&1 + &2)) == 6
    end

    test "Enum.map/2" do
      ref = FEnum.new([1, 2, 3])
      assert Enum.map(ref, &(&1 * 2)) == [2, 4, 6]
    end

    test "Enum.filter/2" do
      ref = FEnum.new([1, 2, 3, 4])
      assert Enum.filter(ref, &(&1 > 2)) == [3, 4]
    end

    test "for comprehension" do
      ref = FEnum.new([1, 2, 3])
      result = for x <- ref, do: x * 2
      assert result == [2, 4, 6]
    end

    test "Enum.sum/1" do
      ref = FEnum.new([1, 2, 3])
      assert Enum.sum(ref) == 6
    end

    test "Enum.sort/1" do
      ref = FEnum.new([3, 1, 2])
      assert Enum.sort(ref) == [1, 2, 3]
    end
  end

  describe "Inspect protocol" do
    test "short list" do
      ref = FEnum.new([1, 2, 3])
      assert inspect(ref) == "#FEnum.Ref<[1, 2, 3] i64, length: 3>"
    end

    test "long list with preview" do
      ref = FEnum.new(Enum.to_list(1..10))
      assert inspect(ref) == "#FEnum.Ref<[1, 2, 3, 4, 5, ...] i64, length: 10>"
    end
  end
end
