defmodule Automata.Domain.Agent.Server do
  @moduledoc """
  Server process for an agent instance with improved fault tolerance.
  """
  use GenServer, restart: :transient
  
  require Logger
  
  alias Automata.Infrastructure.Registry.DistributedRegistry
  alias Automata.Infrastructure.State.DistributedBlackboard

  defmodule State do
    defstruct [
      :id,
      :world_id,
      :config,
      :manager,
      :implementation,
      :status,
      :started_at,
      :last_error,
      error_count: 0
    ]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(args.id))
  end

  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)
    
    DistributedRegistry.register({:agent, args.id})
    
    {:ok, 
      %State{
        id: args.id,
        world_id: args.world_id,
        config: args.config,
        manager: args.manager,
        status: :initializing,
        started_at: System.system_time(:millisecond),
      }, 
      {:continue, :initialize_agent}
    }
  end

  @impl true
  def handle_continue(:initialize_agent, state) do
    # Log agent initialization
    Automata.Service.EventManager.agent_started(state.id, state.world_id)
    
    # Store agent state in blackboard
    update_agent_in_blackboard(state)
    
    # In a real implementation, we would initialize the actual agent implementation
    # For now, we'll just set a dummy implementation
    implementation = %{
      status: :ready,
      handle_tick: fn -> {:ok, %{status: :ready}} end,
      terminate: fn _reason -> :ok end
    }
    
    {:noreply, %{state | implementation: implementation, status: :ready}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_cast(:tick, %{status: :ready, implementation: impl} = state) do
    # Have the agent implementation process a tick
    result = impl.handle_tick.()
    
    case result do
      {:ok, updated_impl} ->
        {:noreply, %{state | implementation: updated_impl}}
        
      {:error, reason} ->
        # Log error and update state
        Automata.Service.EventManager.agent_error(state.id, reason)
        new_state = %{state | 
          status: :error, 
          last_error: reason,
          error_count: state.error_count + 1
        }
        update_agent_in_blackboard(new_state)
        
        # Return error, but don't crash - let supervision policy handle restart
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast(:tick, state) do
    # Ignore tick if not ready
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, state) do
    # Handle linked process termination
    Automata.Service.EventManager.agent_error(state.id, reason)
    
    new_state = %{state | 
      status: :error, 
      last_error: reason,
      error_count: state.error_count + 1
    }
    update_agent_in_blackboard(new_state)
    
    if state.error_count >= 5 do
      # Too many errors, terminate
      {:stop, {:shutdown, :too_many_errors}, new_state}
    else
      # Try to recover
      {:noreply, new_state, {:continue, :initialize_agent}}
    end
  end

  @impl true
  def terminate(reason, state) do
    # Log agent termination
    Automata.Service.EventManager.agent_finished(state.id, reason)
    
    # Update blackboard
    DistributedBlackboard.put({:agent, state.id}, %{
      id: state.id,
      world_id: state.world_id,
      status: :terminated,
      terminated_at: System.system_time(:millisecond),
      reason: inspect(reason)
    })
    
    # Let implementation clean up
    if state.implementation do
      state.implementation.terminate(reason)
    end
    
    :ok
  end

  # Public API

  @doc """
  Gets the current status of the agent.
  """
  def status(agent_id) do
    GenServer.call(via_tuple(agent_id), :status)
  end

  @doc """
  Sends a tick signal to the agent.
  """
  def tick(agent_id) do
    GenServer.cast(via_tuple(agent_id), :tick)
  end

  # Private helpers

  defp update_agent_in_blackboard(state) do
    DistributedBlackboard.put({:agent, state.id}, %{
      id: state.id,
      world_id: state.world_id,
      type: state.config.type,
      status: state.status,
      error_count: state.error_count,
      last_error: state.last_error,
      updated_at: System.system_time(:millisecond)
    })
  end

  defp via_tuple(id) do
    {:via, Horde.Registry, {Automata.HordeRegistry, {:agent, id}}}
  end
end