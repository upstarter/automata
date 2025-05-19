defmodule Automata.Examples.PerformanceDemo do
  @moduledoc """
  Demonstrates the performance features of the Automata system.
  
  This module provides examples of:
  - Performance metrics collection
  - Rate limiting
  - Benchmarking
  - Profiling
  - Caching
  - Load shedding
  
  To run this demo, execute:
  ```
  iex -S mix
  Automata.Examples.PerformanceDemo.run()
  ```
  """
  
  alias Automata.Infrastructure.Performance.{
    MetricsCollector,
    RateLimiter,
    Benchmarker,
    Profiler,
    Optimizer
  }
  
  @doc """
  Runs the performance features demonstration.
  """
  def run do
    IO.puts("\n=== Automata Performance Features Demo ===\n")
    
    # Demonstrate metrics collection
    IO.puts("\n--- Metrics Collection Demo ---")
    demo_metrics_collection()
    
    # Demonstrate rate limiting
    IO.puts("\n--- Rate Limiting Demo ---")
    demo_rate_limiting()
    
    # Demonstrate benchmarking
    IO.puts("\n--- Benchmarking Demo ---")
    demo_benchmarking()
    
    # Demonstrate profiling
    IO.puts("\n--- Profiling Demo ---")
    demo_profiling()
    
    # Demonstrate optimization
    IO.puts("\n--- Optimization Demo ---")
    demo_optimization()
    
    IO.puts("\n=== Demo Complete ===\n")
    :ok
  end
  
  # Metrics Collection Demo
  
  defp demo_metrics_collection do
    IO.puts("Recording performance metrics...")
    
    # Record latency for some operations
    for i <- 1..5 do
      # Simulate operation with variable latency
      {result, latency_us} = time_function(fn ->
        # Simulate work
        Process.sleep(10 * i)
        :ok
      end)
      
      # Record the latency
      MetricsCollector.record_latency("demo.operation", latency_us, %{
        iteration: i
      })
      
      IO.puts("  Operation #{i}: #{latency_us}μs")
    end
    
    # Record throughput
    MetricsCollector.record_throughput("demo.throughput", 100, %{
      operation_type: "batch_process"
    })
    
    IO.puts("Recorded throughput: 100 operations")
    
    # Get performance snapshot
    IO.puts("\nGetting performance snapshot...")
    snapshot = MetricsCollector.get_performance_snapshot()
    
    # Display some stats
    IO.puts("System info:")
    IO.puts("  Hostname: #{snapshot.system.hostname}")
    IO.puts("  OS: #{inspect(snapshot.system.operating_system)}")
    IO.puts("  Schedulers: #{snapshot.system.schedulers}")
    
    # Display latency stats if available
    if snapshot.latency["demo.operation"] do
      stats = snapshot.latency["demo.operation"]
      IO.puts("\nLatency stats for demo.operation:")
      IO.puts("  Count: #{stats.count}")
      IO.puts("  Min: #{stats.min}μs")
      IO.puts("  Max: #{stats.max}μs")
      IO.puts("  Avg: #{Float.round(stats.avg, 2)}μs")
    end
    
    IO.puts("\nMetrics collection working properly!")
  end
  
  # Rate Limiting Demo
  
  defp demo_rate_limiting do
    # Create a rate limiter
    IO.puts("Creating rate limiter...")
    RateLimiter.create("demo_operations", :token_bucket, [
      rate: 5,  # 5 operations per second
      burst: 10 # Allow bursts up to 10 operations
    ])
    
    # Get initial stats
    {:ok, initial_stats} = RateLimiter.get_stats("demo_operations")
    IO.puts("Rate limiter created with rate: #{initial_stats.rate_per_second} ops/sec")
    
    # Try some operations
    IO.puts("\nPerforming operations with rate limiting...")
    
    results = Enum.map(1..15, fn i ->
      case RateLimiter.check("demo_operations") do
        {:ok, _} ->
          IO.puts("  Operation #{i}: Allowed")
          RateLimiter.execute("demo_operations", fn -> 
            Process.sleep(50) # Simulate work
            :ok
          end)
          :allowed
          
        {:error, :rate_limited, info} ->
          IO.puts("  Operation #{i}: Rate limited (wait #{info.wait_time_ms}ms)")
          :limited
      end
      
      # Small delay between operations
      Process.sleep(100)
    end)
    
    # Count results
    allowed = Enum.count(results, &(&1 == :allowed))
    limited = Enum.count(results, &(&1 == :limited))
    
    IO.puts("\nOperations allowed: #{allowed}")
    IO.puts("Operations limited: #{limited}")
    
    # Update rate limiter
    IO.puts("\nUpdating rate limiter...")
    RateLimiter.update("demo_operations", [rate: 10])
    
    # Get updated stats
    {:ok, updated_stats} = RateLimiter.get_stats("demo_operations")
    IO.puts("Rate limiter updated with rate: #{updated_stats.rate_per_second} ops/sec")
    
    IO.puts("\nRate limiting working properly!")
  end
  
  # Benchmarking Demo
  
  defp demo_benchmarking do
    IO.puts("Running simple benchmark...")
    
    # Define a simple function to benchmark
    benchmark_result = Benchmarker.run("demo_operation", fn ->
      # Simulate work
      fib(20)
    end, iterations: 100, warmup: 10)
    
    # Display results
    IO.puts("\nBenchmark results:")
    IO.puts("  Iterations: #{benchmark_result.iterations}")
    IO.puts("  Average time: #{Float.round(benchmark_result.avg_time, 2)}μs")
    IO.puts("  Throughput: #{Float.round(benchmark_result.throughput, 2)} ops/sec")
    IO.puts("  p90: #{Float.round(benchmark_result.p90, 2)}μs")
    
    IO.puts("\nComparing implementations...")
    
    # Compare different implementations
    comparison = Benchmarker.compare("fibonacci", %{
      "recursive" => fn -> fib(20) end,
      "tail_recursive" => fn -> tail_fib(20) end,
      "stream" => fn -> stream_fib(20) end
    }, iterations: 10, warmup: 5)
    
    # Display comparison results
    IO.puts("\nComparison results:")
    IO.puts("  Fastest: #{comparison.fastest}")
    IO.puts("  Slowest: #{comparison.slowest}")
    IO.puts("  Difference factor: #{Float.round(comparison.diff_factor, 2)}x")
    
    IO.puts("\nBenchmarking working properly!")
  end
  
  # Profiling Demo
  
  defp demo_profiling do
    IO.puts("Profiling function...")
    
    # Profile a function
    profile_result = Profiler.profile_function("demo_function", fn ->
      # Do some work that involves multiple functions
      result = expensive_operation(100)
      another_operation(result)
    end, type: :all)
    
    # Display results
    IO.puts("\nProfiling results:")
    IO.puts("  Total time: #{Float.round(profile_result.total_time_us / 1000, 2)}ms")
    IO.puts("  Reductions: #{profile_result.reductions}")
    
    # Memory profiling
    IO.puts("\nProfiling memory usage...")
    memory_profile = Profiler.profile_memory(top_n: 5)
    
    # Display memory info
    IO.puts("\nMemory usage:")
    IO.puts("  Total: #{format_bytes(memory_profile.system.total)}")
    IO.puts("  Processes: #{format_bytes(memory_profile.system.processes)}")
    IO.puts("  ETS: #{format_bytes(memory_profile.system.ets)}")
    
    IO.puts("\nProfiling working properly!")
  end
  
  # Optimization Demo
  
  defp demo_optimization do
    # Initialize optimizer if not already initialized
    if :ets.info(:performance_optimizer) == :undefined do
      Optimizer.init()
    end
    
    IO.puts("Optimizing process allocation...")
    
    # Optimize process allocation
    {:ok, opts} = Optimizer.optimize_process_allocation(:balanced, [
      priority: :normal
    ])
    
    IO.puts("Optimized process allocation:")
    IO.puts("  Concurrency: #{opts[:concurrency]}")
    IO.puts("  Memory limit: #{format_bytes(opts[:memory_limit])}")
    
    # Setup caching
    IO.puts("\nSetting up caching...")
    Optimizer.create_cache("demo_cache", ttl: 5000, max_size: 100)
    
    # Use the cache
    IO.puts("Using cache for expensive operations...")
    
    # First call (cache miss)
    start_time = System.monotonic_time(:microsecond)
    result1 = Optimizer.cached("demo_cache", "fib_30", fn -> 
      IO.puts("  Cache miss - computing value...")
      fib(30)
    end)
    end_time = System.monotonic_time(:microsecond)
    first_duration = end_time - start_time
    
    # Second call (cache hit)
    start_time = System.monotonic_time(:microsecond)
    result2 = Optimizer.cached("demo_cache", "fib_30", fn -> 
      IO.puts("  This shouldn't be printed - computing value...")
      fib(30)
    end)
    end_time = System.monotonic_time(:microsecond)
    second_duration = end_time - start_time
    
    # Verify results
    IO.puts("  First call (miss): #{first_duration}μs")
    IO.puts("  Second call (hit): #{second_duration}μs")
    IO.puts("  Speedup factor: #{Float.round(first_duration / second_duration, 2)}x")
    
    # Setup load shedding
    IO.puts("\nSetting up load shedding...")
    Optimizer.setup_load_shedding("demo_service", max_load: 0.8, shed_ratio: 0.5)
    
    # Simulate load shedding
    IO.puts("Simulating high load scenario...")
    
    # Process some requests
    processed = Enum.map(1..10, fn i ->
      if Optimizer.should_process?("demo_service", fn -> 0.9 end) do
        IO.puts("  Request #{i}: Processed")
        true
      else
        IO.puts("  Request #{i}: Shed due to high load")
        false
      end
    end)
    
    # End load shedding
    Optimizer.end_load_shedding("demo_service")
    
    # Count processed vs shed
    processed_count = Enum.count(processed, &(&1))
    shed_count = Enum.count(processed, &(!&1))
    
    IO.puts("\nRequests processed: #{processed_count}")
    IO.puts("Requests shed: #{shed_count}")
    
    IO.puts("\nOptimization working properly!")
  end
  
  # Helper functions
  
  defp time_function(function) do
    start_time = System.monotonic_time(:microsecond)
    result = function.()
    end_time = System.monotonic_time(:microsecond)
    
    {result, end_time - start_time}
  end
  
  # Different fibonacci implementations for benchmarking
  
  # Recursive fibonacci
  defp fib(0), do: 0
  defp fib(1), do: 1
  defp fib(n), do: fib(n-1) + fib(n-2)
  
  # Tail-recursive fibonacci
  defp tail_fib(n), do: do_tail_fib(n, 0, 1)
  defp do_tail_fib(0, _acc1, _acc2), do: 0
  defp do_tail_fib(1, _acc1, acc2), do: acc2
  defp do_tail_fib(n, acc1, acc2), do: do_tail_fib(n-1, acc2, acc1+acc2)
  
  # Stream-based fibonacci
  defp stream_fib(n) do
    Stream.unfold({0, 1}, fn {a, b} -> {a, {b, a + b}} end)
    |> Enum.at(n)
  end
  
  # Expensive operations for profiling
  
  defp expensive_operation(n) do
    # Do some work
    Enum.reduce(1..n, 0, fn i, acc ->
      acc + i * i
    end)
  end
  
  defp another_operation(n) do
    # More work
    for i <- 1..n, do: :math.pow(i, 2)
  end
  
  # Formatting helpers
  
  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024*1024 -> "#{Float.round(bytes/1024, 2)} KB"
      bytes < 1024*1024*1024 -> "#{Float.round(bytes/1024/1024, 2)} MB"
      true -> "#{Float.round(bytes/1024/1024/1024, 2)} GB"
    end
  end
end