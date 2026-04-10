defmodule FEnum.AggregationTest do
  use ExUnit.Case, async: true

  describe "sum/1" do
    test "sums a list" do
      assert FEnum.sum([1, 2, 3]) == 6
    end

    test "chain mode" do
      assert [1, 2, 3] |> FEnum.new() |> FEnum.sum() == 6
    end

    test "empty list" do
      assert FEnum.sum([]) == 0
    end

    test "negative numbers" do
      assert FEnum.sum([-1, -2, 3]) == 0
    end

    test "fallback" do
      assert FEnum.sum(1..3) == 6
    end
  end

  describe "product/1" do
    test "products a list" do
      assert FEnum.product([1, 2, 3]) == 6
    end

    test "chain mode" do
      assert [2, 3, 4] |> FEnum.new() |> FEnum.product() == 24
    end

    test "empty list" do
      assert FEnum.product([]) == 1
    end

    test "fallback" do
      assert FEnum.product(1..4) == 24
    end
  end

  describe "min/1" do
    test "finds minimum" do
      assert FEnum.min([3, 1, 2]) == 1
    end

    test "chain mode" do
      assert [5, 2, 8] |> FEnum.new() |> FEnum.min() == 2
    end

    test "raises on empty" do
      assert_raise Enum.EmptyError, fn -> FEnum.min([]) end
    end

    test "negative numbers" do
      assert FEnum.min([-5, 0, 5]) == -5
    end

    test "fallback" do
      assert FEnum.min(1..5) == 1
    end
  end

  describe "max/1" do
    test "finds maximum" do
      assert FEnum.max([3, 1, 2]) == 3
    end

    test "chain mode" do
      assert [5, 2, 8] |> FEnum.new() |> FEnum.max() == 8
    end

    test "raises on empty" do
      assert_raise Enum.EmptyError, fn -> FEnum.max([]) end
    end

    test "fallback" do
      assert FEnum.max(1..5) == 5
    end
  end

  describe "min_max/1" do
    test "returns min and max" do
      assert FEnum.min_max([3, 1, 2]) == {1, 3}
    end

    test "chain mode" do
      assert [5, 2, 8] |> FEnum.new() |> FEnum.min_max() == {2, 8}
    end

    test "raises on empty" do
      assert_raise Enum.EmptyError, fn -> FEnum.min_max([]) end
    end

    test "single element" do
      assert FEnum.min_max([42]) == {42, 42}
    end

    test "fallback" do
      assert FEnum.min_max(1..5) == {1, 5}
    end
  end

  describe "count/1" do
    test "counts elements" do
      assert FEnum.count([1, 2, 3]) == 3
    end

    test "chain mode" do
      assert [1, 2, 3, 4] |> FEnum.new() |> FEnum.count() == 4
    end

    test "empty" do
      assert FEnum.count([]) == 0
    end

    test "fallback" do
      assert FEnum.count(1..10) == 10
    end
  end
end
