defmodule Automata.Infrastructure.Resilience.TelemetryReporter do
  @moduledoc """
  Periodically collects and reports telemetry metrics for the Automata system.
  
  This module:
  - Aggregates metrics from various system components
  - Periodically publishes summary metrics
  - Provides a query interface for current metrics
  - Can be configured to export metrics to external systems
  """
  
  use GenServer
  require Logger
  alias Automata.Infrastructure.Resilience.Telemetry
  
  @default_report_interval 60_000 # 1 minute
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Gets current metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end
  
  @doc """
  Gets metrics history.
  """
  def get_metrics_history(opts \\ []) do
    GenServer.call(__MODULE__, {:get_metrics_history, opts})
  end
  
  @doc """
  Gets metrics for a specific event.
  """
  def get_event_metrics(event_name) when is_list(event_name) do
    GenServer.call(__MODULE__, {:get_event_metrics, event_name})
  end
  
  @doc """
  Triggers an immediate metrics report.
  """
  def report_now do
    GenServer.cast(__MODULE__, :report_metrics)
  end
  
  @doc """
  Registers a metrics handler for custom processing of metrics.
  """
  def register_handler(handler_id, handler_fn) when is_atom(handler_id) and is_function(handler_fn, 1) do
    GenServer.call(__MODULE__, {:register_handler, handler_id, handler_fn})
  end
  
  @doc """
  Deregisters a metrics handler.
  """
  def deregister_handler(handler_id) when is_atom(handler_id) do
    GenServer.call(__MODULE__, {:deregister_handler, handler_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    Logger.info("Starting Telemetry Reporter")
    
    # Set up telemetry event handlers
    Telemetry.setup_default_handlers()
    
    # Set up custom handlers for metrics collection
    :ok = setup_metric_handlers()
    
    # Get report interval
    report_interval = Keyword.get(opts, :report_interval, @default_report_interval)
    
    # Initialize state
    state = %{
      metrics: %{},
      history: [],
      handlers: %{},
      event_metrics: %{},
      started_at: DateTime.utc_now(),
      last_report: nil
    }
    
    # Schedule first report
    schedule_report(report_interval)
    
    {:ok, Map.put(state, :report_interval, report_interval)}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end
  
  @impl true
  def handle_call({:get_metrics_history, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 10)
    history = Enum.take(state.history, limit)
    
    {:reply, history, state}
  end
  
  @impl true
  def handle_call({:get_event_metrics, event_name}, _from, state) do
    metrics = Map.get(state.event_metrics, event_name, %{})
    
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call({:register_handler, handler_id, handler_fn}, _from, state) do
    handlers = Map.put(state.handlers, handler_id, handler_fn)
    
    {:reply, :ok, %{state | handlers: handlers}}
  end
  
  @impl true
  def handle_call({:deregister_handler, handler_id}, _from, state) do
    handlers = Map.delete(state.handlers, handler_id)
    
    {:reply, :ok, %{state | handlers: handlers}}
  end
  
  @impl true
  def handle_cast(:report_metrics, state) do
    # Collect system metrics
    system_metrics = collect_system_metrics()
    
    # Collect error metrics
    error_metrics = collect_error_metrics()
    
    # Collect circuit breaker metrics
    circuit_breaker_metrics = collect_circuit_breaker_metrics()
    
    # Collect health metrics
    health_metrics = collect_health_metrics()
    
    # Collect process metrics
    process_metrics = collect_process_metrics()
    
    # Combine all metrics
    metrics = %{
      system: system_metrics,
      errors: error_metrics,
      circuit_breakers: circuit_breaker_metrics,
      health: health_metrics,
      processes: process_metrics,
      timestamp: DateTime.utc_now()
    }
    
    # Add metrics to history
    history = [metrics | state.history] |> Enum.take(100)
    
    # Call registered handlers
    Enum.each(state.handlers, fn {_id, handler_fn} ->
      Task.start(fn -> handler_fn.(metrics) end)
    end)
    
    # Log summary
    log_metrics_summary(metrics)
    
    # Emit telemetry event
    Telemetry.execute([:automata, :metrics, :report], %{count: 1}, metrics)
    
    # Schedule next report
    schedule_report(state.report_interval)
    
    {:noreply, %{state | 
      metrics: metrics, 
      history: history,
      last_report: DateTime.utc_now()
    }}
  end
  
  @impl true
  def handle_info(:report_metrics, state) do
    # Forward to cast handler
    handle_cast(:report_metrics, state)
  end
  
  @impl true
  def handle_info({:telemetry_event, event_name, measurements, metadata, _config}, state) do
    # Update event metrics
    event_metrics = Map.update(
      state.event_metrics, 
      event_name, 
      %{
        count: 1,
        last_event: {measurements, metadata, DateTime.utc_now()},
        events: [{measurements, metadata, DateTime.utc_now()}] |> Enum.take(10)
      },
      fn metrics ->
        events = [{measurements, metadata, DateTime.utc_now()} | metrics.events] |> Enum.take(10)
        %{
          count: metrics.count + 1,
          last_event: {measurements, metadata, DateTime.utc_now()},
          events: events
        }
      end
    )
    
    {:noreply, %{state | event_metrics: event_metrics}}
  end
  
  # Private helpers
  
  defp setup_metric_handlers do
    # Handler for all telemetry events
    :telemetry.attach_many(
      :telemetry_reporter_events,
      [
        [:automata, :operation, :duration],
        [:automata, :log, :debug],
        [:automata, :log, :info],
        [:automata, :log, :warning],
        [:automata, :log, :error],
        [:automata, :log, :critical],
        [:automata, :circuit_breaker, :state_change],
        [:automata, :error, :occurred],
        [:automata, :health, :check, :completed],
        [:automata, :health, :component, :status_change],
        [:automata, :health, :system],
        [:automata, :span, :start],
        [:automata, :span, :stop],
        [:automata, :span, :exception],
        [:automata, :system, :metrics]
      ],
      &handle_telemetry_event/4,
      nil
    )
    
    :ok
  end
  
  defp handle_telemetry_event(event_name, measurements, metadata, config) do
    # Forward event to process
    send(self(), {:telemetry_event, event_name, measurements, metadata, config})
  end
  
  defp collect_system_metrics do
    # Collect memory statistics
    memory = :erlang.memory()
    
    # Collect process statistics
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    
    # Collect scheduler statistics
    scheduler_count = :erlang.system_info(:schedulers)
    scheduler_online = :erlang.system_info(:schedulers_online)
    
    # Collect node statistics
    node_name = Node.self()
    connected_nodes = Node.list()
    
    %{
      memory: %{
        total: memory[:total],
        processes: memory[:processes],
        system: memory[:system],
        atom: memory[:atom],
        binary: memory[:binary],
        ets: memory[:ets],
        code: memory[:code]
      },
      processes: %{
        count: process_count,
        limit: process_limit,
        utilization: process_count / process_limit
      },
      schedulers: %{
        count: scheduler_count,
        online: scheduler_online
      },
      node: %{
        name: node_name,
        connected_count: length(connected_nodes),
        connected: connected_nodes
      }
    }
  end
  
  defp collect_error_metrics do
    # Get error stats if available
    error_stats = if Process.whereis(Automata.Infrastructure.Resilience.ErrorTracker) do
      Automata.Infrastructure.Resilience.ErrorTracker.get_stats()
    else
      %{total: 0, by_type: %{}, by_node: %{}, by_module: %{}}
    end
    
    %{
      total: error_stats.total,
      by_type: error_stats.by_type,
      by_module: error_stats.by_module,
      by_node: error_stats.by_node
    }
  end
  
  defp collect_circuit_breaker_metrics do
    # Get circuit breaker info if available
    if Process.whereis(Automata.Infrastructure.Resilience.CircuitBreakerSupervisor) do
      supervisor = Automata.Infrastructure.Resilience.CircuitBreakerSupervisor
      circuit_breakers = supervisor.list()
      
      # Get stats for each circuit breaker
      stats = Enum.map(circuit_breakers, fn {name, _pid, _} ->
        {name, Automata.Infrastructure.Resilience.CircuitBreaker.get_stats(name)}
      end)
      |> Map.new()
      
      # Aggregate metrics
      open_count = Enum.count(stats, fn {_name, stat} -> stat.state == :open end)
      half_open_count = Enum.count(stats, fn {_name, stat} -> stat.state == :half_open end)
      closed_count = Enum.count(stats, fn {_name, stat} -> stat.state == :closed end)
      
      %{
        count: map_size(stats),
        states: %{
          open: open_count,
          half_open: half_open_count,
          closed: closed_count
        },
        details: stats
      }
    else
      %{
        count: 0,
        states: %{open: 0, half_open: 0, closed: 0},
        details: %{}
      }
    end
  end
  
  defp collect_health_metrics do
    # Get health info if available
    if Process.whereis(Automata.Infrastructure.Resilience.Health) do
      health = Automata.Infrastructure.Resilience.Health.get_system_health()
      components = Automata.Infrastructure.Resilience.Health.get_all_component_health()
      
      # Count component statuses
      healthy_count = Enum.count(components, fn {_name, health} -> health.status == :healthy end)
      degraded_count = Enum.count(components, fn {_name, health} -> health.status == :degraded end)
      unhealthy_count = Enum.count(components, fn {_name, health} -> health.status == :unhealthy end)
      
      %{
        status: health.status,
        components: %{
          total: map_size(components),
          healthy: healthy_count,
          degraded: degraded_count,
          unhealthy: unhealthy_count
        },
        details: components
      }
    else
      %{
        status: :unknown,
        components: %{total: 0, healthy: 0, degraded: 0, unhealthy: 0},
        details: %{}
      }
    end
  end
  
  defp collect_process_metrics do
    # Get process info for applications
    app_processes = for {app, _, _} <- Application.loaded_applications() do
      # Get master supervisors for each app
      masters = Application.get_supervisors(app)
      
      # Count process each master supervises
      process_count = Enum.reduce(masters, 0, fn master, acc ->
        descendant_count = case Process.whereis(master) do
          nil -> 0
          pid -> count_process_descendants(pid)
        end
        
        acc + descendant_count
      end)
      
      {app, process_count}
    end
    |> Enum.filter(fn {_app, count} -> count > 0 end)
    |> Enum.into(%{})
    
    %{
      by_application: app_processes,
      total: Enum.sum(Map.values(app_processes))
    }
  end
  
  defp count_process_descendants(pid) do
    # Get direct children
    case Process.info(pid, :links) do
      {:links, children} ->
        # Filter to only PIDs
        child_pids = Enum.filter(children, &is_pid/1)
        
        # Count direct children plus their descendants
        Enum.reduce(child_pids, length(child_pids), fn child, acc ->
          acc + count_process_descendants(child)
        end)
        
      _ ->
        0
    end
  end
  
  defp log_metrics_summary(metrics) do
    # Log basic system metrics
    memory_mb = div(metrics.system.memory.total, 1024 * 1024)
    process_percent = Float.round(metrics.system.processes.utilization * 100, 1)
    
    Logger.info("System metrics: #{memory_mb}MB memory, #{metrics.system.processes.count}/#{metrics.system.processes.limit} processes (#{process_percent}%)")
    
    # Log circuit breaker status if any are open
    if metrics.circuit_breakers.states.open > 0 do
      Logger.warning("Circuit breakers: #{metrics.circuit_breakers.states.open} open, #{metrics.circuit_breakers.states.half_open} half-open, #{metrics.circuit_breakers.states.closed} closed")
    end
    
    # Log health status if degraded or unhealthy
    if metrics.health.status != :healthy do
      status_str = to_string(metrics.health.status)
      Logger.warning("System health: #{status_str} - #{metrics.health.components.unhealthy} unhealthy, #{metrics.health.components.degraded} degraded components")
    end
    
    # Log error count if there are new errors
    if metrics.errors.total > 0 do
      Logger.info("Total errors: #{metrics.errors.total}")
    end
  end
  
  defp schedule_report(interval) do
    Process.send_after(self(), :report_metrics, interval)
  end
end