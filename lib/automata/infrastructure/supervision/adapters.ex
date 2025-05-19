defmodule Automata.Infrastructure.Supervision.Adapters do
  @moduledoc """
  Entry point module for supervision adapters that bridge between the original
  supervision tree and the new distributed supervision infrastructure.
  
  This module provides convenience functions for working with the adapter system.
  """
  
  alias Automata.Infrastructure.Supervision.Adapters.SupervisorAdapter
  alias Automata.Infrastructure.Supervision.Adapters.AutomataSupervisorAdapter
  alias Automata.Infrastructure.Supervision.Adapters.AutomatonSupervisorAdapter
  alias Automata.Infrastructure.Supervision.Adapters.ServerAdapter
  alias Automata.Infrastructure.Supervision.Adapters.RegistryAdapter
  
  @doc """
  Starts the entire supervision adapter system with the given world configuration.
  """
  def start_supervision_system(world_config) do
    # Start the registry adapter first
    {:ok, _registry_pid} = RegistryAdapter.start_link([])
    
    # Then start the main supervisor adapter
    SupervisorAdapter.start_link(world_config)
  end
  
  @doc """
  Stops an automaton in the distributed system.
  """
  def stop_automaton(automaton_name) do
    # Find the process in the distributed registry
    case RegistryAdapter.lookup({AutomatonSupervisorAdapter, automaton_name}) do
      [{pid, _}] ->
        # Use the distributed supervisor to terminate the process
        Automata.Infrastructure.Supervision.DistributedSupervisor.terminate_child(pid)
      
      _ ->
        {:error, :not_found}
    end
  end
  
  @doc """
  Lists all running automata in the distributed system.
  """
  def list_running_automata do
    Automata.Infrastructure.Supervision.DistributedSupervisor.which_children()
    |> Enum.filter(fn {id, _pid, _type, _modules} -> 
      case id do
        {AutomatonSupervisorAdapter, _name} -> true
        _ -> false
      end
    end)
    |> Enum.map(fn {{_module, name}, _pid, _type, _modules} -> name end)
  end
end