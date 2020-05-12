defmodule Automata do
  @moduledoc """

  """
  use Application

  def start(_type, _args) do
    # TODO: recursively autoload all the user-defined agents from the worlds/ directory tree
    # to build the data structure of root agents needed to spawn the automata.

    # the user agents are started in `lib/core/control/automaton/agent_server.ex`
    agents_config = [
      [name: "Automaton1", mfa: {MockSeq1, :start_link, []}]
      # [name: "Automaton2", mfa: {MockSel1, :start_link, []}]
    ]

    start_agents(agents_config)
  end

  def start_agents(agents_config) do
    Automata.Supervisor.start_link(agents_config)
  end

  def status(agent_name) do
    Automata.Server.status(agent_name)
  end
end
