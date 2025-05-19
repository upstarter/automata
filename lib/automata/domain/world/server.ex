defmodule Automata.Domain.World.Server do
  @moduledoc """
  Server process for a world instance with improved fault tolerance.
  """
  use GenServer, restart: :transient
  
  require Logger
  
  alias Automata.Infrastructure.Registry.DistributedRegistry
  alias Automata.Infrastructure.State.DistributedBlackboard
  alias Automata.Infrastructure.Supervision.DistributedSupervisor

  defmodule State do
    defstruct [
      :world_id,
      :name,
      :config,
      :automata,
      :status,
      :started_at
    ]
  end

  def start_link(config) do
    world_id = config.id || generate_id()
    GenServer.start_link(__MODULE__, %{world_id: world_id, config: config}, name: via_tuple(world_id))
  end

  @impl true
  def init(%{world_id: world_id, config: config}) do
    Process.flag(:trap_exit, true)
    
    DistributedRegistry.register({:world, world_id})
    
    {:ok, 
      %State{
        world_id: world_id,
        name: config.name || "world-#{world_id}",
        config: config,
        automata: [],
        status: :initializing,
        started_at: System.system_time(:millisecond)
      }, 
      {:continue, :initialize_world}
    }
  end

  @impl true
  def handle_continue(:initialize_world, state) do
    # Log world initialization
    Automata.Service.EventManager.world_started(state.world_id)
    
    # Store world state in blackboard
    DistributedBlackboard.put({:world, state.world_id}, %{
      id: state.world_id,
      name: state.name,
      status: :ready,
      automata_count: 0
    })
    
    # Spawn initial automata if defined in config
    automata = 
      Enum.map(state.config.automata || [], fn automaton_config ->
        case spawn_automaton(state.world_id, automaton_config) do
          {:ok, automaton_id} -> automaton_id
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
    
    {:noreply, %{state | status: :ready, automata: automata}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call({:spawn_automaton, automaton_config}, _from, state) do
    case spawn_automaton(state.world_id, automaton_config) do
      {:ok, automaton_id} = result ->
        {:reply, result, %{state | 
          automata: [automaton_id | state.automata]
        }}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, state) do
    # Handle linked process termination
    Automata.Service.EventManager.world_error(state.world_id, reason)
    
    if reason == :normal do
      {:noreply, state}
    else
      # Update blackboard with error state
      DistributedBlackboard.put({:world, state.world_id}, %{
        id: state.world_id,
        name: state.name,
        status: :error,
        error: inspect(reason),
        automata_count: length(state.automata)
      })
      
      {:noreply, %{state | status: :error}}
    end
  end

  @impl true
  def terminate(reason, state) do
    # Log world termination
    Automata.Service.EventManager.world_finished(state.world_id, reason)
    
    # Clean up world state from blackboard if not normal termination
    if reason != :normal do
      DistributedBlackboard.put({:world, state.world_id}, %{
        id: state.world_id,
        name: state.name,
        status: :terminated,
        terminated_at: System.system_time(:millisecond),
        reason: inspect(reason)
      })
    end
    
    :ok
  end

  # Public API

  @doc """
  Gets the current status of the world.
  """
  def status(world_id) do
    GenServer.call(via_tuple(world_id), :status)
  end

  @doc """
  Spawns a new automaton in the world.
  """
  def spawn_automaton(world_id, automaton_config) when is_pid(world_id) do
    GenServer.call(world_id, {:spawn_automaton, automaton_config})
  end

  def spawn_automaton(world_id, automaton_config) do
    case DistributedRegistry.lookup({:world, world_id}) do
      [{pid, _}] ->
        GenServer.call(pid, {:spawn_automaton, automaton_config})

      [] ->
        {:error, :world_not_found}
    end
  end

  # Private helpers

  defp update_automaton_in_blackboard(world_id, automaton_id, status) do
    world_data = DistributedBlackboard.get({:world, world_id}) || %{}
    automata = Map.get(world_data, :automata, %{})
    
    updated_automata = Map.put(automata, automaton_id, %{
      id: automaton_id,
      status: status,
      updated_at: System.system_time(:millisecond)
    })
    
    updated_world = Map.put(world_data, :automata, updated_automata)
    DistributedBlackboard.put({:world, world_id}, updated_world)
  end

  defp via_tuple(id) do
    {:via, Horde.Registry, {Automata.HordeRegistry, {:world, id}}}
  end

  defp generate_id, do: System.unique_integer([:positive, :monotonic]) |> to_string()
end