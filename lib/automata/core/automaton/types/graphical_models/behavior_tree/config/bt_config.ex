defmodule Automaton.Types.BT.Config do
  alias Automaton.Types.BT.CompositeServer
  alias Automaton.Types.BT.ComponentServer

  defstruct node_type: nil,
            c_types: CompositeServer.types(),
            cn_types: ComponentServer.types(),
            allowed_node_types: CompositeServer.types() ++ ComponentServer.types()
end
