defmodule Automata.Types.Typology do
  @moduledoc """
  ## Types are builtin state space representations.

  Typology is for interpretation of what state space representation to use based
  on user configuration. Each type has a `config/` dir to handle user
  config parsing and interpretation specific to it's domain.

  """

  @types [:behavior_tree]
  def types, do: @types

  def call(_automata_config) do
  end
end
