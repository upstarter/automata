defmodule Automaton do
  @moduledoc """
    This is the primary user control interface to the Automata system. The
    configration parameters are used to inject the appropriate modules into the
    user-defined agents.

  """

  defmacro __using__(user_opts) do
    Automaton.Types.Typology.call(user_opts)
  end
end
