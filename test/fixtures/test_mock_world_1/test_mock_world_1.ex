defmodule TestMockWorld1 do
  @moduledoc """
  Used for experimentation and QA testing until testing strategy devised.
  """
  use Automata.World,
    # highest level meta representations. Ontological working memory can be used
    # to describe meta-state & relations in the world in terms of perspectives,
    # constraints, representations(environs), types of contexts, classes of
    # objects/agents and their types, objective predictive representations
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
    automata: [TestMockSeq1]
end
