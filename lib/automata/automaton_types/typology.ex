defmodule Automaton.Types.Typology do
  @moduledoc """
  ## Types are builtin state space representations.

  Typology is for interpretation of what state space representation to use based
  on user configuration. Each type has a `config/` dir to handle user
  config parsing and interpretation specific to its domain.
  """
  alias Automaton.Types.BT
  alias Automaton.Types.TWEANN
  alias Automaton.Types.MAB

  @types [:behavior_tree]
  def types, do: @types

  # @spec call(nonempty_list()) :: nonempty_list()
  def call(automaton_config) do
    type =
      automaton_config[:type]
      |> case do
        :behavior_tree ->
          quote do: use(BT, automaton_config: unquote(automaton_config))

        :tweann ->
          quote do: use(TWEANN, automaton_config: unquote(automaton_config))

        :bandit ->
          quote do: use(MAB, automaton_config: unquote(automaton_config))

        # TODO: need this for children.
        # use parent type? raise error?
        nil ->
          quote do: use(BT, automaton_config: unquote(automaton_config))
      end

    [type]
  end
end
