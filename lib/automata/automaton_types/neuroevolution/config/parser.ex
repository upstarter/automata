defmodule Automaton.Types.NE.Config.Parser do
  @moduledoc """
  High level automaton_config parsing policy for NE specific user configs.
  """

  @doc """
  Determines the node_type given the `automaton_config`.

  Returns `node_type`.

  ## Examples
      iex> automaton_config = [node_type: :selector]
      iex> Automaton.Config.Parser.node_type(automaton_config)
      :selector
  """

  @spec call(type: atom, node_type: atom) :: tuple
  def call(automaton_config) do
    # config = %Config{
    #   state_spaces: automaton_config[:state_spaces]
    # }

    automaton_config
  end
end
