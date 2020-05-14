defmodule Automata.Types.Typology do
  @moduledoc """
  ## Types are builtin state space representations.

  Typology is for interpretation of what state space representation to use based
  on user configuration. Each type has a `config/` dir to handle user
  config parsing and interpretation specific to it's domain.
  """
  alias Automata.Types.BT

  @types [:behavior_tree]
  def types, do: @types

  def call(automaton_config) do
    type =
      cond do
        automaton_config[:type] == :behavior_tree ->
          quote do: use(BT, automaton_config: unquote(automaton_config))

        # TODO: need this for children.
        # use parent type? raise error?
        automaton_config[:type] == nil ->
          quote do: use(BT, automaton_config: unquote(automaton_config))
      end

    [type]
  end
end
