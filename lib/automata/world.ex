defmodule Automata.World do
  @moduledoc """
  The world contains environments and automata that operate on/from them.
  User defined automata state spaces and blackboards serve as short term working memory
  for the world.

  The further in the supervision tree you get to the `Automaton.Types` the less
  information you have about the global situation, and vice versa.

  Therefore, it will be wise to thoughtfully provide abstractions for robust state space,
  blackboard, ontological representations, etc. for coordination of interacting agents.

  Can also be the source of network calls for the world, called into from running agents.

  Local and/or external databases can provide long term world storage.
  """

  defmacro __using__(_automaton_config) do
  end
end
