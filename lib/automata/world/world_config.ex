defmodule WorldConfig do
  use Ecto.Schema

  embedded_schema do
    field(:world)
    field(:ontology)
    field(:environs)
    field(:automata)
  end

  def new(data) do
    struct(WorldConfig, data)
  end

  @type t :: %__MODULE__{
          world: list,
          ontology: list,
          environs: list,
          automata: list
        }
end
