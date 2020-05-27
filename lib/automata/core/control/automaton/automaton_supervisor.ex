defmodule Automata.AutomatonSupervisor do
  @moduledoc """
  Runs as a child of `Automata.AutomataSupervisor` and supervises the
  `Automaton.AgentServer` which is a delegate for lifecycle management of the user
  agents and starts the agents under the `Automata.AgentSupervisor`.

  This supervisor uses strategy `:one_for_all` to ensure that errors restart the
  entire supervision tree including the `Automaton.AgentServer`.
  """
  use Supervisor

  def start_link(automaton_config) do
    Supervisor.start_link(__MODULE__, automaton_config,
      name: :"#{automaton_config[:name]}Supervisor"
    )
  end

  def init(automaton_config) do
    # No DynamicSupervisor since only one_for_one supported
    opts = [
      strategy: :one_for_all
    ]

    children = [
      {Automaton.AgentServer, [self(), automaton_config]}
    ]

    Supervisor.init(children, opts)
  end

  def child_spec(automaton_config) do
    %{
      id: :"#{automaton_config[:name]}Supervisor",
      start: {__MODULE__, :start_link, automaton_config},
      type: :supervisor
    }
  end
end
