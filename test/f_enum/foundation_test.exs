defmodule FEnum.FoundationTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "creates a Ref from a list" do
      ref = FEnum.new([1, 2, 3])
      assert %FEnum.Ref{length: 3} = ref
    end

    test "works with empty list" do
      ref = FEnum.new([])
      assert %FEnum.Ref{length: 0} = ref
    end

    test "works with negative integers" do
      ref = FEnum.new([-1, -2, -3])
      assert FEnum.run(ref) == [-1, -2, -3]
    end
  end

  describe "run/1 and to_list/1" do
    test "round-trips a list" do
      list = [3, 1, 4, 1, 5, 9]
      assert FEnum.run(FEnum.new(list)) == list
      assert FEnum.to_list(FEnum.new(list)) == list
    end

    test "round-trips empty list" do
      assert FEnum.run(FEnum.new([])) == []
    end

    test "round-trips large list" do
      list = Enum.to_list(1..10_000)
      assert FEnum.run(FEnum.new(list)) == list
    end
  end

  describe "Inspect protocol" do
    test "short list shows all elements" do
      ref = FEnum.new([1, 2, 3])
      assert inspect(ref) == "#FEnum.Ref<[1, 2, 3] i64, length: 3>"
    end

    test "long list shows preview with ellipsis" do
      ref = FEnum.new([10, 20, 30, 40, 50, 60, 70])
      assert inspect(ref) == "#FEnum.Ref<[10, 20, 30, 40, 50, ...] i64, length: 7>"
    end

    test "empty list" do
      ref = FEnum.new([])
      assert inspect(ref) == "#FEnum.Ref<[] i64, length: 0>"
    end
  end
end
