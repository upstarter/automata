defmodule Automata.Infrastructure.Adapters.ServerAdapter do
  @moduledoc """
  Adapter for the legacy Automata.Server that bridges to the distributed system.
  
  This adapter maintains the same interface as the original server but uses
  the distributed infrastructure components behind the scenes.
  """
  
  use GenServer
  
  alias Automata.Infrastructure.Adapters.AutomataSupervisorAdapter
  alias Automata.Infrastructure.Adapters.RegistryAdapter
  alias Automata.Infrastructure.Event.EventBus
  
  @doc """
  Starts the server with the given world configuration.
  """
  def start_link(world_config) do
    GenServer.start_link(__MODULE__, world_config, name: __MODULE__)
  end
  
  @doc """
  Initializes the server with the world configuration.
  """
  def init(world_config) do
    # Store the world configuration in the server state
    {:ok, %{world_config: world_config, automata: %{}}}
  end
  
  @doc """
  Starts an automaton with the given configuration.
  """
  def start_automaton(automaton_config) do
    GenServer.call(__MODULE__, {:start_automaton, automaton_config})
  end
  
  @doc """
  Stops an automaton with the given name.
  """
  def stop_automaton(name) do
    GenServer.call(__MODULE__, {:stop_automaton, name})
  end
  
  @doc """
  Gets information about an automaton.
  """
  def automaton_info(name) do
    GenServer.call(__MODULE__, {:automaton_info, name})
  end
  
  @doc """
  Lists all automata.
  """
  def list_automata do
    GenServer.call(__MODULE__, :list_automata)
  end
  
  # GenServer callbacks
  
  def handle_call({:start_automaton, automaton_config}, _from, state) do
    name = automaton_config[:name]
    
    # Check if the automaton already exists
    case Map.has_key?(state.automata, name) do
      true ->
        {:reply, {:error, :already_exists}, state}
      
      false ->
        # Start the automaton supervisor
        case AutomataSupervisorAdapter.start_automaton(automaton_config) do
          {:ok, pid} ->
            # Publish event for automaton started
            EventBus.publish({:automaton_started, name, pid})
            
            # Update the automata map
            new_automata = Map.put(state.automata, name, %{
              pid: pid,
              config: automaton_config,
              started_at: System.system_time(:second)
            })
            
            {:reply, {:ok, pid}, %{state | automata: new_automata}}
          
          error ->
            {:reply, error, state}
        end
    end
  end
  
  def handle_call({:stop_automaton, name}, _from, state) do
    # Check if the automaton exists
    case Map.has_key?(state.automata, name) do
      false ->
        {:reply, {:error, :not_found}, state}
      
      true ->
        # Stop the automaton supervisor
        case AutomataSupervisorAdapter.stop_automaton(name) do
          :ok ->
            # Publish event for automaton stopped
            EventBus.publish({:automaton_stopped, name})
            
            # Update the automata map
            new_automata = Map.delete(state.automata, name)
            
            {:reply, :ok, %{state | automata: new_automata}}
          
          error ->
            {:reply, error, state}
        end
    end
  end
  
  def handle_call({:automaton_info, name}, _from, state) do
    # Check if the automaton exists
    case Map.get(state.automata, name) do
      nil ->
        {:reply, {:error, :not_found}, state}
      
      info ->
        {:reply, {:ok, info}, state}
    end
  end
  
  def handle_call(:list_automata, _from, state) do
    # Return the list of automata
    {:reply, {:ok, state.automata}, state}
  end
end