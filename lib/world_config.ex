defmodule WorldConfig do
  use Ecto.Schema

  embedded_schema do
    field(:world)
    field(:ontology)
    field(:environs)
    field(:automata_config)
  end

  def new(data) do
    struct(WorldConfig, data)
  end
end
