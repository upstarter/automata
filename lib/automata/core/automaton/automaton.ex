defmodule Automaton do
  @moduledoc """
    This is the primary user boundary point control interface to the Automata
    system. The configration parameters flow from the root through the
    supervision tree on startup and are used to inject the appropriate modules
    into the user-defined agents.
  """

  defmacro __using__(user_config) do
    Automaton.Types.Typology.call(user_config)
  end
end
