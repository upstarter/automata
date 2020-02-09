defmodule Automata do
  @moduledoc """

  """
  use Application
  alias Automata.Automaton

  def start(_type, _args) do
    # TODO: autoload all the user-defined nodes from the nodes/ directory
    # to build this structure. Or is there a better way?
    nodes_config = [
      [name: "ChildBehavior1", mfa: {ChildBehavior1, :start_link, []}],
      [name: "ChildBehavior2", mfa: {ChildBehavior2, :start_link, []}]
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
