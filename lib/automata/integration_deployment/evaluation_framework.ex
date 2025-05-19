defmodule Automata.IntegrationDeployment.EvaluationFramework do
  @moduledoc """
  Evaluation Framework component for evaluating and benchmarking Automata systems.
  
  This module provides functionality for:
  - Creating and running benchmarks
  - Collecting and analyzing metrics
  - Monitoring system performance
  - Comparing multiple systems or configurations
  
  The Evaluation Framework enables comprehensive assessment of Automata systems
  to ensure they meet performance, efficiency, and effectiveness requirements.
  """
  
  use GenServer
  require Logger
  
  alias Automata.IntegrationDeployment.EvaluationFramework.BenchmarkManager
  alias Automata.IntegrationDeployment.EvaluationFramework.MetricsCollector
  alias Automata.IntegrationDeployment.EvaluationFramework.AnalyticsEngine
  alias Automata.IntegrationDeployment.EvaluationFramework.MonitoringManager
  
  @type benchmark_id :: binary()
  @type benchmark_run_id :: binary()
  @type monitoring_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Evaluation Framework server.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Creates a new evaluation benchmark.
  
  ## Parameters
  - name: Name of the benchmark
  - config: Benchmark configuration
    - type: Type of benchmark (:performance, :accuracy, :resilience, etc.)
    - scenarios: Test scenarios to run
    - metrics: Metrics to collect
    - thresholds: Performance thresholds
  
  ## Returns
  - `{:ok, benchmark_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_benchmark(binary(), map()) :: {:ok, benchmark_id()} | {:error, term()}
  def create_benchmark(name, config) do
    GenServer.call(__MODULE__, {:create_benchmark, name, config})
  end
  
  @doc """
  Lists all benchmarks.
  
  ## Parameters
  - type: Optional benchmark type to filter by
  
  ## Returns
  - `{:ok, benchmarks}` list of benchmarks
  """
  @spec list_benchmarks(atom() | nil) :: {:ok, list(map())}
  def list_benchmarks(type \\ nil) do
    GenServer.call(__MODULE__, {:list_benchmarks, type})
  end
  
  @doc """
  Runs a benchmark against a system.
  
  ## Parameters
  - benchmark_id: ID of the benchmark
  - target_id: ID of the system to benchmark
  - options: Options for the benchmark run
  
  ## Returns
  - `{:ok, benchmark_run_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec run_benchmark(benchmark_id(), binary(), map()) :: 
    {:ok, benchmark_run_id()} | {:error, term()}
  def run_benchmark(benchmark_id, target_id, options \\ %{}) do
    GenServer.call(__MODULE__, {:run_benchmark, benchmark_id, target_id, options})
  end
  
  @doc """
  Gets results from a benchmark run.
  
  ## Parameters
  - benchmark_run_id: ID of the benchmark run
  
  ## Returns
  - `{:ok, results}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_benchmark_results(benchmark_run_id()) :: {:ok, map()} | {:error, term()}
  def get_benchmark_results(benchmark_run_id) do
    GenServer.call(__MODULE__, {:get_benchmark_results, benchmark_run_id})
  end
  
  @doc """
  Compares multiple benchmark results.
  
  ## Parameters
  - run_ids: List of benchmark run IDs to compare
  - metrics: List of metrics to compare
  
  ## Returns
  - `{:ok, comparison}` if successful
  - `{:error, reason}` if failed
  """
  @spec compare_benchmark_results(list(benchmark_run_id()), list()) :: 
    {:ok, map()} | {:error, term()}
  def compare_benchmark_results(run_ids, metrics \\ []) do
    GenServer.call(__MODULE__, {:compare_benchmark_results, run_ids, metrics})
  end
  
  @doc """
  Creates a new monitoring configuration.
  
  ## Parameters
  - name: Name of the monitoring configuration
  - config: Monitoring configuration
    - target_id: ID of the system to monitor
    - metrics: Metrics to collect
    - frequency: Collection frequency
    - alerts: Alert configuration
  
  ## Returns
  - `{:ok, monitoring_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_monitoring(binary(), map()) :: {:ok, monitoring_id()} | {:error, term()}
  def create_monitoring(name, config) do
    GenServer.call(__MODULE__, {:create_monitoring, name, config})
  end
  
  @doc """
  Gets monitoring data for a system.
  
  ## Parameters
  - monitoring_id: ID of the monitoring configuration
  - timeframe: Optional timeframe for the data
  
  ## Returns
  - `{:ok, monitoring_data}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_monitoring_data(monitoring_id(), map()) :: {:ok, map()} | {:error, term()}
  def get_monitoring_data(monitoring_id, timeframe \\ %{}) do
    GenServer.call(__MODULE__, {:get_monitoring_data, monitoring_id, timeframe})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Evaluation Framework")
    {:ok, %{initialized: true}}
  end
  
  @impl true
  def handle_call({:create_benchmark, name, config}, _from, state) do
    case BenchmarkManager.create_benchmark(name, config) do
      {:ok, benchmark_id} = result ->
        Logger.info("Created benchmark: #{name} (#{benchmark_id})")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:list_benchmarks, type}, _from, state) do
    result = BenchmarkManager.list_benchmarks(type)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:run_benchmark, benchmark_id, target_id, options}, _from, state) do
    case BenchmarkManager.run_benchmark(benchmark_id, target_id, options) do
      {:ok, run_id} = result ->
        Logger.info("Started benchmark run: #{run_id}")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_benchmark_results, benchmark_run_id}, _from, state) do
    result = BenchmarkManager.get_results(benchmark_run_id)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:compare_benchmark_results, run_ids, metrics}, _from, state) do
    case AnalyticsEngine.compare_results(run_ids, metrics) do
      {:ok, comparison} = result ->
        Logger.info("Compared #{length(run_ids)} benchmark runs")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:create_monitoring, name, config}, _from, state) do
    case MonitoringManager.create_monitoring(name, config) do
      {:ok, monitoring_id} = result ->
        Logger.info("Created monitoring configuration: #{name} (#{monitoring_id})")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_monitoring_data, monitoring_id, timeframe}, _from, state) do
    result = MonitoringManager.get_monitoring_data(monitoring_id, timeframe)
    {:reply, result, state}
  end
end

# Component implementations

defmodule Automata.IntegrationDeployment.EvaluationFramework.BenchmarkManager do
  @moduledoc """
  Manager for benchmarks in the Evaluation Framework component.
  
  Responsible for creating, configuring, and running benchmarks to evaluate
  the performance and effectiveness of Automata systems.
  """
  
  use GenServer
  require Logger
  
  alias Automata.IntegrationDeployment.EvaluationFramework.MetricsCollector
  
  @type benchmark_id :: binary()
  @type benchmark_run_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Benchmark Manager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Creates a new benchmark.
  
  ## Parameters
  - name: Name of the benchmark
  - config: Benchmark configuration
  
  ## Returns
  - `{:ok, benchmark_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_benchmark(binary(), map()) :: {:ok, benchmark_id()} | {:error, term()}
  def create_benchmark(name, config) do
    GenServer.call(__MODULE__, {:create_benchmark, name, config})
  end
  
  @doc """
  Lists all benchmarks.
  
  ## Parameters
  - type: Optional benchmark type to filter by
  
  ## Returns
  - `{:ok, benchmarks}` list of benchmarks
  """
  @spec list_benchmarks(atom() | nil) :: {:ok, list(map())}
  def list_benchmarks(type \\ nil) do
    GenServer.call(__MODULE__, {:list_benchmarks, type})
  end
  
  @doc """
  Runs a benchmark against a system.
  
  ## Parameters
  - benchmark_id: ID of the benchmark
  - target_id: ID of the system to benchmark
  - options: Options for the benchmark run
  
  ## Returns
  - `{:ok, benchmark_run_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec run_benchmark(benchmark_id(), binary(), map()) :: 
    {:ok, benchmark_run_id()} | {:error, term()}
  def run_benchmark(benchmark_id, target_id, options) do
    GenServer.call(__MODULE__, {:run_benchmark, benchmark_id, target_id, options})
  end
  
  @doc """
  Gets results from a benchmark run.
  
  ## Parameters
  - benchmark_run_id: ID of the benchmark run
  
  ## Returns
  - `{:ok, results}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_results(benchmark_run_id()) :: {:ok, map()} | {:error, term()}
  def get_results(benchmark_run_id) do
    GenServer.call(__MODULE__, {:get_results, benchmark_run_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Benchmark Manager")
    
    # Initialize with empty state
    initial_state = %{
      benchmarks: %{},
      runs: %{},
      results: %{},
      next_benchmark_id: 1,
      next_run_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:create_benchmark, name, config}, _from, state) do
    # Validate config
    with :ok <- validate_benchmark_config(config) do
      # Generate benchmark ID
      benchmark_id = "benchmark_#{state.next_benchmark_id}"
      
      # Create benchmark record
      timestamp = DateTime.utc_now()
      benchmark = %{
        id: benchmark_id,
        name: name,
        type: Map.get(config, :type, :performance),
        scenarios: Map.get(config, :scenarios, []),
        metrics: Map.get(config, :metrics, []),
        thresholds: Map.get(config, :thresholds, %{}),
        created_at: timestamp,
        updated_at: timestamp
      }
      
      # Update state
      updated_state = %{
        state |
        benchmarks: Map.put(state.benchmarks, benchmark_id, benchmark),
        next_benchmark_id: state.next_benchmark_id + 1
      }
      
      {:reply, {:ok, benchmark_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create benchmark: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:list_benchmarks, nil}, _from, state) do
    # Return all benchmarks
    benchmarks = Map.values(state.benchmarks)
    |> Enum.sort_by(& &1.created_at, DateTime)
    
    {:reply, {:ok, benchmarks}, state}
  end
  
  @impl true
  def handle_call({:list_benchmarks, type}, _from, state) do
    # Return benchmarks of the specified type
    benchmarks = Map.values(state.benchmarks)
    |> Enum.filter(& &1.type == type)
    |> Enum.sort_by(& &1.created_at, DateTime)
    
    {:reply, {:ok, benchmarks}, state}
  end
  
  @impl true
  def handle_call({:run_benchmark, benchmark_id, target_id, options}, _from, state) do
    case Map.fetch(state.benchmarks, benchmark_id) do
      {:ok, benchmark} ->
        # Generate run ID
        run_id = "run_#{state.next_run_id}"
        
        # Create run record
        timestamp = DateTime.utc_now()
        run = %{
          id: run_id,
          benchmark_id: benchmark_id,
          target_id: target_id,
          options: options,
          started_at: timestamp,
          completed_at: nil,
          status: :running
        }
        
        # Update state
        updated_state = %{
          state |
          runs: Map.put(state.runs, run_id, run),
          next_run_id: state.next_run_id + 1
        }
        
        # Start benchmark run in background
        spawn(fn -> execute_benchmark(benchmark, run_id, target_id, options) end)
        
        {:reply, {:ok, run_id}, updated_state}
      
      :error ->
        {:reply, {:error, :benchmark_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:get_results, benchmark_run_id}, _from, state) do
    case Map.fetch(state.runs, benchmark_run_id) do
      {:ok, run} ->
        results = Map.get(state.results, benchmark_run_id)
        
        if results do
          {:reply, {:ok, results}, state}
        else
          if run.status == :running do
            {:reply, {:error, :benchmark_still_running}, state}
          else
            {:reply, {:error, :results_not_found}, state}
          end
        end
      
      :error ->
        {:reply, {:error, :benchmark_run_not_found}, state}
    end
  end
  
  @impl true
  def handle_info({:benchmark_completed, run_id, results}, state) do
    case Map.fetch(state.runs, run_id) do
      {:ok, run} ->
        # Update run status
        updated_run = %{
          run |
          status: :completed,
          completed_at: DateTime.utc_now()
        }
        
        # Update state
        updated_state = %{
          state |
          runs: Map.put(state.runs, run_id, updated_run),
          results: Map.put(state.results, run_id, results)
        }
        
        Logger.info("Benchmark run completed: #{run_id}")
        {:noreply, updated_state}
      
      :error ->
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:benchmark_failed, run_id, reason}, state) do
    case Map.fetch(state.runs, run_id) do
      {:ok, run} ->
        # Update run status
        updated_run = %{
          run |
          status: :failed,
          completed_at: DateTime.utc_now(),
          failure_reason: reason
        }
        
        # Update state
        updated_state = %{
          state |
          runs: Map.put(state.runs, run_id, updated_run)
        }
        
        Logger.error("Benchmark run failed: #{run_id} - #{reason}")
        {:noreply, updated_state}
      
      :error ->
        {:noreply, state}
    end
  end
  
  # Helper functions
  
  defp validate_benchmark_config(config) do
    # Validate required fields
    required_fields = [:type, :scenarios, :metrics]
    
    missing_fields = Enum.filter(required_fields, fn field -> 
      !Map.has_key?(config, field) || is_nil(Map.get(config, field))
    end)
    
    if Enum.empty?(missing_fields) do
      # Validate benchmark type
      if config.type in [:performance, :accuracy, :resilience, :scalability, :integration] do
        :ok
      else
        {:error, "Invalid benchmark type: #{config.type}"}
      end
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
  
  defp execute_benchmark(benchmark, run_id, target_id, options) do
    # In a real implementation, this would execute the actual benchmark
    # against the target system
    
    try do
      # Collect metrics for each scenario
      results = Enum.map(benchmark.scenarios, fn scenario ->
        # Simulate scenario execution
        Process.sleep(500)
        
        # Collect metrics
        metrics = collect_scenario_metrics(benchmark.metrics, target_id, scenario)
        
        # Return scenario result
        %{
          scenario: scenario,
          metrics: metrics,
          passed: evaluate_thresholds(metrics, benchmark.thresholds)
        }
      end)
      
      # Aggregate results
      aggregated_results = aggregate_results(results, benchmark.metrics)
      
      # Notify benchmark completion
      send(self(), {:benchmark_completed, run_id, aggregated_results})
    catch
      kind, reason ->
        # Notify benchmark failure
        send(self(), {:benchmark_failed, run_id, Exception.format(kind, reason, __STACKTRACE__)})
    end
  end
  
  defp collect_scenario_metrics(metrics, target_id, scenario) do
    # In a real implementation, this would collect actual metrics from
    # the target system for the given scenario
    
    # Simulate metric collection
    Enum.map(metrics, fn metric ->
      case metric do
        :latency ->
          {metric, :rand.uniform(100) + 50} # 50-150ms
        
        :throughput ->
          {metric, :rand.uniform(1000) + 500} # 500-1500 req/s
        
        :error_rate ->
          {metric, :rand.uniform() * 0.02} # 0-2%
        
        :memory_usage ->
          {metric, :rand.uniform(500) + 100} # 100-600MB
        
        :cpu_usage ->
          {metric, :rand.uniform(50) + 10} # 10-60%
        
        _ ->
          {metric, :rand.uniform(100)}
      end
    end)
    |> Enum.into(%{})
  end
  
  defp evaluate_thresholds(metrics, thresholds) do
    # Check if all metrics pass their thresholds
    Enum.all?(thresholds, fn {metric, threshold} ->
      case Map.get(metrics, metric) do
        nil -> 
          true # No metric, no threshold check
        
        value ->
          evaluate_threshold(value, threshold)
      end
    end)
  end
  
  defp evaluate_threshold(value, threshold) do
    cond do
      is_map(threshold) && Map.has_key?(threshold, :max) ->
        value <= threshold.max
      
      is_map(threshold) && Map.has_key?(threshold, :min) ->
        value >= threshold.min
      
      is_map(threshold) && Map.has_key?(threshold, :equals) ->
        value == threshold.equals
      
      is_number(threshold) ->
        value <= threshold
      
      true ->
        true # No valid threshold, considered passing
    end
  end
  
  defp aggregate_results(results, metrics) do
    # Calculate overall success
    overall_passed = Enum.all?(results, & &1.passed)
    
    # Calculate aggregated metrics
    aggregated_metrics = Enum.reduce(metrics, %{}, fn metric, acc ->
      # Extract values for this metric from all scenarios
      values = Enum.map(results, fn result ->
        Map.get(result.metrics, metric)
      end)
      |> Enum.reject(&is_nil/1)
      
      if Enum.empty?(values) do
        acc
      else
        # Calculate statistics
        Map.put(acc, metric, %{
          min: Enum.min(values),
          max: Enum.max(values),
          avg: Enum.sum(values) / length(values),
          values: values
        })
      end
    end)
    
    # Return aggregated results
    %{
      scenario_results: results,
      aggregated_metrics: aggregated_metrics,
      overall_passed: overall_passed,
      timestamp: DateTime.utc_now()
    }
  end
end

defmodule Automata.IntegrationDeployment.EvaluationFramework.MetricsCollector do
  @moduledoc """
  Collector for metrics in the Evaluation Framework component.
  
  Responsible for collecting various performance and operational metrics from
  Automata systems for evaluation and monitoring purposes.
  """
  
  use GenServer
  require Logger
  
  # Client API
  
  @doc """
  Starts the Metrics Collector.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Collects metrics from a system.
  
  ## Parameters
  - target_id: ID of the system to collect metrics from
  - metrics: List of metrics to collect
  
  ## Returns
  - `{:ok, metrics_data}` if successful
  - `{:error, reason}` if failed
  """
  @spec collect_metrics(binary(), list()) :: {:ok, map()} | {:error, term()}
  def collect_metrics(target_id, metrics) do
    GenServer.call(__MODULE__, {:collect_metrics, target_id, metrics})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Metrics Collector")
    
    # Initialize with empty state
    initial_state = %{
      metric_definitions: %{
        latency: %{
          description: "Response time in milliseconds",
          unit: "ms",
          type: :timing
        },
        throughput: %{
          description: "Number of requests processed per second",
          unit: "req/s",
          type: :gauge
        },
        error_rate: %{
          description: "Percentage of requests that result in errors",
          unit: "%",
          type: :gauge
        },
        memory_usage: %{
          description: "Memory usage in megabytes",
          unit: "MB",
          type: :gauge
        },
        cpu_usage: %{
          description: "CPU usage percentage",
          unit: "%",
          type: :gauge
        }
      }
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:collect_metrics, target_id, metrics}, _from, state) do
    # In a real implementation, this would collect actual metrics from
    # the target system
    
    # Simulate metric collection
    collected_metrics = Enum.reduce(metrics, %{}, fn metric, acc ->
      if Map.has_key?(state.metric_definitions, metric) do
        # Generate a simulated value based on metric type
        value = case state.metric_definitions[metric].type do
          :timing -> :rand.uniform(100) + 10
          :gauge -> :rand.uniform(100) * (if metric == :error_rate, do: 0.01, else: 1)
          :counter -> :rand.uniform(10000)
          _ -> :rand.uniform(100)
        end
        
        Map.put(acc, metric, value)
      else
        acc
      end
    end)
    
    {:reply, {:ok, collected_metrics}, state}
  end
end

defmodule Automata.IntegrationDeployment.EvaluationFramework.AnalyticsEngine do
  @moduledoc """
  Analytics engine for the Evaluation Framework component.
  
  Responsible for analyzing benchmark results and performance data to provide
  insights and comparisons between different systems or configurations.
  """
  
  use GenServer
  require Logger
  
  alias Automata.IntegrationDeployment.EvaluationFramework.BenchmarkManager
  
  @type benchmark_run_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Analytics Engine.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Compares multiple benchmark results.
  
  ## Parameters
  - run_ids: List of benchmark run IDs to compare
  - metrics: List of metrics to compare
  
  ## Returns
  - `{:ok, comparison}` if successful
  - `{:error, reason}` if failed
  """
  @spec compare_results(list(benchmark_run_id()), list()) :: {:ok, map()} | {:error, term()}
  def compare_results(run_ids, metrics) do
    GenServer.call(__MODULE__, {:compare_results, run_ids, metrics})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Analytics Engine")
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:compare_results, run_ids, metrics}, _from, state) do
    # Get results for each run
    run_results = Enum.map(run_ids, fn run_id ->
      case BenchmarkManager.get_results(run_id) do
        {:ok, results} -> {run_id, results}
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    if Enum.empty?(run_results) do
      {:reply, {:error, :no_valid_results}, state}
    else
      # Extract run info
      runs_info = Enum.map(run_results, fn {run_id, results} ->
        %{
          run_id: run_id,
          timestamp: results.timestamp,
          overall_passed: results.overall_passed
        }
      end)
      
      # Compare metrics across runs
      metrics_comparison = compare_metrics(run_results, metrics)
      
      # Create comparison report
      comparison = %{
        runs: runs_info,
        metrics_comparison: metrics_comparison,
        compared_at: DateTime.utc_now()
      }
      
      {:reply, {:ok, comparison}, state}
    end
  end
  
  # Helper functions
  
  defp compare_metrics(run_results, metrics) do
    # For each metric, compare across all runs
    available_metrics = if Enum.empty?(metrics) do
      # Extract all available metrics from first run
      {_, first_results} = List.first(run_results)
      Map.keys(first_results.aggregated_metrics)
    else
      metrics
    end
    
    # For each metric, collect and compare values across runs
    Enum.map(available_metrics, fn metric ->
      metric_values = Enum.map(run_results, fn {run_id, results} ->
        metric_data = get_in(results, [:aggregated_metrics, metric])
        
        if metric_data do
          {run_id, metric_data.avg}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})
      
      if map_size(metric_values) > 0 do
        # Find best value (lower is better for most metrics)
        best_run_id = Enum.min_by(metric_values, fn {_run_id, value} -> value end) |> elem(0)
        
        # Calculate percentage differences
        reference_value = metric_values[best_run_id]
        differences = Enum.map(metric_values, fn {run_id, value} ->
          if run_id == best_run_id do
            {run_id, 0.0}
          else
            percent_diff = ((value - reference_value) / reference_value) * 100
            {run_id, percent_diff}
          end
        end)
        |> Enum.into(%{})
        
        # Return metric comparison
        {metric, %{
          values: metric_values,
          best_run_id: best_run_id,
          differences: differences
        }}
      else
        {metric, nil}
      end
    end)
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end
end

defmodule Automata.IntegrationDeployment.EvaluationFramework.MonitoringManager do
  @moduledoc """
  Manager for monitoring configurations in the Evaluation Framework component.
  
  Responsible for creating and managing monitoring configurations for ongoing
  evaluation of Automata systems in production.
  """
  
  use GenServer
  require Logger
  
  alias Automata.IntegrationDeployment.EvaluationFramework.MetricsCollector
  
  @type monitoring_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Monitoring Manager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Creates a new monitoring configuration.
  
  ## Parameters
  - name: Name of the monitoring configuration
  - config: Monitoring configuration
  
  ## Returns
  - `{:ok, monitoring_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_monitoring(binary(), map()) :: {:ok, monitoring_id()} | {:error, term()}
  def create_monitoring(name, config) do
    GenServer.call(__MODULE__, {:create_monitoring, name, config})
  end
  
  @doc """
  Gets monitoring data for a system.
  
  ## Parameters
  - monitoring_id: ID of the monitoring configuration
  - timeframe: Optional timeframe for the data
  
  ## Returns
  - `{:ok, monitoring_data}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_monitoring_data(monitoring_id(), map()) :: {:ok, map()} | {:error, term()}
  def get_monitoring_data(monitoring_id, timeframe) do
    GenServer.call(__MODULE__, {:get_monitoring_data, monitoring_id, timeframe})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Monitoring Manager")
    
    # Initialize with empty state
    initial_state = %{
      monitoring_configs: %{},
      monitoring_data: %{},
      next_id: 1
    }
    
    # Start periodic data collection
    schedule_data_collection()
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:create_monitoring, name, config}, _from, state) do
    # Validate config
    with :ok <- validate_monitoring_config(config) do
      # Generate monitoring ID
      monitoring_id = "monitoring_#{state.next_id}"
      
      # Create monitoring record
      timestamp = DateTime.utc_now()
      monitoring = %{
        id: monitoring_id,
        name: name,
        target_id: Map.get(config, :target_id),
        metrics: Map.get(config, :metrics, []),
        frequency: Map.get(config, :frequency, 60), # seconds
        alerts: Map.get(config, :alerts, []),
        created_at: timestamp,
        updated_at: timestamp,
        active: true
      }
      
      # Update state
      updated_state = %{
        state |
        monitoring_configs: Map.put(state.monitoring_configs, monitoring_id, monitoring),
        next_id: state.next_id + 1
      }
      
      {:reply, {:ok, monitoring_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create monitoring: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_monitoring_data, monitoring_id, timeframe}, _from, state) do
    case Map.fetch(state.monitoring_configs, monitoring_id) do
      {:ok, _config} ->
        # Get monitoring data
        all_data = Map.get(state.monitoring_data, monitoring_id, [])
        
        # Apply timeframe filter
        filtered_data = apply_timeframe_filter(all_data, timeframe)
        
        {:reply, {:ok, filtered_data}, state}
      
      :error ->
        {:reply, {:error, :monitoring_not_found}, state}
    end
  end
  
  @impl true
  def handle_info(:collect_monitoring_data, state) do
    # Collect data for each active monitoring configuration
    updated_monitoring_data = Enum.reduce(state.monitoring_configs, state.monitoring_data, 
      fn {monitoring_id, config}, acc ->
        if config.active do
          # Collect metrics for this configuration
          case MetricsCollector.collect_metrics(config.target_id, config.metrics) do
            {:ok, metrics} ->
              # Add timestamp to metrics
              data_point = Map.put(metrics, :timestamp, DateTime.utc_now())
              
              # Add to monitoring data
              Map.update(acc, monitoring_id, [data_point], fn data_points ->
                # Keep up to 1000 data points
                [data_point | Enum.take(data_points, 999)]
              end)
            
            {:error, _reason} ->
              # Failed to collect metrics, leave data unchanged
              acc
          end
        else
          # Monitoring not active, don't collect data
          acc
        end
      end)
    
    # Schedule next collection
    schedule_data_collection()
    
    {:noreply, %{state | monitoring_data: updated_monitoring_data}}
  end
  
  # Helper functions
  
  defp validate_monitoring_config(config) do
    # Validate required fields
    required_fields = [:target_id, :metrics]
    
    missing_fields = Enum.filter(required_fields, fn field -> 
      !Map.has_key?(config, field) || is_nil(Map.get(config, field))
    end)
    
    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
  
  defp apply_timeframe_filter(data_points, timeframe) do
    case timeframe do
      %{since: since} when not is_nil(since) ->
        Enum.filter(data_points, fn point -> 
          DateTime.compare(point.timestamp, since) in [:gt, :eq]
        end)
      
      %{until: until} when not is_nil(until) ->
        Enum.filter(data_points, fn point -> 
          DateTime.compare(point.timestamp, until) in [:lt, :eq]
        end)
      
      %{since: since, until: until} when not is_nil(since) and not is_nil(until) ->
        Enum.filter(data_points, fn point -> 
          DateTime.compare(point.timestamp, since) in [:gt, :eq] and
          DateTime.compare(point.timestamp, until) in [:lt, :eq]
        end)
      
      %{last: seconds} when is_integer(seconds) and seconds > 0 ->
        cutoff = DateTime.add(DateTime.utc_now(), -seconds, :second)
        Enum.filter(data_points, fn point -> 
          DateTime.compare(point.timestamp, cutoff) in [:gt, :eq]
        end)
      
      _ ->
        # No timeframe filter
        data_points
    end
  end
  
  defp schedule_data_collection do
    # Collect data every 10 seconds
    Process.send_after(self(), :collect_monitoring_data, 10 * 1000)
  end
end