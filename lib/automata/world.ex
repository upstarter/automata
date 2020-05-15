defmodule Automata.World do
  @moduledoc """
  The world contains environments and automata that operate on/from them. User
  defined automata state spaces (as distinct from automaton state spaces) and
  blackboards serve as short term working memory for the world.

  The further in the supervision tree you get to the `Automaton.Types` the less
  information you have about the global situation, and vice versa.

  Therefore, it will be wise to thoughtfully provide abstractions for robust state space,
  blackboard, ontological representations, etc. for coordination of interacting agents.

  Can also be the source of network calls for the world, called into from running agents.

  Local and/or external databases can provide long term world storage.

  ## Usage
  ```elixir
  use Automata.World,
    # highest level meta representations. Ontological working memory can be used
    # to describe meta-state & relations in the world in terms of perspectives,
    # constraints, representations(environs), types of contexts, classes of
    # objects/agents and their types, objective & subjective representations
    ontology: [],

    # the initial stratified state space representations describing the world
    # ontology may determine the environment and vice versa, they are dependent
    # and can be mixed and matched
    # stratified by design and/or ontological representations
    environs: [],
    
    # the Automata configured to operate in this world, given the environs
    # TODO: match (or automatch) the automata to an environ or all environs
    # perhaps like: `automata: [MockAgent1: :psr, MockRobot1: :dec_pomdp]`
    # or inferred at automata level policies
    automata: [MockSeq1]
  ```
  """

  defmacro __using__(_automaton_config) do
  end
end
