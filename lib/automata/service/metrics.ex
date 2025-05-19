defmodule Automata.Service.Metrics do
  @moduledoc """
  Service for tracking metrics and system health.
  """
  use GenServer
  
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Set up telemetry
    :telemetry.attach(
      "automata-metrics-handler",
      [:automata, :event],
      &handle_event/4,
      nil
    )
    
    {:ok, %{
      worlds: %{},
      agents: %{},
      events: [],
      started_at: System.system_time(:millisecond)
    }}
  end

  def record_event(event) do
    :telemetry.execute([:automata, :event], %{count: 1}, event)
    GenServer.cast(__MODULE__, {:record_event, event})
  end

  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  def get_system_health do
    GenServer.call(__MODULE__, :get_system_health)
  end

  @impl true
  def handle_cast({:record_event, event}, state) do
    # Update state based on event type
    new_state = case event.type do
      :world_started ->
        worlds = Map.put(state.worlds, event.world_id, %{
          started_at: event.timestamp,
          status: :running,
          node: event.node
        })
        %{state | worlds: worlds}
        
      :world_finished ->
        worlds = case Map.fetch(state.worlds, event.world_id) do
          {:ok, world} ->
            Map.put(state.worlds, event.world_id, Map.merge(world, %{
              finished_at: event.timestamp,
              status: :finished,
              reason: event.reason
            }))
          :error ->
            state.worlds
        end
        %{state | worlds: worlds}
        
      :world_error ->
        worlds = case Map.fetch(state.worlds, event.world_id) do
          {:ok, world} ->
            error_count = Map.get(world, :error_count, 0) + 1
            Map.put(state.worlds, event.world_id, Map.merge(world, %{
              last_error_at: event.timestamp,
              status: :error,
              error: event.error,
              error_count: error_count
            }))
          :error ->
            state.worlds
        end
        %{state | worlds: worlds}
        
      :agent_started ->
        agents = Map.put(state.agents, event.agent_id, %{
          world_id: event.world_id,
          started_at: event.timestamp,
          status: :running,
          node: event.node
        })
        %{state | agents: agents}
        
      :agent_finished ->
        agents = case Map.fetch(state.agents, event.agent_id) do
          {:ok, agent} ->
            Map.put(state.agents, event.agent_id, Map.merge(agent, %{
              finished_at: event.timestamp,
              status: :finished,
              reason: event.reason
            }))
          :error ->
            state.agents
        end
        %{state | agents: agents}
        
      :agent_error ->
        agents = case Map.fetch(state.agents, event.agent_id) do
          {:ok, agent} ->
            error_count = Map.get(agent, :error_count, 0) + 1
            Map.put(state.agents, event.agent_id, Map.merge(agent, %{
              last_error_at: event.timestamp,
              status: :error,
              error: event.error,
              error_count: error_count
            }))
          :error ->
            state.agents
        end
        %{state | agents: agents}
        
      _ ->
        state
    end
    
    # Keep the last 1000 events
    events = [event | state.events] |> Enum.take(1000)
    
    {:noreply, %{new_state | events: events}}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      worlds: %{
        total: map_size(state.worlds),
        running: count_by_status(state.worlds, :running),
        finished: count_by_status(state.worlds, :finished),
        error: count_by_status(state.worlds, :error)
      },
      agents: %{
        total: map_size(state.agents),
        running: count_by_status(state.agents, :running),
        finished: count_by_status(state.agents, :finished),
        error: count_by_status(state.agents, :error)
      },
      events: %{
        total: length(state.events),
        by_type: count_events_by_type(state.events)
      },
      uptime_ms: System.system_time(:millisecond) - state.started_at,
      node: Node.self(),
      cluster: %{
        nodes: [Node.self() | Node.list()],
        count: length(Node.list()) + 1
      }
    }
    
    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:get_system_health, _from, state) do
    # Calculate system health metrics
    error_rate = calculate_error_rate(state.events)
    
    health = %{
      status: determine_system_status(error_rate),
      error_rate: error_rate,
      agent_error_count: count_by_status(state.agents, :error),
      world_error_count: count_by_status(state.worlds, :error),
      last_errors: get_last_errors(state.events, 5)
    }
    
    {:reply, health, state}
  end

  # Event handler for telemetry
  defp handle_event([:automata, :event], %{count: _count}, metadata, _config) do
    # Process telemetry event - could send to external monitoring
    event_type = Map.get(metadata, :type, :unknown)
    Logger.debug("Telemetry event: #{event_type}")
  end

  # Helper functions
  
  defp count_by_status(map, status) do
    Enum.count(map, fn {_id, entity} -> entity.status == status end)
  end
  
  defp count_events_by_type(events) do
    Enum.reduce(events, %{}, fn event, acc ->
      Map.update(acc, event.type, 1, &(&1 + 1))
    end)
  end
  
  defp calculate_error_rate(events) do
    recent_events = Enum.take(events, 100)
    
    if length(recent_events) == 0 do
      0.0
    else
      error_count = Enum.count(recent_events, fn event -> 
        event.type == :world_error || event.type == :agent_error
      end)
      
      error_count / length(recent_events)
    end
  end
  
  defp determine_system_status(error_rate) do
    cond do
      error_rate > 0.25 -> :critical
      error_rate > 0.10 -> :warning
      true -> :healthy
    end
  end
  
  defp get_last_errors(events, count) do
    events
    |> Enum.filter(fn event -> event.type == :world_error || event.type == :agent_error end)
    |> Enum.take(count)
  end
end