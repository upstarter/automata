defmodule Automata.Infrastructure.Adapters.SupervisorAdapter do
  @moduledoc """
  Adapter for the legacy Automata.Supervisor that bridges to the distributed supervision tree.
  
  This adapter maintains the same interface as the original supervisor but uses
  the distributed infrastructure components under the hood.
  """
  
  use Supervisor
  
  alias Automata.Infrastructure.Adapters.AutomataSupervisorAdapter
  alias Automata.Infrastructure.Adapters.ServerAdapter
  alias Automata.Infrastructure.Adapters.RegistryAdapter
  alias Automata.Infrastructure.Supervision.DistributedSupervisor
  
  @doc """
  Starts the supervisor with the given world configuration.
  """
  def start_link(world_config) do
    Supervisor.start_link(__MODULE__, world_config, name: __MODULE__)
  end
  
  @doc """
  Initializes the supervisor with the children needed for the distributed system.
  """
  def init(world_config) do
    # Ensure the registry is started
    RegistryAdapter.ensure_started()
    
    children = [
      # The distributed registry for processes
      {RegistryAdapter, []},
      
      # The server manages automata lifecycle
      {ServerAdapter, [world_config]},
      
      # The automata supervisor manages individual automata
      {AutomataSupervisorAdapter, []}
    ]
    
    # Stratey is one_for_one to allow partial restarts
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Retrieves the server process.
  """
  def server do
    ServerAdapter
  end
  
  @doc """
  Retrieves the automata supervisor process.
  """
  def automata_supervisor do
    AutomataSupervisorAdapter
  end
end