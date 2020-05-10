defmodule Automaton.Config.UserConfigParser do
  @moduledoc """
  High level user-config parsing policy.

  ## User Provided State Space parsing & interpretation boundary point
  ## Delegate provided user input to corresponding modules
  """
  alias Automaton.CompositeServer
  alias Automaton.ComponentServer

  @doc """
  Determines the node_type given the `user_opts`.

  Returns `node_type`.

  ## Examples
      iex> user_opts = [node_type: :selector]
      iex> Automaton.UserConfigParser.node_type(user_opts)
      :selector
  """
  def node_type(user_opts) do
    c_types = CompositeServer.types()
    cn_types = ComponentServer.types()
    allowed_node_types = c_types ++ cn_types
    node_type = user_opts[:node_type]
    unless Enum.member?(allowed_node_types, node_type), do: raise("NodeTypeError")
    node_type
  end
end
