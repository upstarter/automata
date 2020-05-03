defmodule Automata do
  @moduledoc """

  """
  use Application

  def start(_type, _args) do
    # TODO: recursively autoload all the user-defined nodes from the worlds/ directory tree
    # to build the data structure of root nodes needed to spawn the automata.

    # USER DEFINED BT ROOT(CompositeServer) NODES (AUTOMATA)
    # these are started specifically in `lib/automaton_server.ex`
    nodes_config = [
      [name: "Automaton1", mfa: {MockSeq1, :start_link, []}]
      # [name: "Automaton2", mfa: {MockSel1, :start_link, []}]
    ]

    start_nodes(nodes_config)
  end

  def start_nodes(nodes_config) do
    Automata.Supervisor.start_link(nodes_config)
  end

  def status(action_name) do
    Automata.Server.status(action_name)
  end
end
