defmodule Automata do
  @moduledoc """

  """
  use Application
  alias Automata.Automaton

  def start(_type, _args) do
    # TODO: recursively autoload all the user-defined nodes from the nodes/ directory tree
    # to build this/a data structure to spawn the automata.
    nodes_config = [
      [name: "Automaton1", mfa: {MockSequence1, :start_link, []}],
      [name: "Automaton2", mfa: {MockSelector1, :start_link, []}]
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
