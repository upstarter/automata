defmodule Automata do
  @moduledoc """

  """
  use Application
  alias Automata.Automaton

  def start(_type, _args) do
    # TODO: do we want to autoload all the user-defined nodes from the nodes/ directory
    # to build this structure? Or is there a better way?
    nodes_config = [
      [name: "Automaton1", mfa: {Automaton, :start_link, []}, size: 4],
      [name: "Automaton2", mfa: {Automaton, :start_link, []}, size: 2],
      [name: "Automaton3", mfa: {Automaton, :start_link, []}, size: 1]
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
