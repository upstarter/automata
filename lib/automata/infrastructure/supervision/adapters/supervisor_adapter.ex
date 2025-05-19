defmodule Automata.Infrastructure.Supervision.Adapters.SupervisorAdapter do
  @moduledoc """
  Adapter for Automata.Supervisor that bridges the original supervision tree with
  the new distributed supervisor infrastructure.
  
  This adapter maintains the same interface as the original Automata.Supervisor but
  delegates the actual supervision work to the distributed components.
  """
  use Supervisor

  alias Automata.Infrastructure.Supervision.DistributedSupervisor
  alias Automata.Infrastructure.Supervision.Adapters.AutomataSupervisorAdapter
  alias Automata.Infrastructure.Supervision.Adapters.ServerAdapter

  def start_link(world_config) do
    Supervisor.start_link(__MODULE__, world_config, name: __MODULE__)
  end

  @spec init(any) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}}
  def init(world_config) do
    children = [
      # Start the distributed supervisor infrastructure
      {DistributedSupervisor, []},
      
      # Start the adapter components to maintain compatibility
      {AutomataSupervisorAdapter, []},
      {ServerAdapter, [world_config]}
    ]

    opts = [
      strategy: :one_for_all,
      max_restarts: 1,
      max_time: 3600
    ]

    {:ok, {opts, children}}
  end
end