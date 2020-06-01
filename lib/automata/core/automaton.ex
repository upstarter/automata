defmodule Automaton do
  @moduledoc """
  This is the primary user boundary point control interface to the Automata
  system. The `automaton_config` parameters flow from the root through the
  supervision tree on startup and are interpreted by the Typology system to inject
  the appropriate components into the user-defined agents.
  """

  defmacro __using__(automaton_config) do
    Automaton.Types.Typology.call(automaton_config)
  end
end
