defmodule Automata.Service.EventManager do
  @moduledoc """
  Manages events in the system with improved reliability.
  """
  use GenServer
  
  require Logger

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def world_started(world_id) do
    GenServer.cast(__MODULE__, {:world_started, world_id, Node.self()})
  end

  def world_finished(world_id, reason) do
    GenServer.cast(__MODULE__, {:world_finished, world_id, reason, Node.self()})
  end

  def world_error(world_id, error) do
    GenServer.cast(__MODULE__, {:world_error, world_id, error, Node.self()})
  end

  def agent_started(agent_id, world_id) do
    GenServer.cast(__MODULE__, {:agent_started, agent_id, world_id, Node.self()})
  end

  def agent_finished(agent_id, reason) do
    GenServer.cast(__MODULE__, {:agent_finished, agent_id, reason, Node.self()})
  end

  def agent_error(agent_id, error) do
    GenServer.cast(__MODULE__, {:agent_error, agent_id, error, Node.self()})
  end

  # Server callbacks

  @impl true
  def init(_) do
    # Initialize Phoenix PubSub or another pubsub mechanism
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:world_started, world_id, node}, state) do
    event = %{
      type: :world_started,
      world_id: world_id,
      node: node,
      timestamp: System.system_time(:millisecond)
    }
    
    # Log the event
    Logger.info("World started: #{world_id} on node #{node}")
    
    # Publish the event to metrics and any subscribers
    Automata.Service.Metrics.record_event(event)
    
    # Broadcast to all nodes
    :rpc.multicall(Node.list(), __MODULE__, :handle_remote_event, [event])
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({:world_finished, world_id, reason, node}, state) do
    event = %{
      type: :world_finished,
      world_id: world_id,
      reason: reason,
      node: node,
      timestamp: System.system_time(:millisecond)
    }
    
    # Log the event
    Logger.info("World finished: #{world_id} on node #{node} with reason: #{inspect(reason)}")
    
    # Publish the event to metrics and any subscribers
    Automata.Service.Metrics.record_event(event)
    
    # Broadcast to all nodes
    :rpc.multicall(Node.list(), __MODULE__, :handle_remote_event, [event])
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({:world_error, world_id, error, node}, state) do
    event = %{
      type: :world_error,
      world_id: world_id,
      error: error,
      node: node,
      timestamp: System.system_time(:millisecond)
    }
    
    # Log the event
    Logger.error("World error: #{world_id} on node #{node} with error: #{inspect(error)}")
    
    # Publish the event to metrics and any subscribers
    Automata.Service.Metrics.record_event(event)
    
    # Broadcast to all nodes
    :rpc.multicall(Node.list(), __MODULE__, :handle_remote_event, [event])
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({:agent_started, agent_id, world_id, node}, state) do
    event = %{
      type: :agent_started,
      agent_id: agent_id,
      world_id: world_id,
      node: node,
      timestamp: System.system_time(:millisecond)
    }
    
    # Log the event
    Logger.info("Agent started: #{agent_id} in world #{world_id} on node #{node}")
    
    # Publish the event to metrics and any subscribers
    Automata.Service.Metrics.record_event(event)
    
    # Broadcast to all nodes
    :rpc.multicall(Node.list(), __MODULE__, :handle_remote_event, [event])
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({tag, entity_id, reason_or_error, node}, state) 
      when tag in [:agent_finished, :agent_error] do
    
    type = if tag == :agent_finished, do: :agent_finished, else: :agent_error
    field = if tag == :agent_finished, do: :reason, else: :error
    
    event = %{
      type: type,
      agent_id: entity_id,
      node: node,
      timestamp: System.system_time(:millisecond)
    } |> Map.put(field, reason_or_error)
    
    # Log the event
    level = if tag == :agent_finished, do: :info, else: :error
    message = if tag == :agent_finished, 
      do: "Agent finished: #{entity_id} on node #{node} with reason: #{inspect(reason_or_error)}",
      else: "Agent error: #{entity_id} on node #{node} with error: #{inspect(reason_or_error)}"
    
    Logger.log(level, message)
    
    # Publish the event to metrics and any subscribers
    Automata.Service.Metrics.record_event(event)
    
    # Broadcast to all nodes
    :rpc.multicall(Node.list(), __MODULE__, :handle_remote_event, [event])
    
    {:noreply, state}
  end

  @doc """
  Handles an event from a remote node.
  """
  def handle_remote_event(event) do
    # Process the remote event locally
    # This could involve updating local state, triggering local handlers, etc.
    Automata.Service.Metrics.record_event(event)
    :ok
  end
end