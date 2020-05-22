defmodule WorldConfig do
  use Ecto.Schema

  embedded_schema do
    field(:world)
    field(:automata_config)
  end
end
