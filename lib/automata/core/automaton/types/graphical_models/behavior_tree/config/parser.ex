defmodule Automaton.Types.BT.Config.Parser do
  @moduledoc """
  High level automaton_config parsing policy for BT specific user configs.
  """

  alias Automaton.Types.BT.Config
  alias Automaton.Types.BT.CompositeServer
  alias Automaton.Types.BT.ComponentServer

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
    config = %Config{
      node_type: automaton_config[:node_type],
      c_types: CompositeServer.types(),
      cn_types: ComponentServer.types(),
      allowed_node_types: CompositeServer.types() ++ ComponentServer.types()
    }

    unless Enum.member?(config.allowed_node_types, config.node_type),
      do: raise("NodeTypeError")

    {config.node_type, config.c_types, config.cn_types}
  end
end
