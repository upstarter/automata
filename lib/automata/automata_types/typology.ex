defmodule Automata.Types.Typology do
  @moduledoc """
  ## Types are builtin state space representations.

  Typology is for interpretation of what state space representation to use based
  on user configuration. Each type has a `config/` dir to handle user
  config parsing and interpretation specific to that types domain.
  """

  @types [:behavior_tree]
  def types, do: @types

  @doc """
  ## TODO: determine layers and levels of abstraction for builtins and custom support
    - ontology, environs, automata type specific protocols and/or behaviours.

    Using information from the World, including the agent configurations, initialize
    the state space representations according to the ontology.
  """
  def call(world_config) do
    world_config
  end
end
