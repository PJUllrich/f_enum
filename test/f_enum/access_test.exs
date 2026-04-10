defmodule FEnum.AccessTest do
  use ExUnit.Case, async: true

  describe "at/2" do
    test "returns element at index" do
      assert FEnum.at([10, 20, 30], 1) == 20
    end

    test "negative index" do
      assert FEnum.at([10, 20, 30], -1) == 30
    end

    test "out of bounds returns nil" do
      assert FEnum.at([10, 20], 5) == nil
    end

    test "chain mode" do
      assert [10, 20, 30] |> FEnum.new() |> FEnum.at(0) == 10
    end

    test "fallback" do
      assert FEnum.at(1..5, 2) == 3
    end
  end

  describe "fetch!/2" do
    test "returns element" do
      assert FEnum.fetch!([10, 20, 30], 1) == 20
    end

    test "raises on out of bounds" do
      assert_raise Enum.OutOfBoundsError, fn -> FEnum.fetch!([1, 2], 5) end
    end

    test "chain mode" do
      assert [10, 20, 30] |> FEnum.new() |> FEnum.fetch!(2) == 30
    end
  end

  describe "slice/2" do
    test "slices with range" do
      assert FEnum.slice([1, 2, 3, 4, 5], 1..3) == [2, 3, 4]
    end

    test "chain mode" do
      result = [1, 2, 3, 4, 5] |> FEnum.new() |> FEnum.slice(0..2) |> FEnum.run()
      assert result == [1, 2, 3]
    end

    test "negative indices" do
      assert FEnum.slice([1, 2, 3, 4, 5], -3..-1) == [3, 4, 5]
    end

    test "out of bounds" do
      assert FEnum.slice([1, 2, 3], 5..10) == []
    end

    test "fallback" do
      assert FEnum.slice(1..10, 2..4) == [3, 4, 5]
    end
  end

  describe "take/2" do
    test "takes from beginning" do
      assert FEnum.take([1, 2, 3, 4], 2) == [1, 2]
    end

    test "takes from end with negative" do
      assert FEnum.take([1, 2, 3, 4], -2) == [3, 4]
    end

    test "chain mode" do
      result = [1, 2, 3, 4] |> FEnum.new() |> FEnum.take(2) |> FEnum.run()
      assert result == [1, 2]
    end

    test "take more than available" do
      assert FEnum.take([1, 2], 5) == [1, 2]
    end

    test "fallback" do
      assert FEnum.take(1..10, 3) == [1, 2, 3]
    end
  end

  describe "drop/2" do
    test "drops from beginning" do
      assert FEnum.drop([1, 2, 3, 4], 2) == [3, 4]
    end

    test "drops from end with negative" do
      assert FEnum.drop([1, 2, 3, 4], -2) == [1, 2]
    end

    test "chain mode" do
      result = [1, 2, 3, 4] |> FEnum.new() |> FEnum.drop(1) |> FEnum.run()
      assert result == [2, 3, 4]
    end

    test "fallback" do
      assert FEnum.drop(1..5, 2) == [3, 4, 5]
    end
  end

  describe "member?/2" do
    test "returns true when present" do
      assert FEnum.member?([1, 2, 3], 2) == true
    end

    test "returns false when absent" do
      assert FEnum.member?([1, 2, 3], 4) == false
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.member?(2) == true
    end

    test "fallback" do
      assert FEnum.member?(1..5, 3) == true
    end
  end

  describe "empty?/1" do
    test "empty list" do
      assert FEnum.empty?([]) == true
    end

    test "non-empty list" do
      assert FEnum.empty?([1]) == false
    end

    test "chain mode empty" do
      assert [] |> FEnum.new() |> FEnum.empty?() == true
    end

    test "chain mode non-empty" do
      assert [1] |> FEnum.new() |> FEnum.empty?() == false
    end

    test "fallback" do
      assert FEnum.empty?(1..3) == false
    end
  end
end
