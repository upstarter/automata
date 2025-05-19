defmodule Automata.Infrastructure.AgentSystem.AgentServer do
  @moduledoc """
  Server process for agent instances.
  
  This module implements a GenServer that manages an agent instance,
  handling initialization, ticks, and termination of the agent.
  """
  
  use GenServer, restart: :transient
  require Logger
  alias Automata.Infrastructure.Resilience.Logger, as: EnhancedLogger
  alias Automata.Infrastructure.AgentSystem.AgentFactory
  alias Automata.Infrastructure.Registry.DistributedRegistry
  alias Automata.Infrastructure.State.DistributedBlackboard
  alias Automata.Infrastructure.Event.EventBus
  alias Automata.Infrastructure.Resilience.CircuitBreaker
  
  defmodule State do
    @moduledoc false
    defstruct [
      :id,
      :world_id,
      :config,
      :agent,
      :status,
      :started_at,
      :last_error,
      :circuit_breaker,
      error_count: 0
    ]
  end
  
  # Client API
  
  @doc """
  Starts an agent server.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(args.id))
  end
  
  @doc """
  Starts a new agent from configuration.
  """
  def start_agent(agent_id, world_id, config) do
    DynamicSupervisor.start_child(
      Automata.Infrastructure.AgentSystem.AgentSupervisor,
      {__MODULE__, %{id: agent_id, world_id: world_id, config: config}}
    )
  end
  
  @doc """
  Gets the current status of an agent.
  """
  def status(agent_id) do
    GenServer.call(via_tuple(agent_id), :status)
  end
  
  @doc """
  Sends a tick signal to an agent.
  """
  def tick(agent_id) do
    GenServer.cast(via_tuple(agent_id), :tick)
  end
  
  @doc """
  Stops an agent.
  """
  def stop(agent_id, reason \\ :normal) do
    GenServer.cast(via_tuple(agent_id), {:stop, reason})
  end
  
  @doc """
  Gets information about an agent.
  """
  def info(agent_id) do
    GenServer.call(via_tuple(agent_id), :info)
  end
  
  # Server Callbacks
  
  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)
    
    EnhancedLogger.info("Initializing agent", %{
      agent_id: args.id,
      world_id: args.world_id,
      type: args.config[:type]
    })
    
    # Register with distributed registry
    DistributedRegistry.register({:agent, args.id})
    
    # Create a circuit breaker for the agent
    {:ok, _pid} = CircuitBreaker.CircuitBreakerSupervisor.create(
      name: "agent-#{args.id}",
      failure_threshold: 5,
      retry_timeout: 10_000
    )
    
    {:ok, 
      %State{
        id: args.id,
        world_id: args.world_id,
        config: args.config,
        status: :initializing,
        started_at: System.system_time(:millisecond),
        circuit_breaker: "agent-#{args.id}"
      }, 
      {:continue, :initialize_agent}
    }
  end
  
  @impl true
  def handle_continue(:initialize_agent, state) do
    # Initialize agent through factory
    case CircuitBreaker.execute(state.circuit_breaker, fn ->
      AgentFactory.create_agent(state.id, state.world_id, state.config)
    end) do
      {:ok, agent} ->
        # Agent initialized successfully
        EnhancedLogger.info("Agent initialized", %{
          agent_id: state.id,
          type: state.config[:type]
        })
        
        # Update state
        new_state = %{state | agent: agent, status: :ready}
        
        # Update blackboard
        update_agent_in_blackboard(new_state)
        
        # Start tick timer if auto_tick is enabled
        new_state = if state.config[:auto_tick] do
          schedule_tick(state.config[:tick_freq] || 100)
          %{new_state | status: :running}
        else
          new_state
        end
        
        {:noreply, new_state}
        
      {:error, reason} ->
        # Agent initialization failed
        EnhancedLogger.error("Agent initialization failed", %{
          agent_id: state.id,
          error: reason
        })
        
        new_state = %{state | 
          status: :error, 
          last_error: reason,
          error_count: state.error_count + 1
        }
        
        update_agent_in_blackboard(new_state)
        
        # Determine if we should retry or fail
        if state.error_count >= 3 do
          # Too many initialization attempts, fail
          {:stop, {:shutdown, :initialization_failed}, new_state}
        else
          # Retry after delay
          Process.send_after(self(), :retry_initialization, 5000)
          {:noreply, new_state}
        end
    end
  end
  
  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end
  
  @impl true
  def handle_call(:info, _from, state) do
    info = %{
      id: state.id,
      world_id: state.world_id,
      type: state.config[:type],
      status: state.status,
      started_at: state.started_at,
      uptime_ms: System.system_time(:millisecond) - state.started_at,
      error_count: state.error_count,
      tick_count: state.agent && state.agent.tick_count || 0,
      last_tick: state.agent && state.agent.last_tick,
      last_error: state.last_error
    }
    
    {:reply, info, state}
  end
  
  @impl true
  def handle_cast(:tick, %{status: :ready, agent: agent} = state) do
    # Process tick with circuit breaker protection
    case CircuitBreaker.execute(state.circuit_breaker, fn ->
      AgentFactory.tick_agent(agent)
    end) do
      {:ok, updated_agent} ->
        # Tick processed successfully
        new_state = %{state | agent: updated_agent}
        update_agent_in_blackboard(new_state)
        {:noreply, new_state}
        
      {:error, {reason, updated_agent}} ->
        # Tick processing failed
        EnhancedLogger.warning("Agent tick failed", %{
          agent_id: state.id,
          error: reason
        })
        
        new_state = %{state | 
          agent: updated_agent,
          status: :error,
          last_error: reason,
          error_count: state.error_count + 1
        }
        
        update_agent_in_blackboard(new_state)
        
        # Determine if we should reset or fail
        if state.error_count >= 10 do
          # Too many errors, terminate
          {:stop, {:shutdown, :too_many_errors}, new_state}
        else
          # Continue but in error state
          {:noreply, new_state}
        end
    end
  end
  
  @impl true
  def handle_cast(:tick, %{status: :running, agent: agent} = state) do
    # Process tick with circuit breaker protection
    case CircuitBreaker.execute(state.circuit_breaker, fn ->
      AgentFactory.tick_agent(agent)
    end) do
      {:ok, updated_agent} ->
        # Tick processed successfully
        new_state = %{state | agent: updated_agent}
        update_agent_in_blackboard(new_state)
        
        # Schedule next tick
        schedule_tick(state.config[:tick_freq] || 100)
        
        {:noreply, new_state}
        
      {:error, {reason, updated_agent}} ->
        # Tick processing failed
        EnhancedLogger.warning("Agent tick failed", %{
          agent_id: state.id,
          error: reason
        })
        
        new_state = %{state | 
          agent: updated_agent,
          status: :error,
          last_error: reason,
          error_count: state.error_count + 1
        }
        
        update_agent_in_blackboard(new_state)
        
        # Determine if we should retry or fail
        if state.error_count >= 10 do
          # Too many errors, terminate
          {:stop, {:shutdown, :too_many_errors}, new_state}
        else
          # Schedule next tick anyway to attempt recovery
          schedule_tick(state.config[:tick_freq] || 100)
          {:noreply, new_state}
        end
    end
  end
  
  @impl true
  def handle_cast(:tick, state) do
    # Ignore tick if not ready or running
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:stop, reason}, state) do
    # Stop the agent
    EnhancedLogger.info("Stopping agent", %{
      agent_id: state.id,
      reason: reason
    })
    
    {:stop, {:shutdown, reason}, state}
  end
  
  @impl true
  def handle_info(:tick, state) do
    # Forward to tick handler
    handle_cast(:tick, state)
  end
  
  @impl true
  def handle_info(:retry_initialization, state) do
    # Retry agent initialization
    EnhancedLogger.info("Retrying agent initialization", %{
      agent_id: state.id,
      attempt: state.error_count + 1
    })
    
    {:noreply, state, {:continue, :initialize_agent}}
  end
  
  @impl true
  def terminate(reason, state) do
    EnhancedLogger.info("Terminating agent", %{
      agent_id: state.id,
      reason: reason
    })
    
    # Terminate agent implementation
    if state.agent do
      AgentFactory.terminate_agent(state.agent, reason)
    end
    
    # Update blackboard
    DistributedBlackboard.put({:agent, state.id}, %{
      id: state.id,
      world_id: state.world_id,
      status: :terminated,
      terminated_at: System.system_time(:millisecond),
      reason: inspect(reason)
    })
    
    # Clean up circuit breaker
    CircuitBreaker.CircuitBreakerSupervisor.stop(state.circuit_breaker)
    
    :ok
  end
  
  # Private helpers
  
  defp update_agent_in_blackboard(state) do
    DistributedBlackboard.put({:agent, state.id}, %{
      id: state.id,
      world_id: state.world_id,
      type: state.config[:type],
      status: state.status,
      error_count: state.error_count,
      last_error: state.last_error,
      tick_count: state.agent && state.agent.tick_count || 0,
      updated_at: System.system_time(:millisecond)
    })
  end
  
  defp schedule_tick(delay) do
    Process.send_after(self(), :tick, delay)
  end
  
  defp via_tuple(id) do
    {:via, Registry, {Automata.Infrastructure.AgentSystem.AgentRegistry, id}}
  end
end