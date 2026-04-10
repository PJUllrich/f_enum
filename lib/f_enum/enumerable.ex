defimpl Enumerable, for: FEnum.Ref do
  alias FEnum.Native

  def count(%FEnum.Ref{length: length}), do: {:ok, length}

  def member?(%FEnum.Ref{resource: resource}, value) when is_integer(value) do
    {:ok, Native.nif_member(resource, value)}
  end

  def member?(_ref, _value), do: {:ok, false}

  def slice(%FEnum.Ref{resource: resource, length: length}) do
    slicer = fn start, count, _step ->
      Native.nif_to_list(Native.nif_slice(resource, start, count))
    end

    {:ok, length, slicer}
  end

  def reduce(%FEnum.Ref{resource: resource}, acc, fun) do
    list = Native.nif_to_list(resource)
    Enumerable.List.reduce(list, acc, fun)
  end
end
