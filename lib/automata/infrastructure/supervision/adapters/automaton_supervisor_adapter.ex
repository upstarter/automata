defmodule Automata.Infrastructure.Supervision.Adapters.AutomatonSupervisorAdapter do
  @moduledoc """
  Adapter for Automata.AutomatonSupervisor that bridges the original automaton supervisor
  with the new distributed infrastructure.
  
  This adapter maintains the same interface as the original AutomatonSupervisor but delegates
  the actual supervision to the distributed components.
  """
  use Supervisor

  alias Automata.Infrastructure.Supervision.DistributedSupervisor

  def start_link([automaton_config]) do
    Supervisor.start_link(__MODULE__, [automaton_config], name: via_tuple(automaton_config.name))
  end

  @impl true
  def init([automaton_config]) do
    children = [
      {Automata.AgentServer, [automaton_config]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Create a via tuple for registration in the distributed registry
  defp via_tuple(name) do
    {:via, Horde.Registry, {Automata.HordeRegistry, {__MODULE__, name}}}
  end

  # Provide compatibility with the original child_spec
  def child_spec([automaton_config]) do
    %{
      id: {__MODULE__, automaton_config.name},
      start: {__MODULE__, :start_link, [[automaton_config]]},
      restart: :temporary,
      shutdown: 10_000,
      type: :supervisor
    }
  end
end