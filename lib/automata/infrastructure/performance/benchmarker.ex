defmodule Automata.Infrastructure.Performance.Benchmarker do
  @moduledoc """
  Benchmarking utilities for measuring and analyzing system performance.
  
  This module provides tools for:
  - Measuring operation latency
  - Testing system throughput under load
  - Conducting stress tests
  - Comparing performance between implementations
  - Profiling system bottlenecks
  """
  
  alias Automata.Infrastructure.Performance.MetricsCollector
  alias Automata.Infrastructure.Resilience.{Telemetry, Logger}
  
  # Benchmark runners
  
  @doc """
  Runs a simple benchmark, executing a function multiple times and measuring performance.
  
  ## Parameters
  
  - `name` - Name of the benchmark
  - `function` - Function to benchmark
  - `opts` - Options for the benchmark
    - `:iterations` - Number of iterations (default: 1000)
    - `:warmup` - Number of warmup iterations (default: 100)
    - `:concurrency` - Number of concurrent workers (default: 1)
    - `:prepare` - Function to prepare the benchmark environment (optional)
    - `:cleanup` - Function to clean up after the benchmark (optional)
  
  ## Returns
  
  A map with benchmark results.
  
  ## Examples
  
  ```elixir
  Benchmarker.run("list_operations", fn ->
    MyModule.list_all_items()
  end, iterations: 1000, concurrency: 2)
  ```
  """
  def run(name, function, opts \\ []) when is_function(function) do
    iterations = Keyword.get(opts, :iterations, 1000)
    warmup = Keyword.get(opts, :warmup, 100)
    concurrency = Keyword.get(opts, :concurrency, 1)
    prepare_fn = Keyword.get(opts, :prepare)
    cleanup_fn = Keyword.get(opts, :cleanup)
    
    Logger.info("Starting benchmark", %{
      name: name,
      iterations: iterations,
      warmup: warmup,
      concurrency: concurrency
    })
    
    # Run preparation if provided
    if prepare_fn, do: prepare_fn.()
    
    try do
      # Run warmup iterations
      if warmup > 0 do
        Logger.debug("Running warmup", %{count: warmup})
        run_iterations(function, warmup, 1)
      end
      
      # Start measuring
      start_time = System.monotonic_time(:microsecond)
      
      # Run benchmark iterations
      measurements = if concurrency > 1 do
        # Concurrent benchmark
        run_concurrent(function, iterations, concurrency)
      else
        # Sequential benchmark
        run_iterations(function, iterations, 1)
      end
      
      # Calculate total duration
      end_time = System.monotonic_time(:microsecond)
      total_duration = end_time - start_time
      
      # Calculate results
      results = calculate_results(measurements, total_duration, iterations)
      
      # Record in metrics collector if available
      if Process.whereis(MetricsCollector) do
        # Record average latency
        MetricsCollector.record_latency("benchmark.#{name}", results.avg_time, %{
          iterations: iterations,
          concurrency: concurrency
        })
        
        # Record throughput
        MetricsCollector.record_throughput("benchmark.#{name}", iterations, %{
          duration_ms: total_duration / 1000,
          concurrency: concurrency
        })
      end
      
      # Emit telemetry event
      Telemetry.execute(
        [:automata, :performance, :benchmark, :completed],
        %{
          total_time: total_duration,
          avg_time: results.avg_time,
          min_time: results.min_time,
          max_time: results.max_time,
          throughput: results.throughput
        },
        %{
          name: name,
          iterations: iterations,
          concurrency: concurrency
        }
      )
      
      # Log results
      Logger.info("Benchmark completed", %{
        name: name,
        avg_time_us: Float.round(results.avg_time, 2),
        throughput: Float.round(results.throughput, 2),
        iterations: iterations,
        concurrency: concurrency
      })
      
      results
    after
      # Run cleanup if provided
      if cleanup_fn, do: cleanup_fn.()
    end
  end
  
  @doc """
  Runs a load test, gradually increasing load and measuring system response.
  
  ## Parameters
  
  - `name` - Name of the load test
  - `function` - Function to test under load
  - `opts` - Options for the load test
    - `:initial_rate` - Initial operations per second (default: 10)
    - `:target_rate` - Target operations per second (default: 1000)
    - `:step_size` - Rate increment per step (default: 10)
    - `:step_duration` - Duration of each step in milliseconds (default: 10000)
    - `:max_duration` - Maximum test duration in milliseconds (default: 300000)
    - `:concurrency` - Maximum number of concurrent workers (default: 100)
    - `:prepare` - Function to prepare the test environment (optional)
    - `:cleanup` - Function to clean up after the test (optional)
    - `:on_step` - Function called after each step with results (optional)
  
  ## Returns
  
  A map with load test results.
  
  ## Examples
  
  ```elixir
  Benchmarker.load_test("api_requests", fn ->
    MyAPI.make_request()
  end, initial_rate: 10, target_rate: 500, step_size: 20)
  ```
  """
  def load_test(name, function, opts \\ []) when is_function(function) do
    initial_rate = Keyword.get(opts, :initial_rate, 10)
    target_rate = Keyword.get(opts, :target_rate, 1000)
    step_size = Keyword.get(opts, :step_size, 10)
    step_duration = Keyword.get(opts, :step_duration, 10000)
    max_duration = Keyword.get(opts, :max_duration, 300000)
    concurrency = Keyword.get(opts, :concurrency, 100)
    prepare_fn = Keyword.get(opts, :prepare)
    cleanup_fn = Keyword.get(opts, :cleanup)
    on_step_fn = Keyword.get(opts, :on_step)
    
    Logger.info("Starting load test", %{
      name: name,
      initial_rate: initial_rate,
      target_rate: target_rate,
      step_size: step_size,
      step_duration: step_duration,
      max_duration: max_duration
    })
    
    # Run preparation if provided
    if prepare_fn, do: prepare_fn.()
    
    try do
      start_time = System.monotonic_time(:millisecond)
      
      # Initialize step results
      step_results = []
      
      # Run the load test steps
      {results, saturation_point} = Enum.reduce_while(
        Stream.iterate(initial_rate, &(&1 + step_size)),
        {step_results, nil},
        fn rate, {results, _} ->
          # Check if we've reached the target rate or max duration
          current_time = System.monotonic_time(:millisecond)
          elapsed = current_time - start_time
          
          if rate > target_rate or elapsed > max_duration do
            # End the test
            {:halt, {results, nil}}
          else
            # Run test at current rate
            step_result = run_load_step(name, function, rate, step_duration, concurrency)
            
            # Check if this step reached saturation
            saturation_detected = detect_saturation(step_result, rate)
            
            # Call the step callback if provided
            if on_step_fn, do: on_step_fn.(rate, step_result)
            
            # Log step results
            Logger.info("Load test step", %{
              name: name,
              rate: rate,
              actual_rate: Float.round(step_result.actual_rate, 2),
              avg_latency_ms: Float.round(step_result.avg_latency / 1000, 2),
              error_rate: Float.round(step_result.error_rate * 100, 2),
              saturation: saturation_detected
            })
            
            # Add results to list
            updated_results = [step_result | results]
            
            if saturation_detected do
              # Stop at saturation point
              {:halt, {updated_results, rate}}
            else
              # Continue to next rate
              {:cont, {updated_results, nil}}
            end
          end
        end
      )
      
      # Calculate final results
      end_time = System.monotonic_time(:millisecond)
      total_duration = end_time - start_time
      
      # Sort results by rate
      sorted_results = Enum.sort_by(results, & &1.target_rate)
      
      # Calculate max throughput and optimal rate
      {max_throughput, optimal_rate} = calculate_optimal_rate(sorted_results)
      
      final_results = %{
        name: name,
        duration_ms: total_duration,
        steps: Enum.reverse(sorted_results),
        max_throughput: max_throughput,
        optimal_rate: optimal_rate,
        saturation_point: saturation_point
      }
      
      # Emit telemetry event
      Telemetry.execute(
        [:automata, :performance, :load_test, :completed],
        %{
          duration: total_duration,
          max_throughput: max_throughput,
          optimal_rate: optimal_rate,
          saturation_point: saturation_point || 0
        },
        %{name: name}
      )
      
      Logger.info("Load test completed", %{
        name: name,
        duration_s: Float.round(total_duration / 1000, 1),
        max_throughput: Float.round(max_throughput, 2),
        optimal_rate: optimal_rate,
        saturation_point: saturation_point
      })
      
      final_results
    after
      # Run cleanup if provided
      if cleanup_fn, do: cleanup_fn.()
    end
  end
  
  @doc """
  Generates a comparison report between multiple implementations.
  
  ## Parameters
  
  - `name` - Name of the comparison
  - `implementations` - Map of implementation name to function
  - `opts` - Options for the comparison
    - `:iterations` - Number of iterations (default: 1000)
    - `:warmup` - Number of warmup iterations (default: 100)
    - `:prepare` - Function to prepare the comparison environment (optional)
    - `:cleanup` - Function to clean up after the comparison (optional)
  
  ## Returns
  
  A map with comparison results.
  
  ## Examples
  
  ```elixir
  Benchmarker.compare("sorting_algorithms", %{
    "bubble_sort" => fn -> bubble_sort(data) end,
    "merge_sort" => fn -> merge_sort(data) end,
    "quick_sort" => fn -> quick_sort(data) end
  })
  ```
  """
  def compare(name, implementations, opts \\ []) when is_map(implementations) do
    iterations = Keyword.get(opts, :iterations, 1000)
    warmup = Keyword.get(opts, :warmup, 100)
    prepare_fn = Keyword.get(opts, :prepare)
    cleanup_fn = Keyword.get(opts, :cleanup)
    
    Logger.info("Starting comparison", %{
      name: name,
      implementations: Map.keys(implementations),
      iterations: iterations
    })
    
    # Run preparation if provided
    if prepare_fn, do: prepare_fn.()
    
    try do
      # Run each implementation
      results = Enum.map(implementations, fn {impl_name, function} ->
        Logger.info("Benchmarking implementation", %{name: impl_name})
        
        # Run the benchmark
        result = run("#{name}.#{impl_name}", function, [
          iterations: iterations,
          warmup: warmup,
          concurrency: 1
        ])
        
        # Add implementation name
        Map.put(result, :implementation, impl_name)
      end)
      
      # Sort results by average time
      sorted_results = Enum.sort_by(results, & &1.avg_time)
      
      # Calculate relative performance
      baseline = hd(sorted_results).avg_time
      results_with_relative = Enum.map(sorted_results, fn result ->
        relative = result.avg_time / baseline
        Map.put(result, :relative, relative)
      end)
      
      # Create comparison
      comparison = %{
        name: name,
        iterations: iterations,
        results: results_with_relative,
        fastest: hd(results_with_relative).implementation,
        slowest: List.last(results_with_relative).implementation,
        diff_factor: List.last(results_with_relative).relative
      }
      
      # Log comparison results
      log_comparison_results(comparison)
      
      comparison
    after
      # Run cleanup if provided
      if cleanup_fn, do: cleanup_fn.()
    end
  end
  
  @doc """
  Runs a profile on a function, identifying bottlenecks.
  
  ## Parameters
  
  - `name` - Name of the profile
  - `function` - Function to profile
  - `opts` - Options for the profile
    - `:iterations` - Number of iterations (default: 100)
    - `:report_level` - Detail level of the report (default: :medium)
  
  ## Returns
  
  A map with profiling results.
  
  ## Examples
  
  ```elixir
  Benchmarker.profile("database_query", fn ->
    MyDatabase.execute_query("SELECT * FROM users")
  end)
  ```
  """
  def profile(name, function, opts \\ []) when is_function(function) do
    iterations = Keyword.get(opts, :iterations, 100)
    report_level = Keyword.get(opts, :report_level, :medium)
    
    Logger.info("Starting profiling", %{
      name: name,
      iterations: iterations
    })
    
    # Try to use fprof if available
    profile_result = try do
      # Create temporary file for profile output
      {file, file_path} = Temp.open("profile")
      File.close(file)
      
      # Start profiling
      :fprof.start()
      
      # Profile the function for the specified iterations
      :fprof.apply(fn ->
        for _ <- 1..iterations, do: function.()
      end, [])
      
      # Wait for profiler to complete
      :fprof.profile()
      
      # Generate analysis
      :fprof.analyse(dest: to_charlist(file_path), totals: true)
      
      # Read and parse results
      profile_data = File.read!(file_path)
      parsed_results = parse_fprof_output(profile_data, report_level)
      
      # Stop profiler
      :fprof.stop()
      
      # Return results
      %{
        name: name,
        iterations: iterations,
        profile_type: :fprof,
        results: parsed_results
      }
    rescue
      error in [UndefinedFunctionError] ->
        # Fall back to simple timing if fprof is not available
        Logger.warning("fprof not available, falling back to simple timing", %{
          error: inspect(error)
        })
        
        # Run a simple benchmark instead
        result = run(name, function, iterations: iterations, warmup: 0)
        
        # Modify result to indicate it's a simple timing
        Map.merge(result, %{
          name: name,
          iterations: iterations,
          profile_type: :simple_timing
        })
    end
    
    # Log profiling completed
    Logger.info("Profiling completed", %{
      name: name,
      profile_type: profile_result.profile_type
    })
    
    profile_result
  end
  
  @doc """
  Measures the latency of a single operation.
  
  ## Parameters
  
  - `function` - Function to measure
  
  ## Returns
  
  Tuple of `{result, duration_microseconds}`.
  
  ## Examples
  
  ```elixir
  {result, duration} = Benchmarker.measure(fn ->
    MyModule.perform_operation()
  end)
  ```
  """
  def measure(function) when is_function(function) do
    start_time = System.monotonic_time(:microsecond)
    result = function.()
    end_time = System.monotonic_time(:microsecond)
    
    {result, end_time - start_time}
  end
  
  # Private helpers
  
  defp run_iterations(function, iterations, sample_factor) do
    Enum.map(1..iterations, fn _ ->
      {result, duration} = measure(function)
      {result, duration * sample_factor}
    end)
  end
  
  defp run_concurrent(function, iterations, concurrency) do
    # Calculate iterations per worker
    iterations_per_worker = div(iterations, concurrency)
    remainder = rem(iterations, concurrency)
    
    # Spawn workers
    workers = Enum.map(1..concurrency, fn worker_id ->
      # Assign iterations to worker, distributing remainder
      worker_iterations = if worker_id <= remainder do
        iterations_per_worker + 1
      else
        iterations_per_worker
      end
      
      # Spawn worker
      Task.async(fn ->
        run_iterations(function, worker_iterations, 1)
      end)
    end)
    
    # Await all workers
    results = Task.await_many(workers, 300_000)
    
    # Concatenate results
    List.flatten(results)
  end
  
  defp calculate_results(measurements, total_duration, iterations) do
    # Extract durations
    durations = Enum.map(measurements, fn {_, duration} -> duration end)
    
    # Calculate statistics
    sum = Enum.sum(durations)
    avg = sum / iterations
    min = Enum.min(durations)
    max = Enum.max(durations)
    
    # Calculate standard deviation
    variance = Enum.reduce(durations, 0, fn duration, acc ->
      diff = duration - avg
      acc + diff * diff
    end) / iterations
    stddev = :math.sqrt(variance)
    
    # Calculate throughput (operations per second)
    throughput = iterations / (total_duration / 1_000_000)
    
    # Calculate percentiles
    sorted = Enum.sort(durations)
    p50 = percentile(sorted, 0.5)
    p90 = percentile(sorted, 0.9)
    p95 = percentile(sorted, 0.95)
    p99 = percentile(sorted, 0.99)
    
    %{
      avg_time: avg,
      min_time: min,
      max_time: max,
      total_time: total_duration,
      stddev: stddev,
      throughput: throughput,
      iterations: iterations,
      p50: p50,
      p90: p90,
      p95: p95,
      p99: p99
    }
  end
  
  defp percentile(sorted_list, p) when is_list(sorted_list) and is_number(p) do
    len = length(sorted_list)
    
    if len == 0 do
      0
    else
      idx = floor(len * p)
      idx = max(0, min(len - 1, idx))
      Enum.at(sorted_list, idx)
    end
  end
  
  defp run_load_step(name, function, rate, duration, max_concurrency) do
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + duration
    
    # Calculate sleep time between operations to achieve target rate
    sleep_time = div(1000, rate)
    
    # Start worker pool
    pool_size = min(rate, max_concurrency)
    
    # Start workers
    workers = for _ <- 1..pool_size do
      Task.async(fn ->
        worker_loop(function, end_time, rate, pool_size)
      end)
    end
    
    # Wait for all workers to complete
    worker_results = Task.await_many(workers, duration + 10_000)
    
    # Aggregate results
    all_latencies = Enum.flat_map(worker_results, & &1.latencies)
    all_errors = Enum.flat_map(worker_results, & &1.errors)
    
    total_operations = Enum.sum(Enum.map(worker_results, & &1.operations))
    completed_operations = total_operations - length(all_errors)
    
    # Calculate statistics
    actual_duration = System.monotonic_time(:millisecond) - start_time
    actual_rate = total_operations / (actual_duration / 1000)
    
    avg_latency = if length(all_latencies) > 0 do
      Enum.sum(all_latencies) / length(all_latencies)
    else
      0
    end
    
    # Calculate error rate
    error_rate = if total_operations > 0 do
      length(all_errors) / total_operations
    else
      0
    end
    
    # Calculate percentiles
    sorted_latencies = Enum.sort(all_latencies)
    p50 = percentile(sorted_latencies, 0.5)
    p90 = percentile(sorted_latencies, 0.9)
    p95 = percentile(sorted_latencies, 0.95)
    p99 = percentile(sorted_latencies, 0.99)
    
    %{
      target_rate: rate,
      actual_rate: actual_rate,
      duration_ms: actual_duration,
      operations: total_operations,
      completed: completed_operations,
      errors: length(all_errors),
      error_rate: error_rate,
      avg_latency: avg_latency,
      min_latency: if(length(sorted_latencies) > 0, do: hd(sorted_latencies), else: 0),
      max_latency: if(length(sorted_latencies) > 0, do: List.last(sorted_latencies), else: 0),
      p50: p50,
      p90: p90,
      p95: p95,
      p99: p99
    }
  end
  
  defp worker_loop(function, end_time, rate, pool_size) do
    # Calculate worker's share of the rate
    worker_rate = div(rate, pool_size)
    
    # Calculate sleep time
    sleep_time = if worker_rate > 0, do: div(1000, worker_rate), else: 0
    
    # Initialize result accumulator
    result = %{
      operations: 0,
      latencies: [],
      errors: []
    }
    
    # Run until end time
    do_worker_loop(function, end_time, sleep_time, result)
  end
  
  defp do_worker_loop(function, end_time, sleep_time, result) do
    now = System.monotonic_time(:millisecond)
    
    if now >= end_time do
      # Time's up, return results
      result
    else
      # Execute function and measure latency
      {function_result, latency} = measure(function)
      
      # Process result
      new_result = case function_result do
        {:ok, _} ->
          # Success
          %{
            operations: result.operations + 1,
            latencies: [latency | result.latencies],
            errors: result.errors
          }
          
        {:error, _} = error ->
          # Error
          %{
            operations: result.operations + 1,
            latencies: [latency | result.latencies],
            errors: [error | result.errors]
          }
          
        _ ->
          # Treat as success
          %{
            operations: result.operations + 1,
            latencies: [latency | result.latencies],
            errors: result.errors
          }
      end
      
      # Sleep if needed
      if sleep_time > 0 do
        Process.sleep(sleep_time)
      end
      
      # Continue loop
      do_worker_loop(function, end_time, sleep_time, new_result)
    end
  end
  
  defp detect_saturation(step_result, rate) do
    # Check for signs of saturation
    cond do
      # High error rate (over 10%)
      step_result.error_rate > 0.1 ->
        true
        
      # Actual rate significantly below target rate (over 20% difference)
      step_result.actual_rate < rate * 0.8 ->
        true
        
      # Sharp increase in latency (p95 > 500ms)
      step_result.p95 > 500_000 ->
        true
        
      # Otherwise, not saturated
      true ->
        false
    end
  end
  
  defp calculate_optimal_rate(results) do
    # Find the point with maximum throughput
    {max_throughput, optimal_rate} = Enum.reduce(results, {0, 0}, fn step, {max_throughput, optimal_rate} ->
      # Calculate actual throughput (completed operations per second)
      throughput = step.completed / (step.duration_ms / 1000)
      
      if throughput > max_throughput do
        {throughput, step.target_rate}
      else
        {max_throughput, optimal_rate}
      end
    end)
    
    {max_throughput, optimal_rate}
  end
  
  defp log_comparison_results(comparison) do
    Logger.info("Comparison results: #{comparison.name}", %{
      fastest: comparison.fastest,
      slowest: comparison.slowest,
      diff_factor: Float.round(comparison.diff_factor, 2)
    })
    
    # Log details for each implementation
    Enum.each(comparison.results, fn result ->
      Logger.info("  #{result.implementation}", %{
        avg_time_us: Float.round(result.avg_time, 2),
        throughput: Float.round(result.throughput, 2),
        relative: Float.round(result.relative, 2)
      })
    end)
  end
  
  defp parse_fprof_output(output, level) do
    # Split output into lines
    lines = String.split(output, "\n")
    
    # Extract totals
    totals_line = Enum.find(lines, fn line ->
      String.contains?(line, "[Total]")
    end)
    
    # Parse function entries
    function_entries = Enum.filter(lines, fn line ->
      String.match?(line, ~r/^\s+\[.+\]/)
    end)
    
    # Limit number of entries based on level
    entry_limit = case level do
      :low -> 10
      :medium -> 30
      :high -> 100
      _ -> 30
    end
    
    # Parse entries
    parsed_entries = Enum.take(function_entries, entry_limit)
    |> Enum.map(fn line ->
      parse_fprof_line(line)
    end)
    |> Enum.filter(&(&1 != nil))
    
    # Return parsed results
    %{
      totals: parse_fprof_line(totals_line),
      entries: parsed_entries
    }
  end
  
  defp parse_fprof_line(line) when is_binary(line) do
    # Example format: [   x.xxx] Module.function/arity
    case Regex.run(~r/^\s*\[\s*(\d+\.\d+)\s*\]\s*(.+)$/, line) do
      [_, time, function] ->
        %{
          time: String.to_float(time),
          function: String.trim(function)
        }
        
      _ ->
        nil
    end
  end
  
  defp parse_fprof_line(nil), do: nil
end