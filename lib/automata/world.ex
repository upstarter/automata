defmodule Automata.World do
  @moduledoc """
  The world contains environments and automata that operate on/from them.
  User defined automata state spaces and blackboards serve as short term working memory
  for the world.

  Local and/or external databases can provide long term world storage.
  """

  defmacro __using__(_automaton_config) do
  end
end
