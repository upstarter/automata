defmodule Automaton.Types.BT.Config.Parser do
  @moduledoc """
  High level automaton_config parsing policy for BT specific user configs.
  """

  alias Automaton.Types.BT.Config

  @doc """
  Determines the node_type given the `automaton_config`.

  Returns `node_type`.

  ## Examples
      iex> automaton_config = [node_type: :selector]
      iex> Automaton.Config.Parser.node_type(automaton_config)
      :selector
  """
  def call(automaton_config) do
    config = %Config{
      node_type: automaton_config[:node_type]
    }

    unless Enum.member?(config.allowed_node_types, config.node_type),
      do: raise("NodeTypeError")

    {config.node_type, config.c_types, config.cn_types}
  end
end
