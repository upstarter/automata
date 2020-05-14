defmodule MockWorld1 do
  @moduledoc """

  """
  use Automata.World,
    # the Automata configured for this world
    automata: [MockSeq1]
end
