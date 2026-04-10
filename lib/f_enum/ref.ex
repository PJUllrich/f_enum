defmodule FEnum.Ref do
  @moduledoc """
  Opaque wrapper around a Rust `ResourceArc<RwLock<Vec<i64>>>`.

  Used in chain mode to keep data in Rust between operations.
  """

  defstruct [:resource, :length]

  @type t :: %__MODULE__{
          resource: reference(),
          length: non_neg_integer()
        }
end
