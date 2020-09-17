defmodule Automaton.Types.DECPOMDP.Config do
  use Ecto.Schema

  alias AtomType

  embedded_schema do
    field(:type)
  end

  def new(data) do
    struct(WorldConfig, data)
  end
end
