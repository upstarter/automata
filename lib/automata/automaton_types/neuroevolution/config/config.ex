defmodule Automaton.Types.NE.Config do
  use Ecto.Schema

  alias AtomType

  embedded_schema do
    field(:type)
  end

  def new(data) do
    struct(__MODULE__, data)
  end
end
