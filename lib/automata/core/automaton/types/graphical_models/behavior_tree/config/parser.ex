defmodule Automaton.Types.BT.Config.Parser do
  @moduledoc """
  Purely Functional high level parsing policy for BT specific
  config from `automaton_config`.

  ## User Provided State Space parsing & interpretation boundary point
  ## Delegate provided user input to modules corresponding to config state spaces
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
  def node_type(opts) do
    c_types = CompositeServer.types()
    cn_types = ComponentServer.types()
    allowed_node_types = c_types ++ cn_types
    node_type = opts[:node_type]

    unless Enum.member?(allowed_node_types, node_type), do: raise("NodeTypeError")
    node_type
  end
end
