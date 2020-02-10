defmodule Automata do
  @moduledoc """

  """
  use Application
  alias Automata.Automaton

  def start(_type, _args) do
    # TODO: autoload all the user-defined nodes from the nodes/ directory
    # to build this structure. Or is there a better way?
    nodes_config = [
      [name: "MockUserNode1", mfa: {MockUserNode1, :start_link, []}],
      [name: "MockUserNode2", mfa: {MockUserNode2, :start_link, []}]
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
