defmodule Automaton.Types.BT.Config.Parser do
  @moduledoc """
  High level automaton_config parsing policy for BT specific user configs.
  """
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
  def node_type(automaton_config) do
    c_types = CompositeServer.types()
    cn_types = ComponentServer.types()
    allowed_node_types = c_types ++ cn_types
    node_type = automaton_config[:node_type]

    unless Enum.member?(allowed_node_types, node_type), do: raise("NodeTypeError")
    node_type
  end
end
