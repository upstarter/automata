defmodule Automaton.Types.BT.Config do
  use Ecto.Schema

  alias AtomType

  embedded_schema do
    field(:node_type)
    field(:c_types)
    field(:cn_types)
    field(:allowed_node_types)
  end

  def new(data) do
    struct(__MODULE__, data)
  end
end
