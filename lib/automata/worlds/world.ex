defmodule Automata.World do
  @moduledoc """
  A World is made up of Agents (automata) which interpret & act based on
  global(all-agents) & local(per-agent) Obervations (from State Space
  Representations) and Events from the World.

  Events arise in the world, and agents with matching traits and capabilities
  respond to the events individually and collectively.

  The further in the supervision tree you get to the `Automaton.Types` the less
  information you have about the global situation, and vice versa.

  Therefore, it will be wise to thoughtfully provide abstractions for robust
  state space, blackboard, ontological representations, etc. for coordination of
  interacting agents.

  The World can also be the source of network calls for the world, called into
  from running agents

  Local and/or external databases can provide long term world storage.

  ## Usage
  ```elixir
  use Automata.World,
    # An **Ontology** is for highest level meta representations for a **World**. It
    # gives us a way to provide shared goals, beliefs, features. Ontological
    # working memory can be used to describe inter-relations in terms of
    # perspectives, constraints, environs, stratified classes of objects/agents and
    # their types, objective predictive representations
    ontology: [],

    # The representations describing the world ontology may determine the initial
    # environment and vice versa, they are dependent and can be mixed and matched.
    environs: [],

    # the Automata configured to operate in this world, given the environs
    # TODO: match (or automatch) the automata to an environ or all environs
    # perhaps like: `automata: [MockAgent1: :psr, MockRobot1: :dec_pomdp]`
    # or inferred at automata level policies
    automata: [MockSeq1]
  ```
  """

  defmacro __using__(_automaton_config) do
    prepend =
      quote do
        # use GenServer
      end

    [prepend]
  end
end
