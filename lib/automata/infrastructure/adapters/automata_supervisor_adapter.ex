defmodule Automata.Infrastructure.Adapters.AutomataSupervisorAdapter do
  @moduledoc """
  Adapter for the legacy Automata.AutomataSupervisor that bridges to the
  distributed supervision system.
  
  This adapter maintains compatibility with existing code while using
  distributed supervisor functionality behind the scenes.
  """
  
  use DynamicSupervisor
  
  alias Automata.Infrastructure.Adapters.AutomatonSupervisorAdapter
  alias Automata.Infrastructure.Adapters.RegistryAdapter
  alias Automata.Infrastructure.Supervision.DistributedSupervisor
  
  @doc """
  Starts the automata supervisor.
  """
  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @doc """
  Initializes the dynamic supervisor.
  """
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
  
  @doc """
  Starts a child automaton supervisor with the given configuration.
  """
  def start_automaton(automaton_config) do
    name = :"#{automaton_config[:name]}Supervisor"
    
    # Create a child spec for the automaton supervisor
    child_spec = %{
      id: name,
      start: {AutomatonSupervisorAdapter, :start_link, [automaton_config]},
      restart: :permanent,
      shutdown: 5000,
      type: :supervisor
    }
    
    # Start the child with distributed supervision
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        # Register the automaton supervisor in the distributed registry
        RegistryAdapter.register(name, pid)
        {:ok, pid}
      
      other ->
        other
    end
  end
  
  @doc """
  Stops an automaton supervisor with the given name.
  """
  def stop_automaton(name) do
    name_supervisor = :"#{name}Supervisor"
    
    # Look up the pid in the distributed registry
    case RegistryAdapter.lookup(name_supervisor) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        RegistryAdapter.unregister(name_supervisor)
        :ok
      
      _ ->
        {:error, :not_found}
    end
  end
  
  @doc """
  Lists all automata that are currently running.
  """
  def list_automata do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, type, modules} ->
      # Extract the automaton name from the supervisor name
      name = RegistryAdapter.reverse_lookup(pid)
      |> case do
        {:ok, name_supervisor} ->
          name_str = Atom.to_string(name_supervisor)
          String.replace_suffix(name_str, "Supervisor", "")
          |> String.to_atom()
        
        _ ->
          :unknown
      end
      
      {name, pid, type, modules}
    end)
  end
end