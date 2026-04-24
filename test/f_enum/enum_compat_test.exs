defmodule FFEnum.EnumCompatTest do
  use ExUnit.Case, async: true

  test "chunk_every/2" do
    assert FEnum.chunk_every([1, 2, 3, 4, 5], 2) == [[1, 2], [3, 4], [5]]
  end

  test "concat/2" do
    assert FEnum.concat([], [1]) == [1]
    assert FEnum.concat([1, [2], 3], [4, 5]) == [1, [2], 3, 4, 5]

    assert FEnum.concat([1, 2], 3..5) == [1, 2, 3, 4, 5]

    assert FEnum.concat([], []) == []
    assert FEnum.concat([], 1..3) == [1, 2, 3]

    assert FEnum.concat(fn acc, _ -> acc end, [1]) == [1]
  end

  test "count/1" do
    assert FEnum.count([1, 2, 3]) == 3
    assert FEnum.count([]) == 0
    assert FEnum.count([1, true, false, nil]) == 4
  end

  test "dedup/1" do
    assert FEnum.dedup([1, 1, 2, 1, 1, 2, 1]) == [1, 2, 1, 2, 1]
    assert FEnum.dedup([2, 1, 1, 2, 1]) == [2, 1, 2, 1]
    assert FEnum.dedup([1, 2, 3, 4]) == [1, 2, 3, 4]
    assert FEnum.dedup([1, 1.0, 2.0, 2]) == [1, 1.0, 2.0, 2]
    assert FEnum.dedup([]) == []
    assert FEnum.dedup([nil, nil, true, {:value, true}]) == [nil, true, {:value, true}]
    assert FEnum.dedup([nil]) == [nil]
  end

  test "dedup/1 with streams" do
    dedup_stream = fn list -> list |> Stream.map(& &1) |> FEnum.dedup() end

    assert dedup_stream.([1, 1, 2, 1, 1, 2, 1]) == [1, 2, 1, 2, 1]
    assert dedup_stream.([2, 1, 1, 2, 1]) == [2, 1, 2, 1]
    assert dedup_stream.([1, 2, 3, 4]) == [1, 2, 3, 4]
    assert dedup_stream.([1, 1.0, 2.0, 2]) == [1, 1.0, 2.0, 2]
    assert dedup_stream.([]) == []
    assert dedup_stream.([nil, nil, true, {:value, true}]) == [nil, true, {:value, true}]
    assert dedup_stream.([nil]) == [nil]
  end

  test "drop/2" do
    assert FEnum.drop([1, 2, 3], 0) == [1, 2, 3]
    assert FEnum.drop([1, 2, 3], 1) == [2, 3]
    assert FEnum.drop([1, 2, 3], 2) == [3]
    assert FEnum.drop([1, 2, 3], 3) == []
    assert FEnum.drop([1, 2, 3], 4) == []
    assert FEnum.drop([1, 2, 3], -1) == [1, 2]
    assert FEnum.drop([1, 2, 3], -2) == [1]
    assert FEnum.drop([1, 2, 3], -4) == []
    assert FEnum.drop([], 3) == []

    assert_raise FunctionClauseError, fn ->
      FEnum.drop([1, 2, 3], 0.0)
    end
  end

  test "drop/2 with streams" do
    drop_stream = fn list, count -> list |> Stream.map(& &1) |> FEnum.drop(count) end

    assert drop_stream.([1, 2, 3], 0) == [1, 2, 3]
    assert drop_stream.([1, 2, 3], 1) == [2, 3]
    assert drop_stream.([1, 2, 3], 2) == [3]
    assert drop_stream.([1, 2, 3], 3) == []
    assert drop_stream.([1, 2, 3], 4) == []
    assert drop_stream.([1, 2, 3], -1) == [1, 2]
    assert drop_stream.([1, 2, 3], -2) == [1]
    assert drop_stream.([1, 2, 3], -4) == []
    assert drop_stream.([], 3) == []
  end

  test "empty?/1" do
    assert FEnum.empty?([])
    assert FEnum.empty?(%{})
    refute FEnum.empty?([1, 2, 3])
    refute FEnum.empty?(%{one: 1})
    refute FEnum.empty?(1..3)

    assert Stream.take([1], 0) |> FEnum.empty?()
    refute Stream.take([1], 1) |> FEnum.empty?()
  end

  test "frequencies/1" do
    assert FEnum.frequencies([]) == %{}
    assert FEnum.frequencies(~w{a c a a c b}) == %{"a" => 3, "b" => 1, "c" => 2}
  end

  test "join/2" do
    assert FEnum.join([], " = ") == ""
    assert FEnum.join([1, 2, 3], " = ") == "1 = 2 = 3"
    assert FEnum.join([1, "2", 3], " = ") == "1 = 2 = 3"
    assert FEnum.join([1, 2, 3]) == "123"
    assert FEnum.join(["", "", 1, 2, "", 3, "", "\n"], ";") == ";;1;2;;3;;\n"
    assert FEnum.join([""]) == ""

    assert FEnum.join(fn acc, _ -> acc end, ".") == ""
  end

  test "max/1" do
    assert FEnum.max([1]) == 1
    assert FEnum.max([1, 2, 3]) == 3
    assert FEnum.max([1, [], :a, {}]) == []

    assert FEnum.max([1, 1.0]) === 1
    assert FEnum.max([1.0, 1]) === 1.0

    assert_raise Enum.EmptyError, fn ->
      FEnum.max([])
    end
  end

  test "member?/2" do
    assert FEnum.member?([1, 2, 3], 2)
    refute FEnum.member?([], 0)
    refute FEnum.member?([1, 2, 3], 0)
  end

  test "min/1" do
    assert FEnum.min([1]) == 1
    assert FEnum.min([1, 2, 3]) == 1
    assert FEnum.min([[], :a, {}]) == :a

    assert FEnum.min([1, 1.0]) === 1
    assert FEnum.min([1.0, 1]) === 1.0

    assert_raise Enum.EmptyError, fn ->
      FEnum.min([])
    end
  end

  test "min_max/1" do
    assert FEnum.min_max([1]) == {1, 1}
    assert FEnum.min_max([2, 3, 1]) == {1, 3}
    assert FEnum.min_max([[], :a, {}]) == {:a, []}

    assert FEnum.min_max([1, 1.0]) === {1, 1}
    assert FEnum.min_max([1.0, 1]) === {1.0, 1.0}

    assert_raise Enum.EmptyError, fn ->
      FEnum.min_max([])
    end
  end

  test "reverse/1" do
    assert FEnum.reverse([]) == []
    assert FEnum.reverse([1, 2, 3]) == [3, 2, 1]
    assert FEnum.reverse([5..5]) == [5..5]
  end

  test "slice/2" do
    list = [1, 2, 3, 4, 5]
    assert FEnum.slice(list, 0..0) == [1]
    assert FEnum.slice(list, 0..1) == [1, 2]
    assert FEnum.slice(list, 0..2) == [1, 2, 3]

    assert FEnum.slice(list, 0..10//2) == [1, 3, 5]
    assert FEnum.slice(list, 0..10//3) == [1, 4]
    assert FEnum.slice(list, 0..10//4) == [1, 5]
    assert FEnum.slice(list, 0..10//5) == [1]
    assert FEnum.slice(list, 0..10//6) == [1]

    assert FEnum.slice(list, 0..2//2) == [1, 3]
    assert FEnum.slice(list, 0..2//3) == [1]

    assert FEnum.slice(list, 0..-1//2) == [1, 3, 5]
    assert FEnum.slice(list, 0..-1//3) == [1, 4]
    assert FEnum.slice(list, 0..-1//4) == [1, 5]
    assert FEnum.slice(list, 0..-1//5) == [1]
    assert FEnum.slice(list, 0..-1//6) == [1]

    assert FEnum.slice(list, 1..-1//2) == [2, 4]
    assert FEnum.slice(list, 1..-1//3) == [2, 5]
    assert FEnum.slice(list, 1..-1//4) == [2]
    assert FEnum.slice(list, 1..-1//5) == [2]

    assert FEnum.slice(list, -4..-1//2) == [2, 4]
    assert FEnum.slice(list, -4..-1//3) == [2, 5]
    assert FEnum.slice(list, -4..-1//4) == [2]
    assert FEnum.slice(list, -4..-1//5) == [2]
  end

  test "sort/1" do
    assert FEnum.sort([5, 3, 2, 4, 1]) == [1, 2, 3, 4, 5]
  end

  test "sort/2 with module" do
    assert FEnum.sort([~D[2020-01-01], ~D[2018-01-01], ~D[2019-01-01]], Date) ==
             [~D[2018-01-01], ~D[2019-01-01], ~D[2020-01-01]]

    assert FEnum.sort([~D[2020-01-01], ~D[2018-01-01], ~D[2019-01-01]], {:asc, Date}) ==
             [~D[2018-01-01], ~D[2019-01-01], ~D[2020-01-01]]

    assert FEnum.sort([~D[2020-01-01], ~D[2018-01-01], ~D[2019-01-01]], {:desc, Date}) ==
             [~D[2020-01-01], ~D[2019-01-01], ~D[2018-01-01]]
  end

  test "sort/2 with streams" do
    sort_stream = fn list, sorter -> list |> Stream.map(& &1) |> FEnum.sort(sorter) end

    assert sort_stream.([5, 3, 2, 4, 1], &(&1 >= &2)) == [5, 4, 3, 2, 1]
    assert sort_stream.([5, 3, 2, 4, 1], :asc) == [1, 2, 3, 4, 5]
    assert sort_stream.([5, 3, 2, 4, 1], :desc) == [5, 4, 3, 2, 1]

    assert sort_stream.([3, 2, 1, 3, 2, 3], :asc) == [1, 2, 2, 3, 3, 3]
    assert sort_stream.([3, 2, 1, 3, 2, 3], :desc) == [3, 3, 3, 2, 2, 1]
  end

  test "sum/1" do
    assert FEnum.sum([]) == 0
    assert FEnum.sum([1]) == 1
    assert FEnum.sum([1, 2, 3]) == 6
    assert FEnum.sum([1.1, 2.2, 3.3]) == 6.6
    assert FEnum.sum([-3, -2, -1, 0, 1, 2, 3]) == 0
    assert FEnum.sum(42..42) == 42
    assert FEnum.sum(11..17) == 98
    assert FEnum.sum(17..11//-1) == 98
    assert FEnum.sum(11..-17//-1) == FEnum.sum(-17..11)

    assert_raise ArithmeticError, fn ->
      FEnum.sum([{}])
    end

    assert_raise ArithmeticError, fn ->
      FEnum.sum([1, {}])
    end
  end

  test "product/1" do
    assert FEnum.product([]) == 1
    assert FEnum.product([1]) == 1
    assert FEnum.product([1, 2, 3, 4, 5]) == 120
    assert FEnum.product([1, -2, 3, 4, 5]) == -120
    assert FEnum.product(1..5) == 120
    assert FEnum.product(11..-17//-1) == FEnum.product(-17..11)

    assert_raise ArithmeticError, fn ->
      FEnum.product([{}])
    end

    assert_raise ArithmeticError, fn ->
      FEnum.product([1, {}])
    end

    assert_raise ArithmeticError, fn ->
      FEnum.product(%{a: 1, b: 2})
    end
  end

  test "take/2" do
    assert FEnum.take([1, 2, 3], 0) == []
    assert FEnum.take([1, 2, 3], 1) == [1]
    assert FEnum.take([1, 2, 3], 2) == [1, 2]
    assert FEnum.take([1, 2, 3], 3) == [1, 2, 3]
    assert FEnum.take([1, 2, 3], 4) == [1, 2, 3]
    assert FEnum.take([1, 2, 3], -1) == [3]
    assert FEnum.take([1, 2, 3], -2) == [2, 3]
    assert FEnum.take([1, 2, 3], -4) == [1, 2, 3]
    assert FEnum.take([], 3) == []

    assert_raise FunctionClauseError, fn ->
      FEnum.take([1, 2, 3], 0.0)
    end
  end

  test "to_list/1" do
    assert FEnum.to_list([]) == []
  end

  test "uniq/1" do
    assert FEnum.uniq([5, 1, 2, 3, 2, 1]) == [5, 1, 2, 3]
  end

  test "with_index/2" do
    assert FEnum.with_index([]) == []
    assert FEnum.with_index([1, 2, 3]) == [{1, 0}, {2, 1}, {3, 2}]
    assert FEnum.with_index([1, 2, 3], 10) == [{1, 10}, {2, 11}, {3, 12}]

    assert FEnum.with_index([1, 2, 3], fn element, index -> {index, element} end) ==
             [{0, 1}, {1, 2}, {2, 3}]

    assert FEnum.with_index(1..0//1) == []
    assert FEnum.with_index(1..3) == [{1, 0}, {2, 1}, {3, 2}]
    assert FEnum.with_index(1..3, 10) == [{1, 10}, {2, 11}, {3, 12}]

    assert FEnum.with_index(1..3, fn element, index -> {index, element} end) ==
             [{0, 1}, {1, 2}, {2, 3}]
  end

  test "zip/2" do
    assert FEnum.zip([:a, :b], [1, 2]) == [{:a, 1}, {:b, 2}]
    assert FEnum.zip([:a, :b], [1, 2, 3, 4]) == [{:a, 1}, {:b, 2}]
    assert FEnum.zip([:a, :b, :c, :d], [1, 2]) == [{:a, 1}, {:b, 2}]

    assert FEnum.zip([], [1]) == []
    assert FEnum.zip([1], []) == []
    assert FEnum.zip([], []) == []
  end

  test "zip/2 with infinite streams" do
    assert FEnum.zip([], Stream.cycle([1, 2])) == []
    assert FEnum.zip([], Stream.cycle(1..2)) == []
    assert FEnum.zip(.., Stream.cycle([1, 2])) == []
    assert FEnum.zip(.., Stream.cycle(1..2)) == []

    assert FEnum.zip(Stream.cycle([1, 2]), ..) == []
    assert FEnum.zip(Stream.cycle(1..2), ..) == []
    assert FEnum.zip(Stream.cycle([1, 2]), ..) == []
    assert FEnum.zip(Stream.cycle(1..2), ..) == []
  end
end

defmodule FFEnum.EnumCompatTest.Range do
  # Ranges use custom callbacks for protocols in many operations.
  use ExUnit.Case, async: true

  test "at/3" do
    assert FEnum.at(2..6, 0) == 2
    assert FEnum.at(2..6, 4) == 6
    assert FEnum.at(2..6, 6) == nil
    assert FEnum.at(2..6, -2) == 5
    assert FEnum.at(2..6, -8) == nil

    assert FEnum.at(0..1//-1, 0) == nil
    assert FEnum.at(1..1//5, 0) == 1
    assert FEnum.at(1..3//2, 0) == 1
    assert FEnum.at(1..3//2, 1) == 3
    assert FEnum.at(1..3//2, 2) == nil
    assert FEnum.at(1..3//2, -1) == 3
    assert FEnum.at(1..3//2, -2) == 1
    assert FEnum.at(1..3//2, -3) == nil
  end

  test "chunk_every/2" do
    assert FEnum.chunk_every(1..5, 2) == [[1, 2], [3, 4], [5]]
    assert FEnum.chunk_every(1..10//2, 2) == [[1, 3], [5, 7], [9]]
  end

  test "concat/2" do
    assert FEnum.concat(1..3, 4..5) == [1, 2, 3, 4, 5]
    assert FEnum.concat(1..3, [4, 5]) == [1, 2, 3, 4, 5]
    assert FEnum.concat(1..3, []) == [1, 2, 3]
    assert FEnum.concat(1..3, 0..0) == [1, 2, 3, 0]
    assert FEnum.concat(1..5, 6..10//2) == [1, 2, 3, 4, 5, 6, 8, 10]
    assert FEnum.concat(1..5, 0..1//-1) == [1, 2, 3, 4, 5]
    assert FEnum.concat(1..5, 1..0//1) == [1, 2, 3, 4, 5]
  end

  test "count/1" do
    assert FEnum.count(1..5) == 5
    assert FEnum.count(1..1) == 1
    assert FEnum.count(1..9//2) == 5
    assert FEnum.count(1..10//2) == 5
    assert FEnum.count(1..11//2) == 6
    assert FEnum.count(1..11//-2) == 0
    assert FEnum.count(11..1//-2) == 6
    assert FEnum.count(10..1//-2) == 5
    assert FEnum.count(9..1//-2) == 5
    assert FEnum.count(9..1//2) == 0
  end

  test "dedup/1" do
    assert FEnum.dedup(1..3) == [1, 2, 3]
    assert FEnum.dedup(1..3//2) == [1, 3]
  end

  test "drop/2" do
    assert FEnum.drop(1..3, 0) == [1, 2, 3]
    assert FEnum.drop(1..3, 1) == [2, 3]
    assert FEnum.drop(1..3, 2) == [3]
    assert FEnum.drop(1..3, 3) == []
    assert FEnum.drop(1..3, 4) == []
    assert FEnum.drop(1..3, -1) == [1, 2]
    assert FEnum.drop(1..3, -2) == [1]
    assert FEnum.drop(1..3, -4) == []
    assert FEnum.drop(1..0//-1, 3) == []

    assert FEnum.drop(1..9//2, 2) == [5, 7, 9]
    assert FEnum.drop(1..9//2, -2) == [1, 3, 5]
    assert FEnum.drop(9..1//-2, 2) == [5, 3, 1]
    assert FEnum.drop(9..1//-2, -2) == [9, 7, 5]
  end

  test "empty?/1" do
    refute FEnum.empty?(1..0//-1)
    refute FEnum.empty?(1..2)
    refute FEnum.empty?(1..2//2)
    assert FEnum.empty?(1..2//-2)
  end

  test "fetch!/2" do
    assert FEnum.fetch!(2..6, 0) == 2
    assert FEnum.fetch!(2..6, 4) == 6
    assert FEnum.fetch!(2..6, -1) == 6
    assert FEnum.fetch!(2..6, -2) == 5
    assert FEnum.fetch!(-2..-6//-1, 0) == -2
    assert FEnum.fetch!(-2..-6//-1, 4) == -6

    assert_raise Enum.OutOfBoundsError, fn ->
      FEnum.fetch!(2..6, 8)
    end

    assert_raise Enum.OutOfBoundsError, fn ->
      FEnum.fetch!(-2..-6//-1, 8)
    end

    assert_raise Enum.OutOfBoundsError, fn ->
      FEnum.fetch!(2..6, -8)
    end
  end

  test "join/2" do
    assert FEnum.join(1..0//-1, " = ") == "1 = 0"
    assert FEnum.join(1..3, " = ") == "1 = 2 = 3"
    assert FEnum.join(1..3) == "123"
  end

  test "max/1" do
    assert FEnum.max(1..1) == 1
    assert FEnum.max(1..3) == 3
    assert FEnum.max(3..1//-1) == 3

    assert FEnum.max(1..9//2) == 9
    assert FEnum.max(1..10//2) == 9
    assert FEnum.max(-1..-9//-2) == -1

    assert_raise Enum.EmptyError, fn -> FEnum.max(1..0//1) end
  end

  test "member?/2" do
    assert FEnum.member?(1..3, 2)
    refute FEnum.member?(1..3, 0)

    assert FEnum.member?(1..9//2, 1)
    assert FEnum.member?(1..9//2, 9)
    refute FEnum.member?(1..9//2, 10)
    refute FEnum.member?(1..10//2, 10)
    assert FEnum.member?(1..2//2, 1)
    refute FEnum.member?(1..2//2, 2)

    assert FEnum.member?(-1..-9//-2, -1)
    assert FEnum.member?(-1..-9//-2, -9)
    refute FEnum.member?(-1..-9//-2, -8)

    refute FEnum.member?(1..0//1, 1)
    refute FEnum.member?(0..1//-1, 1)
  end

  test "min/1" do
    assert FEnum.min(1..1) == 1
    assert FEnum.min(1..3) == 1

    assert FEnum.min(1..9//2) == 1
    assert FEnum.min(1..10//2) == 1
    assert FEnum.min(-1..-9//-2) == -9

    assert_raise Enum.EmptyError, fn -> FEnum.min(1..0//1) end
  end

  test "min_max/1" do
    assert FEnum.min_max(1..1) == {1, 1}
    assert FEnum.min_max(1..3) == {1, 3}
    assert FEnum.min_max(3..1//-1) == {1, 3}

    assert FEnum.min_max(1..9//2) == {1, 9}
    assert FEnum.min_max(1..10//2) == {1, 9}
    assert FEnum.min_max(-1..-9//-2) == {-9, -1}

    assert_raise Enum.EmptyError, fn -> FEnum.min_max(1..0//1) end
  end

  test "reverse/1" do
    assert FEnum.reverse(0..0) == [0]
    assert FEnum.reverse(1..3) == [3, 2, 1]
    assert FEnum.reverse(-3..5) == [5, 4, 3, 2, 1, 0, -1, -2, -3]
    assert FEnum.reverse(5..5) == [5]

    assert FEnum.reverse(0..1//-1) == []
    assert FEnum.reverse(1..10//2) == [9, 7, 5, 3, 1]
  end

  test "slice/2" do
    assert FEnum.slice(1..5, 0..0) == [1]
    assert FEnum.slice(1..5, 0..1) == [1, 2]
    assert FEnum.slice(1..5, 0..2) == [1, 2, 3]
    assert FEnum.slice(1..5, 1..2) == [2, 3]
    assert FEnum.slice(1..5, 1..0//1) == []
    assert FEnum.slice(1..5, 2..5) == [3, 4, 5]
    assert FEnum.slice(1..5, 2..6) == [3, 4, 5]
    assert FEnum.slice(1..5, 4..4) == [5]
    assert FEnum.slice(1..5, 5..5) == []
    assert FEnum.slice(1..5, 6..5//1) == []
    assert FEnum.slice(1..5, 6..0//1) == []
    assert FEnum.slice(1..5, -3..0) == []
    assert FEnum.slice(1..5, -3..1) == []
    assert FEnum.slice(1..5, -6..0) == [1]
    assert FEnum.slice(1..5, -6..5) == [1, 2, 3, 4, 5]
    assert FEnum.slice(1..5, -6..-1) == [1, 2, 3, 4, 5]
    assert FEnum.slice(1..5, -5..-1) == [1, 2, 3, 4, 5]
    assert FEnum.slice(1..5, -5..-3) == [1, 2, 3]

    assert FEnum.slice(1..5, 0..10//2) == [1, 3, 5]
    assert FEnum.slice(1..5, 0..10//3) == [1, 4]
    assert FEnum.slice(1..5, 0..10//4) == [1, 5]
    assert FEnum.slice(1..5, 0..10//5) == [1]
    assert FEnum.slice(1..5, 0..10//6) == [1]

    assert FEnum.slice(1..5, 0..2//2) == [1, 3]
    assert FEnum.slice(1..5, 0..2//3) == [1]

    assert FEnum.slice(1..5, 0..-1//2) == [1, 3, 5]
    assert FEnum.slice(1..5, 0..-1//3) == [1, 4]
    assert FEnum.slice(1..5, 0..-1//4) == [1, 5]
    assert FEnum.slice(1..5, 0..-1//5) == [1]
    assert FEnum.slice(1..5, 0..-1//6) == [1]

    assert FEnum.slice(1..5, 1..-1//2) == [2, 4]
    assert FEnum.slice(1..5, 1..-1//3) == [2, 5]
    assert FEnum.slice(1..5, 1..-1//4) == [2]
    assert FEnum.slice(1..5, 1..-1//5) == [2]

    assert FEnum.slice(1..5, -4..-1//2) == [2, 4]
    assert FEnum.slice(1..5, -4..-1//3) == [2, 5]
    assert FEnum.slice(1..5, -4..-1//4) == [2]
    assert FEnum.slice(1..5, -4..-1//5) == [2]

    assert FEnum.slice(5..1//-1, 0..0) == [5]
    assert FEnum.slice(5..1//-1, 0..1) == [5, 4]
    assert FEnum.slice(5..1//-1, 0..2) == [5, 4, 3]
    assert FEnum.slice(5..1//-1, 1..2) == [4, 3]
    assert FEnum.slice(5..1//-1, 1..0//1) == []
    assert FEnum.slice(5..1//-1, 2..5) == [3, 2, 1]
    assert FEnum.slice(5..1//-1, 2..6) == [3, 2, 1]
    assert FEnum.slice(5..1//-1, 4..4) == [1]
    assert FEnum.slice(5..1//-1, 5..5) == []
    assert FEnum.slice(5..1//-1, 6..5//1) == []
    assert FEnum.slice(5..1//-1, 6..0//1) == []
    assert FEnum.slice(5..1//-1, -6..0) == [5]
    assert FEnum.slice(5..1//-1, -6..5) == [5, 4, 3, 2, 1]
    assert FEnum.slice(5..1//-1, -6..-1) == [5, 4, 3, 2, 1]
    assert FEnum.slice(5..1//-1, -5..-1) == [5, 4, 3, 2, 1]
    assert FEnum.slice(5..1//-1, -5..-3) == [5, 4, 3]

    assert FEnum.slice(1..10//2, 0..0) == [1]
    assert FEnum.slice(1..10//2, 0..1) == [1, 3]
    assert FEnum.slice(1..10//2, 0..2) == [1, 3, 5]
    assert FEnum.slice(1..10//2, 1..2) == [3, 5]
    assert FEnum.slice(1..10//2, 1..0//1) == []
    assert FEnum.slice(1..10//2, 2..5) == [5, 7, 9]
    assert FEnum.slice(1..10//2, 2..6) == [5, 7, 9]
    assert FEnum.slice(1..10//2, 4..4) == [9]
    assert FEnum.slice(1..10//2, 5..5) == []
    assert FEnum.slice(1..10//2, 6..5//1) == []
    assert FEnum.slice(1..10//2, 6..0//1) == []
    assert FEnum.slice(1..10//2, -3..0) == []
    assert FEnum.slice(1..10//2, -3..1) == []
    assert FEnum.slice(1..10//2, -6..0) == [1]
    assert FEnum.slice(1..10//2, -6..5) == [1, 3, 5, 7, 9]
    assert FEnum.slice(1..10//2, -6..-1) == [1, 3, 5, 7, 9]
    assert FEnum.slice(1..10//2, -5..-1) == [1, 3, 5, 7, 9]
    assert FEnum.slice(1..10//2, -5..-3) == [1, 3, 5]

    assert_raise ArgumentError,
                 "Enum.slice/2 does not accept ranges with negative steps, got: 1..3//-2",
                 fn -> FEnum.slice(1..5, 1..3//-2) end
  end

  test "sort/1" do
    assert FEnum.sort(3..1//-1) == [1, 2, 3]
    assert FEnum.sort(2..1//-1) == [1, 2]
    assert FEnum.sort(1..1) == [1]
  end

  test "sort/2" do
    assert FEnum.sort(3..1//-1, &(&1 > &2)) == [3, 2, 1]
    assert FEnum.sort(2..1//-1, &(&1 > &2)) == [2, 1]
    assert FEnum.sort(1..1, &(&1 > &2)) == [1]

    assert FEnum.sort(3..1//-1, :asc) == [1, 2, 3]
    assert FEnum.sort(3..1//-1, :desc) == [3, 2, 1]
  end

  test "sum/1" do
    assert FEnum.sum(0..0) == 0
    assert FEnum.sum(1..1) == 1
    assert FEnum.sum(1..3) == 6
    assert FEnum.sum(0..100) == 5050
    assert FEnum.sum(10..100) == 5005
    assert FEnum.sum(100..10//-1) == 5005
    assert FEnum.sum(-10..-20//-1) == -165
    assert FEnum.sum(-10..2) == -52

    assert FEnum.sum(0..1//-1) == 0
    assert FEnum.sum(1..9//2) == 25
    assert FEnum.sum(1..10//2) == 25
    assert FEnum.sum(9..1//-2) == 25
  end

  test "take/2" do
    assert FEnum.take(1..3, 0) == []
    assert FEnum.take(1..3, 1) == [1]
    assert FEnum.take(1..3, 2) == [1, 2]
    assert FEnum.take(1..3, 3) == [1, 2, 3]
    assert FEnum.take(1..3, 4) == [1, 2, 3]
    assert FEnum.take(1..3, -1) == [3]
    assert FEnum.take(1..3, -2) == [2, 3]
    assert FEnum.take(1..3, -4) == [1, 2, 3]
    assert FEnum.take(1..0//-1, 3) == [1, 0]
    assert FEnum.take(1..0//1, -3) == []
  end

  test "to_list/1" do
    assert FEnum.to_list(1..3) == [1, 2, 3]
    assert FEnum.to_list(1..3//2) == [1, 3]
    assert FEnum.to_list(3..1//-2) == [3, 1]
    assert FEnum.to_list(0..1//-1) == []
  end

  test "uniq/1" do
    assert FEnum.uniq(1..3) == [1, 2, 3]
  end

  test "with_index/2" do
    assert FEnum.with_index(1..3) == [{1, 0}, {2, 1}, {3, 2}]
    assert FEnum.with_index(1..3, 3) == [{1, 3}, {2, 4}, {3, 5}]
  end

  test "zip/2" do
    assert FEnum.zip([:a, :b], 1..2) == [{:a, 1}, {:b, 2}]
    assert FEnum.zip([:a, :b], 1..4) == [{:a, 1}, {:b, 2}]
    assert FEnum.zip([:a, :b, :c, :d], 1..2) == [{:a, 1}, {:b, 2}]

    assert FEnum.zip(1..2, [:a, :b]) == [{1, :a}, {2, :b}]
    assert FEnum.zip(1..4, [:a, :b]) == [{1, :a}, {2, :b}]
    assert FEnum.zip(1..2, [:a, :b, :c, :d]) == [{1, :a}, {2, :b}]

    assert FEnum.zip(1..2, 1..2) == [{1, 1}, {2, 2}]
    assert FEnum.zip(1..4, 1..2) == [{1, 1}, {2, 2}]
    assert FEnum.zip(1..2, 1..4) == [{1, 1}, {2, 2}]

    assert FEnum.zip(1..10//2, 1..10//3) == [{1, 1}, {3, 4}, {5, 7}, {7, 10}]
    assert FEnum.zip(0..1//-1, 1..10//3) == []
  end
end

defmodule FFEnum.EnumCompatTest.Map do
  # Maps use different protocols path than lists and ranges in the cases below.
  use ExUnit.Case, async: true

  test "reverse/1" do
    assert FEnum.reverse(%{}) == []
    assert FEnum.reverse(MapSet.new()) == []

    map = %{a: 1, b: 2, c: 3}
    assert FEnum.reverse(map) == Map.to_list(map) |> FEnum.reverse()
  end

  test "slice/2" do
    map = %{a: 1, b: 2, c: 3, d: 4, e: 5}
    [x1, x2, x3 | _] = Map.to_list(map)
    assert FEnum.slice(map, 0..0) == [x1]
    assert FEnum.slice(map, 0..1) == [x1, x2]
    assert FEnum.slice(map, 0..2) == [x1, x2, x3]
  end
end

defmodule FFEnum.EnumCompatTest.SideEffects do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  test "take/2 with side effects" do
    stream =
      Stream.unfold(1, fn x ->
        IO.puts(x)
        {x, x + 1}
      end)

    assert capture_io(fn ->
             FEnum.take(stream, 1)
           end) == "1\n"
  end

  @tag :tmp_dir
  test "take/2 does not consume next without a need", config do
    path = Path.join(config.tmp_dir, "oneliner.txt")
    File.mkdir(Path.dirname(path))

    try do
      File.write!(path, "ONE")

      File.open!(path, [], fn file ->
        iterator = IO.stream(file, :line)
        assert FEnum.take(iterator, 1) == ["ONE"]
        assert FEnum.take(iterator, 5) == []
      end)
    after
      File.rm(path)
    end
  end

  # Removed: "take/2 with no elements works as no-op"
  # Requires PathHelpers module from Elixir's internal test suite
end

defmodule FFEnum.EnumCompatTest.Function do
  use ExUnit.Case, async: true

  test "raises Protocol.UndefinedError for funs of wrong arity" do
    assert_raise Protocol.UndefinedError, fn ->
      FEnum.to_list(fn -> nil end)
    end
  end
end
