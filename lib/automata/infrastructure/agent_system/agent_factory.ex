defmodule Automata.Infrastructure.AgentSystem.AgentFactory do
  @moduledoc """
  Factory for creating agent implementations.
  
  This module provides functions for creating and managing agent instances,
  acting as a factory for agent implementations of different types.
  """
  
  require Logger
  alias Automata.Infrastructure.AgentSystem.Registry
  alias Automata.Infrastructure.Event.EventBus
  alias Automata.Infrastructure.Resilience.Logger
  
  @doc """
  Creates a new agent instance.
  
  Takes an agent ID, world ID, and configuration map. Returns `{:ok, agent}`
  if creation is successful, or `{:error, reason}` if it fails.
  """
  def create_agent(agent_id, world_id, config) do
    Logger.info("Creating agent", %{agent_id: agent_id, world_id: world_id, type: config[:type]})
    
    # Validate config first
    with {:ok, validated_config} <- Registry.validate_config(config),
         {:ok, implementation} <- Registry.create_implementation(agent_id, world_id, validated_config) do
      # Create agent wrapper with additional metadata
      agent = %{
        id: agent_id,
        world_id: world_id,
        config: validated_config,
        implementation: implementation,
        status: :ready,
        created_at: DateTime.utc_now(),
        last_tick: nil,
        tick_count: 0,
        error_count: 0,
        last_error: nil
      }
      
      # Publish agent created event
      publish_agent_event(:agent_created, agent)
      
      {:ok, agent}
    end
  end
  
  @doc """
  Processes a tick for an agent.
  
  Takes an agent map and returns `{:ok, updated_agent}` if the tick is processed
  successfully, or `{:error, reason}` if it fails.
  """
  def tick_agent(agent) do
    # Start tick processing
    start_time = System.monotonic_time(:microsecond)
    
    # Publish tick start event
    publish_agent_event(:agent_tick_started, agent)
    
    # Process tick with the implementation
    type_module = get_type_module(agent.config.type)
    
    result = try do
      type_module.handle_tick(agent.implementation)
    rescue
      e ->
        Logger.error("Agent tick error", %{
          agent_id: agent.id,
          error: Exception.message(e),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        {:error, {:exception, e, __STACKTRACE__}}
    end
    
    # Calculate tick duration
    end_time = System.monotonic_time(:microsecond)
    duration_ms = (end_time - start_time) / 1000
    
    # Process result
    case result do
      {:ok, updated_implementation} ->
        # Update agent with new implementation state
        updated_agent = %{agent |
          implementation: updated_implementation,
          status: type_module.status(updated_implementation),
          last_tick: DateTime.utc_now(),
          tick_count: agent.tick_count + 1
        }
        
        # Publish tick completed event
        publish_agent_event(:agent_tick_completed, Map.put(updated_agent, :tick_duration_ms, duration_ms))
        
        {:ok, updated_agent}
        
      {:error, reason} ->
        # Update agent with error information
        updated_agent = %{agent |
          status: :error,
          last_tick: DateTime.utc_now(),
          tick_count: agent.tick_count + 1,
          error_count: agent.error_count + 1,
          last_error: reason
        }
        
        # Publish tick error event
        publish_agent_event(:agent_tick_error, Map.merge(updated_agent, %{
          tick_duration_ms: duration_ms,
          error: reason
        }))
        
        {:error, {reason, updated_agent}}
    end
  end
  
  @doc """
  Terminates an agent.
  
  Takes an agent map and a reason for termination. Returns `:ok` if termination
  is successful, or `{:error, reason}` if it fails.
  """
  def terminate_agent(agent, reason \\ :normal) do
    Logger.info("Terminating agent", %{agent_id: agent.id, reason: reason})
    
    # Publish termination event
    publish_agent_event(:agent_terminating, Map.put(agent, :reason, reason))
    
    # Terminate the implementation
    type_module = get_type_module(agent.config.type)
    
    result = try do
      type_module.terminate(agent.implementation, reason)
    rescue
      e ->
        Logger.error("Agent termination error", %{
          agent_id: agent.id,
          error: Exception.message(e),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        {:error, {:exception, e, __STACKTRACE__}}
    end
    
    # Publish terminated event
    publish_agent_event(:agent_terminated, Map.put(agent, :reason, reason))
    
    result
  end
  
  # Private helpers
  
  defp get_type_module(type) do
    {:ok, type_info} = Registry.get_type_info(type)
    type_info.module
  end
  
  defp publish_agent_event(event_type, agent) do
    if Process.whereis(EventBus) do
      event = %{
        type: event_type,
        payload: agent,
        metadata: %{
          timestamp: DateTime.utc_now(),
          source: __MODULE__
        }
      }
      
      EventBus.publish(event)
    end
  end
end