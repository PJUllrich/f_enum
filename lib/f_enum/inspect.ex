defimpl Inspect, for: FEnum.Ref do
  import Inspect.Algebra

  def inspect(%FEnum.Ref{resource: resource, length: length}, _opts) do
    preview = FEnum.Native.nif_inspect(resource, 5)

    suffix =
      if length > 5,
        do: ", ...",
        else: ""

    inner = Enum.map_join(preview, ", ", &Integer.to_string/1)

    concat([
      "#FEnum.Ref<[",
      inner,
      suffix,
      "] i64, length: ",
      Integer.to_string(length),
      ">"
    ])
  end
end
