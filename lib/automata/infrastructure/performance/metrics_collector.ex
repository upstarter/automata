defmodule Automata.Infrastructure.Performance.MetricsCollector do
  @moduledoc """
  Collects detailed performance metrics for the Automata system.
  
  This module extends the telemetry system with more granular performance metrics,
  including:
  - Operation latencies with histogram distribution
  - Resource utilization tracking
  - Operation throughput measurements
  - Process statistics
  - Message queue monitoring
  
  The metrics are stored with configurable resolution for visualization
  and analysis.
  """
  
  use GenServer
  require Logger
  alias Automata.Infrastructure.Resilience.Telemetry
  
  @collection_interval 5_000 # 5 seconds
  @retention_period :timer.hours(24) # 24 hours
  @resolution_levels [
    # [interval, retention]
    [1, :timer.minutes(10)],     # 1 second intervals for last 10 minutes
    [10, :timer.hours(1)],       # 10 second intervals for last hour
    [60, :timer.hours(6)],       # 1 minute intervals for last 6 hours
    [300, :timer.hours(24)]      # 5 minute intervals for last 24 hours
  ]
  
  # Client API
  
  @doc """
  Starts the metrics collector.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Records an operation latency.
  
  ## Parameters
  
  - `operation` - Name of the operation
  - `duration_us` - Duration in microseconds
  - `metadata` - Additional metadata about the operation
  """
  def record_latency(operation, duration_us, metadata \\ %{}) when is_binary(operation) and is_integer(duration_us) do
    GenServer.cast(__MODULE__, {:record_latency, operation, duration_us, metadata})
    
    # Also emit telemetry event for real-time monitoring
    Telemetry.execute(
      [:automata, :performance, :latency],
      %{duration: duration_us},
      Map.merge(%{operation: operation}, metadata)
    )
  end
  
  @doc """
  Records an operation throughput data point.
  
  ## Parameters
  
  - `operation` - Name of the operation
  - `count` - Number of operations
  - `metadata` - Additional metadata about the operations
  """
  def record_throughput(operation, count, metadata \\ %{}) when is_binary(operation) and is_integer(count) and count > 0 do
    GenServer.cast(__MODULE__, {:record_throughput, operation, count, metadata})
    
    # Also emit telemetry event for real-time monitoring
    Telemetry.execute(
      [:automata, :performance, :throughput],
      %{count: count},
      Map.merge(%{operation: operation}, metadata)
    )
  end
  
  @doc """
  Gets latency statistics for a specific operation.
  
  ## Parameters
  
  - `operation` - Name of the operation
  - `interval` - Time interval in seconds to aggregate data
  - `window` - Time window in seconds to analyze
  """
  def get_latency_stats(operation, interval \\ 60, window \\ 3600) do
    GenServer.call(__MODULE__, {:get_latency_stats, operation, interval, window})
  end
  
  @doc """
  Gets throughput statistics for a specific operation.
  
  ## Parameters
  
  - `operation` - Name of the operation
  - `interval` - Time interval in seconds to aggregate data
  - `window` - Time window in seconds to analyze
  """
  def get_throughput_stats(operation, interval \\ 60, window \\ 3600) do
    GenServer.call(__MODULE__, {:get_throughput_stats, operation, interval, window})
  end
  
  @doc """
  Gets resource utilization statistics.
  
  ## Parameters
  
  - `resource` - Resource type (:memory, :process, :cpu, etc.)
  - `interval` - Time interval in seconds to aggregate data
  - `window` - Time window in seconds to analyze
  """
  def get_resource_stats(resource, interval \\ 60, window \\ 3600) do
    GenServer.call(__MODULE__, {:get_resource_stats, resource, interval, window})
  end
  
  @doc """
  Gets the current system performance snapshot.
  """
  def get_performance_snapshot do
    GenServer.call(__MODULE__, :get_performance_snapshot)
  end
  
  @doc """
  Gets percentile values for operation latency.
  
  ## Parameters
  
  - `operation` - Name of the operation
  - `percentiles` - List of percentiles to calculate (0.0 to 1.0)
  """
  def get_latency_percentiles(operation, percentiles \\ [0.5, 0.9, 0.95, 0.99, 0.999]) do
    GenServer.call(__MODULE__, {:get_latency_percentiles, operation, percentiles})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    Logger.info("Starting Performance Metrics Collector")
    
    # Set up metric storage
    :ets.new(:performance_metrics, [:named_table, :set, :protected])
    
    # Set up telemetry handlers
    setup_telemetry_handlers()
    
    # Get initial system info
    system_info = collect_system_info()
    
    # Initialize state
    state = %{
      start_time: DateTime.utc_now(),
      last_collection: DateTime.utc_now(),
      collection_interval: Keyword.get(opts, :collection_interval, @collection_interval),
      retention_period: Keyword.get(opts, :retention_period, @retention_period),
      resolution_levels: Keyword.get(opts, :resolution_levels, @resolution_levels),
      latency_metrics: %{},
      throughput_metrics: %{},
      resource_metrics: %{},
      system_info: system_info
    }
    
    # Schedule first metrics collection
    schedule_collection(state.collection_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:record_latency, operation, duration_us, metadata}, state) do
    timestamp = System.system_time(:millisecond)
    
    # Record in ETS for efficient storage and querying
    :ets.insert(:performance_metrics, {{:latency, operation, timestamp}, duration_us, metadata})
    
    # Update in-memory aggregated stats
    latency_metrics = update_latency_metrics(state.latency_metrics, operation, duration_us, timestamp)
    
    {:noreply, %{state | latency_metrics: latency_metrics}}
  end
  
  @impl true
  def handle_cast({:record_throughput, operation, count, metadata}, state) do
    timestamp = System.system_time(:millisecond)
    
    # Record in ETS for efficient storage and querying
    :ets.insert(:performance_metrics, {{:throughput, operation, timestamp}, count, metadata})
    
    # Update in-memory aggregated stats
    throughput_metrics = update_throughput_metrics(state.throughput_metrics, operation, count, timestamp)
    
    {:noreply, %{state | throughput_metrics: throughput_metrics}}
  end
  
  @impl true
  def handle_call({:get_latency_stats, operation, interval, window}, _from, state) do
    now = System.system_time(:millisecond)
    window_ms = window * 1000
    start_time = now - window_ms
    
    # Get metrics from ETS
    metrics = :ets.select(:performance_metrics, 
      [{
        {{:latency, operation, :"$1"}, :"$2", :_},
        [{:>=, :"$1", start_time}],
        [{{:"$1", :"$2"}}]
      }]
    )
    
    # Aggregate by interval
    interval_ms = interval * 1000
    aggregated = aggregate_by_interval(metrics, interval_ms)
    
    # Calculate stats
    stats = calculate_latency_stats(aggregated)
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_call({:get_throughput_stats, operation, interval, window}, _from, state) do
    now = System.system_time(:millisecond)
    window_ms = window * 1000
    start_time = now - window_ms
    
    # Get metrics from ETS
    metrics = :ets.select(:performance_metrics, 
      [{
        {{:throughput, operation, :"$1"}, :"$2", :_},
        [{:>=, :"$1", start_time}],
        [{{:"$1", :"$2"}}]
      }]
    )
    
    # Aggregate by interval
    interval_ms = interval * 1000
    aggregated = aggregate_by_interval(metrics, interval_ms)
    
    # Calculate stats
    stats = calculate_throughput_stats(aggregated, interval)
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_call({:get_resource_stats, resource, interval, window}, _from, state) do
    now = System.system_time(:millisecond)
    window_ms = window * 1000
    start_time = now - window_ms
    
    # Get metrics from ETS
    metrics = :ets.select(:performance_metrics, 
      [{
        {{:resource, resource, :"$1"}, :"$2", :_},
        [{:>=, :"$1", start_time}],
        [{{:"$1", :"$2"}}]
      }]
    )
    
    # Aggregate by interval
    interval_ms = interval * 1000
    aggregated = aggregate_by_interval(metrics, interval_ms)
    
    # Calculate stats
    stats = calculate_resource_stats(aggregated, resource)
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_call(:get_performance_snapshot, _from, state) do
    # Collect current system info
    system_info = collect_system_info()
    
    # Get current metrics
    snapshot = %{
      timestamp: DateTime.utc_now(),
      system: system_info,
      latency: get_latest_latency_metrics(state.latency_metrics),
      throughput: get_latest_throughput_metrics(state.throughput_metrics),
      resources: get_latest_resource_metrics(state.resource_metrics)
    }
    
    {:reply, snapshot, %{state | system_info: system_info}}
  end
  
  @impl true
  def handle_call({:get_latency_percentiles, operation, percentiles}, _from, state) do
    # Get raw latency data for the operation
    raw_data = :ets.select(:performance_metrics, 
      [{
        {{:latency, operation, :_}, :"$1", :_},
        [],
        [:"$1"]
      }]
    )
    
    # Calculate percentiles
    percentile_values = calculate_percentiles(raw_data, percentiles)
    
    {:reply, percentile_values, state}
  end
  
  @impl true
  def handle_info(:collect_metrics, state) do
    # Collect system metrics
    system_metrics = collect_system_metrics()
    
    # Record resource metrics
    Enum.each(system_metrics, fn {resource, value} ->
      timestamp = System.system_time(:millisecond)
      :ets.insert(:performance_metrics, {{:resource, resource, timestamp}, value, %{}})
    end)
    
    # Update resource metrics in state
    resource_metrics = Enum.reduce(system_metrics, state.resource_metrics, fn {resource, value}, acc ->
      update_resource_metrics(acc, resource, value, System.system_time(:millisecond))
    end)
    
    # Clean up old metrics
    clean_old_metrics(state.retention_period)
    
    # Schedule next collection
    schedule_collection(state.collection_interval)
    
    {:noreply, %{state | 
      last_collection: DateTime.utc_now(),
      resource_metrics: resource_metrics
    }}
  end
  
  # Private helpers
  
  defp setup_telemetry_handlers do
    # Handler for performance-related events
    Telemetry.attach_handler(
      :metrics_collector_performance,
      [
        [:automata, :performance, :latency],
        [:automata, :performance, :throughput],
        [:automata, :operation, :duration]
      ],
      &handle_performance_event/4
    )
    
    # Handler for resource metrics
    Telemetry.attach_handler(
      :metrics_collector_resources,
      [
        [:automata, :system, :metrics]
      ],
      &handle_resource_event/4
    )
  end
  
  defp handle_performance_event([:automata, :operation, :duration], %{duration: duration}, metadata, _config) do
    # Convert duration from microseconds to milliseconds for more readable values
    duration_ms = duration / 1000
    operation = Map.get(metadata, :operation, "unknown")
    
    # Record the latency
    record_latency(operation, duration, metadata)
  end
  
  defp handle_performance_event([:automata, :performance, :latency], measurements, metadata, _config) do
    # Already handled directly through record_latency, but could add additional logic here
  end
  
  defp handle_performance_event([:automata, :performance, :throughput], measurements, metadata, _config) do
    # Already handled directly through record_throughput, but could add additional logic here
  end
  
  defp handle_resource_event([:automata, :system, :metrics], measurements, metadata, _config) do
    # Extract resource metrics and record them
    if measurements[:memory] do
      record_resource_metric(:memory_total, measurements.memory.total)
      record_resource_metric(:memory_processes, measurements.memory.processes)
      record_resource_metric(:memory_ets, measurements.memory.ets)
    end
    
    if measurements[:processes] do
      record_resource_metric(:process_count, measurements.processes.count)
      record_resource_metric(:process_limit, measurements.processes.limit)
    end
  end
  
  defp record_resource_metric(resource, value) do
    timestamp = System.system_time(:millisecond)
    :ets.insert(:performance_metrics, {{:resource, resource, timestamp}, value, %{}})
  end
  
  defp collect_system_info do
    %{
      hostname: get_hostname(),
      operating_system: :os.type(),
      otp_release: :erlang.system_info(:otp_release),
      erts_version: :erlang.system_info(:version),
      schedulers: :erlang.system_info(:schedulers),
      schedulers_online: :erlang.system_info(:schedulers_online),
      process_limit: :erlang.system_info(:process_limit),
      atom_limit: :erlang.system_info(:atom_limit),
      port_limit: :erlang.system_info(:port_limit)
    }
  end
  
  defp collect_system_metrics do
    # Memory metrics
    memory = :erlang.memory()
    
    # Process metrics
    process_count = :erlang.system_info(:process_count)
    
    # Scheduler metrics
    scheduler_usage = try do
      :scheduler.sample()
      :scheduler.utilization()
    rescue
      _ -> nil
    end
    
    # Port metrics
    port_count = length(:erlang.ports())
    
    # Message queue metrics
    message_queue_len = Enum.reduce(Process.list(), 0, fn pid, acc ->
      case Process.info(pid, :message_queue_len) do
        {:message_queue_len, len} -> acc + len
        _ -> acc
      end
    end)
    
    # Return as map
    %{
      memory_total: memory[:total],
      memory_processes: memory[:processes],
      memory_system: memory[:system],
      memory_atom: memory[:atom],
      memory_binary: memory[:binary],
      memory_ets: memory[:ets],
      memory_code: memory[:code],
      process_count: process_count,
      process_utilization: process_count / :erlang.system_info(:process_limit),
      port_count: port_count,
      message_queue_len: message_queue_len,
      scheduler_usage: scheduler_usage
    }
  end
  
  defp get_hostname do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end
  
  defp update_latency_metrics(metrics, operation, duration_us, timestamp) do
    # Get or initialize operation metrics
    operation_metrics = Map.get(metrics, operation, %{
      total: 0,
      count: 0,
      min: duration_us,
      max: duration_us,
      sum: 0,
      latest: %{}
    })
    
    # Update metrics
    updated_metrics = %{
      total: operation_metrics.total + duration_us,
      count: operation_metrics.count + 1,
      min: min(operation_metrics.min, duration_us),
      max: max(operation_metrics.max, duration_us),
      sum: operation_metrics.sum + duration_us,
      latest: Map.put(operation_metrics.latest, timestamp, duration_us)
    }
    
    # Add to metrics map
    Map.put(metrics, operation, updated_metrics)
  end
  
  defp update_throughput_metrics(metrics, operation, count, timestamp) do
    # Get or initialize operation metrics
    operation_metrics = Map.get(metrics, operation, %{
      total: 0,
      latest: %{}
    })
    
    # Update metrics
    updated_metrics = %{
      total: operation_metrics.total + count,
      latest: Map.put(operation_metrics.latest, timestamp, count)
    }
    
    # Add to metrics map
    Map.put(metrics, operation, updated_metrics)
  end
  
  defp update_resource_metrics(metrics, resource, value, timestamp) do
    # Get or initialize resource metrics
    resource_metrics = Map.get(metrics, resource, %{
      min: value,
      max: value,
      latest: %{}
    })
    
    # Update metrics
    updated_metrics = %{
      min: min(resource_metrics.min, value),
      max: max(resource_metrics.max, value),
      latest: Map.put(resource_metrics.latest, timestamp, value)
    }
    
    # Add to metrics map
    Map.put(metrics, resource, updated_metrics)
  end
  
  defp get_latest_latency_metrics(latency_metrics) do
    Enum.map(latency_metrics, fn {operation, metrics} ->
      # Calculate average
      avg = if metrics.count > 0, do: metrics.total / metrics.count, else: 0
      
      # Get latest measurements (last 10)
      latest = Enum.sort_by(metrics.latest, fn {timestamp, _} -> timestamp end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {timestamp, value} -> %{timestamp: timestamp, value: value} end)
      
      {operation, %{
        count: metrics.count,
        min: metrics.min,
        max: metrics.max,
        avg: avg,
        latest: latest
      }}
    end)
    |> Map.new()
  end
  
  defp get_latest_throughput_metrics(throughput_metrics) do
    Enum.map(throughput_metrics, fn {operation, metrics} ->
      # Get latest measurements (last 10)
      latest = Enum.sort_by(metrics.latest, fn {timestamp, _} -> timestamp end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {timestamp, value} -> %{timestamp: timestamp, value: value} end)
      
      {operation, %{
        total: metrics.total,
        latest: latest
      }}
    end)
    |> Map.new()
  end
  
  defp get_latest_resource_metrics(resource_metrics) do
    Enum.map(resource_metrics, fn {resource, metrics} ->
      # Get latest measurements (last 10)
      latest = Enum.sort_by(metrics.latest, fn {timestamp, _} -> timestamp end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {timestamp, value} -> %{timestamp: timestamp, value: value} end)
      
      {resource, %{
        min: metrics.min,
        max: metrics.max,
        latest: latest
      }}
    end)
    |> Map.new()
  end
  
  defp aggregate_by_interval(metrics, interval_ms) do
    Enum.reduce(metrics, %{}, fn {timestamp, value}, acc ->
      # Calculate interval bucket
      bucket = div(timestamp, interval_ms) * interval_ms
      
      # Update bucket values
      bucket_values = Map.get(acc, bucket, [])
      Map.put(acc, bucket, [value | bucket_values])
    end)
  end
  
  defp calculate_latency_stats(aggregated) do
    Enum.map(aggregated, fn {timestamp, values} ->
      count = length(values)
      sum = Enum.sum(values)
      avg = if count > 0, do: sum / count, else: 0
      
      %{
        timestamp: timestamp,
        count: count,
        min: Enum.min(values, fn -> 0 end),
        max: Enum.max(values, fn -> 0 end),
        avg: avg,
        p50: percentile(values, 0.5),
        p90: percentile(values, 0.9),
        p99: percentile(values, 0.99)
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end
  
  defp calculate_throughput_stats(aggregated, interval_seconds) do
    Enum.map(aggregated, fn {timestamp, values} ->
      total = Enum.sum(values)
      # Throughput per second
      rate = total / interval_seconds
      
      %{
        timestamp: timestamp,
        count: total,
        rate: rate
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end
  
  defp calculate_resource_stats(aggregated, resource) do
    Enum.map(aggregated, fn {timestamp, values} ->
      avg = Enum.sum(values) / length(values)
      
      %{
        timestamp: timestamp,
        resource: resource,
        min: Enum.min(values),
        max: Enum.max(values),
        avg: avg
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end
  
  defp calculate_percentiles(data, percentiles) do
    sorted_data = Enum.sort(data)
    length = length(sorted_data)
    
    Enum.map(percentiles, fn p ->
      idx = round(length * p) - 1
      idx = max(0, min(length - 1, idx))
      {p, Enum.at(sorted_data, idx)}
    end)
    |> Map.new()
  end
  
  defp percentile(values, p) when is_list(values) and is_number(p) do
    sorted = Enum.sort(values)
    count = length(sorted)
    
    if count > 0 do
      idx = floor(count * p)
      idx = max(0, min(count - 1, idx))
      Enum.at(sorted, idx)
    else
      0
    end
  end
  
  defp clean_old_metrics(retention_period) do
    # Calculate cutoff time
    now = System.system_time(:millisecond)
    cutoff = now - retention_period
    
    # Delete old latency metrics
    :ets.select_delete(:performance_metrics, 
      [{
        {{:latency, :_, :"$1"}, :_, :_},
        [{:<, :"$1", cutoff}],
        [true]
      }]
    )
    
    # Delete old throughput metrics
    :ets.select_delete(:performance_metrics, 
      [{
        {{:throughput, :_, :"$1"}, :_, :_},
        [{:<, :"$1", cutoff}],
        [true]
      }]
    )
    
    # Delete old resource metrics
    :ets.select_delete(:performance_metrics, 
      [{
        {{:resource, :_, :"$1"}, :_, :_},
        [{:<, :"$1", cutoff}],
        [true]
      }]
    )
  end
  
  defp schedule_collection(interval) do
    Process.send_after(self(), :collect_metrics, interval)
  end
end