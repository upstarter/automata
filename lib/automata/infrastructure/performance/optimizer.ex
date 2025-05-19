defmodule Automata.Infrastructure.Performance.Optimizer do
  @moduledoc """
  Performance optimization utilities for the Automata system.
  
  This module provides tools for:
  - Throttling and rate limiting system activities
  - Dynamic resource allocation
  - Automated performance tuning
  - Load shedding during high load
  - Caching for expensive operations
  """
  
  alias Automata.Infrastructure.Performance.{MetricsCollector, RateLimiter}
  alias Automata.Infrastructure.Resilience.Logger
  
  # Initialization
  
  @doc """
  Initializes the performance optimizer.
  
  ## Parameters
  
  - `opts` - Configuration options
    - `:adaptive_mode` - Enable adaptive optimization (default: true)
    - `:learning_rate` - Rate at which parameters adapt (default: 0.1)
    - `:tuning_interval` - Milliseconds between tuning (default: 60000)
  
  ## Returns
  
  `:ok` if successful.
  """
  def init(opts \\ []) do
    adaptive_mode = Keyword.get(opts, :adaptive_mode, true)
    learning_rate = Keyword.get(opts, :learning_rate, 0.1)
    tuning_interval = Keyword.get(opts, :tuning_interval, 60000)
    
    # Initialize ETS table for optimizer state
    :ets.new(:performance_optimizer, [:named_table, :set, :public])
    
    # Store configuration
    :ets.insert(:performance_optimizer, {:config, %{
      adaptive_mode: adaptive_mode,
      learning_rate: learning_rate,
      tuning_interval: tuning_interval,
      initialized_at: DateTime.utc_now()
    }})
    
    # Initialize optimizations table
    :ets.new(:performance_optimizations, [:named_table, :set, :public])
    
    # Create default rate limiters
    create_default_rate_limiters()
    
    # Start tuning process if adaptive mode is enabled
    if adaptive_mode do
      spawn(fn -> adaptive_tuning_loop(tuning_interval) end)
    end
    
    Logger.info("Performance optimizer initialized", %{
      adaptive_mode: adaptive_mode,
      tuning_interval: tuning_interval
    })
    
    :ok
  end
  
  # Resource optimization
  
  @doc """
  Optimizes process allocation based on workload.
  
  ## Parameters
  
  - `workload` - Type of workload to optimize
  - `opts` - Optimization options
    - `:concurrency` - Target concurrency level
    - `:priority` - Priority level (low, normal, high)
    - `:memory_limit` - Memory limit in bytes
  
  ## Returns
  
  `{:ok, optimized_opts}` with the optimized parameters.
  """
  def optimize_process_allocation(workload, opts \\ []) do
    concurrency = Keyword.get(opts, :concurrency)
    priority = Keyword.get(opts, :priority, :normal)
    memory_limit = Keyword.get(opts, :memory_limit)
    
    # Get system info
    schedulers = :erlang.system_info(:schedulers_online)
    total_memory = :erlang.memory()[:total]
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    
    # Calculate optimal concurrency if not specified
    optimal_concurrency = if concurrency do
      concurrency
    else
      calculate_optimal_concurrency(workload, schedulers, process_count, process_limit)
    end
    
    # Adjust concurrency based on priority
    adjusted_concurrency = case priority do
      :low -> max(1, div(optimal_concurrency, 2))
      :normal -> optimal_concurrency
      :high -> min(schedulers * 2, optimal_concurrency * 2)
    end
    
    # Calculate memory limit if not specified
    optimal_memory_limit = if memory_limit do
      memory_limit
    else
      # Default to 10% of available memory per process
      div(total_memory, 10 * adjusted_concurrency)
    end
    
    # Create optimized options
    optimized_opts = Keyword.merge(opts, [
      concurrency: adjusted_concurrency,
      memory_limit: optimal_memory_limit
    ])
    
    # Log optimization
    Logger.debug("Optimized process allocation", %{
      workload: workload,
      concurrency: adjusted_concurrency,
      memory_limit: optimal_memory_limit
    })
    
    # Track optimization
    track_optimization(workload, :process_allocation, opts, optimized_opts)
    
    {:ok, optimized_opts}
  end
  
  @doc """
  Sets up load shedding for a component under high load.
  
  ## Parameters
  
  - `component` - Component name
  - `opts` - Load shedding options
    - `:max_load` - Maximum load before shedding (default: 0.8)
    - `:shed_ratio` - Ratio of requests to shed when overloaded (default: 0.2)
    - `:recovery_time` - Time to recover after shedding in milliseconds (default: 10000)
  
  ## Returns
  
  `:ok` if successful.
  """
  def setup_load_shedding(component, opts \\ []) do
    max_load = Keyword.get(opts, :max_load, 0.8)
    shed_ratio = Keyword.get(opts, :shed_ratio, 0.2)
    recovery_time = Keyword.get(opts, :recovery_time, 10000)
    
    # Store load shedding configuration
    :ets.insert(:performance_optimizations, {{:load_shedding, component}, %{
      max_load: max_load,
      shed_ratio: shed_ratio,
      recovery_time: recovery_time,
      active: false,
      last_active: nil
    }})
    
    # Create rate limiter for this component
    RateLimiter.create("#{component}_shedding", :token_bucket, [
      rate: 1_000_000, # Very high initial rate
      burst: 1_000_000
    ])
    
    Logger.info("Load shedding configured", %{
      component: component,
      max_load: max_load,
      shed_ratio: shed_ratio
    })
    
    :ok
  end
  
  @doc """
  Checks if a request should be processed or shed under high load.
  
  ## Parameters
  
  - `component` - Component name
  - `metric_fn` - Function to get current load metric
  
  ## Returns
  
  `true` if the request should be processed, `false` if it should be shed.
  """
  def should_process?(component, metric_fn \\ nil) do
    case :ets.lookup(:performance_optimizations, {:load_shedding, component}) do
      [] ->
        # No load shedding configured, always process
        true
        
      [{_, config}] ->
        # Check if we're in recovery period
        now = System.monotonic_time(:millisecond)
        
        if config.active do
          # Shedding is active, check shed ratio
          if :rand.uniform() < config.shed_ratio do
            # Shed this request
            Logger.debug("Shedding request", %{component: component})
            false
          else
            # Process this request
            true
          end
        else
          # Check current load
          current_load = if metric_fn do
            metric_fn.()
          else
            # Default to system load average
            get_system_load()
          end
          
          if current_load > config.max_load and not recovering?(config, now) do
            # Activate load shedding
            :ets.insert(:performance_optimizations, {{:load_shedding, component}, %{
              config |
              active: true,
              last_active: now
            }})
            
            Logger.warning("Activating load shedding", %{
              component: component,
              load: current_load,
              threshold: config.max_load
            })
            
            # Shed this request
            false
          else
            # Process this request
            true
          end
        end
    end
  end
  
  @doc """
  Declares the end of a high load period for a component.
  
  ## Parameters
  
  - `component` - Component name
  
  ## Returns
  
  `:ok` if successful.
  """
  def end_load_shedding(component) do
    case :ets.lookup(:performance_optimizations, {:load_shedding, component}) do
      [] ->
        :ok
        
      [{_, config}] ->
        # Deactivate load shedding
        :ets.insert(:performance_optimizations, {{:load_shedding, component}, %{
          config |
          active: false,
          last_active: System.monotonic_time(:millisecond)
        }})
        
        Logger.info("Deactivated load shedding", %{component: component})
        
        :ok
    end
  end
  
  # Caching
  
  @doc """
  Creates a cache for expensive operations.
  
  ## Parameters
  
  - `cache_name` - Name of the cache
  - `opts` - Cache options
    - `:ttl` - Time-to-live for cache entries in milliseconds (default: 60000)
    - `:max_size` - Maximum number of entries (default: 1000)
    - `:eviction_policy` - Policy for evicting entries when cache is full (:lru, :lfu)
  
  ## Returns
  
  `:ok` if successful.
  """
  def create_cache(cache_name, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, 60000)
    max_size = Keyword.get(opts, :max_size, 1000)
    eviction_policy = Keyword.get(opts, :eviction_policy, :lru)
    
    # Create ETS table for cache
    table_name = String.to_atom("cache_#{cache_name}")
    :ets.new(table_name, [:named_table, :set, :public])
    
    # Store cache configuration
    :ets.insert(:performance_optimizations, {{:cache, cache_name}, %{
      table: table_name,
      ttl: ttl,
      max_size: max_size,
      eviction_policy: eviction_policy,
      created_at: System.monotonic_time(:millisecond),
      hits: 0,
      misses: 0
    }})
    
    Logger.info("Created cache", %{
      name: cache_name,
      ttl: ttl,
      max_size: max_size
    })
    
    :ok
  end
  
  @doc """
  Gets a value from cache, computing it if not present.
  
  ## Parameters
  
  - `cache_name` - Name of the cache
  - `key` - Cache key
  - `compute_fn` - Function to compute the value if not in cache
  
  ## Returns
  
  The cached or computed value.
  """
  def cached(cache_name, key, compute_fn) when is_function(compute_fn, 0) do
    case :ets.lookup(:performance_optimizations, {:cache, cache_name}) do
      [] ->
        # Cache doesn't exist, just compute
        compute_fn.()
        
      [{_, config}] ->
        table = config.table
        now = System.monotonic_time(:millisecond)
        
        # Try to get from cache
        case :ets.lookup(table, key) do
          [{^key, value, expires_at}] when expires_at > now ->
            # Cache hit
            increment_cache_hits(cache_name, config)
            value
            
          _ ->
            # Cache miss
            increment_cache_misses(cache_name, config)
            
            # Compute value
            value = compute_fn.()
            
            # Cache the result
            :ets.insert(table, {key, value, now + config.ttl})
            
            # Check if cache exceeds max size
            if config.max_size > 0 do
              cache_size = :ets.info(table, :size)
              
              if cache_size > config.max_size do
                # Evict entries based on policy
                evict_entries(table, config.eviction_policy)
              end
            end
            
            value
        end
    end
  end
  
  @doc """
  Invalidates a cache entry.
  
  ## Parameters
  
  - `cache_name` - Name of the cache
  - `key` - Cache key
  
  ## Returns
  
  `:ok` if successful.
  """
  def invalidate_cache(cache_name, key) do
    case :ets.lookup(:performance_optimizations, {:cache, cache_name}) do
      [] ->
        :ok
        
      [{_, config}] ->
        # Delete the entry
        :ets.delete(config.table, key)
        :ok
    end
  end
  
  @doc """
  Clears an entire cache.
  
  ## Parameters
  
  - `cache_name` - Name of the cache
  
  ## Returns
  
  `:ok` if successful.
  """
  def clear_cache(cache_name) do
    case :ets.lookup(:performance_optimizations, {:cache, cache_name}) do
      [] ->
        :ok
        
      [{_, config}] ->
        # Delete all entries
        :ets.delete_all_objects(config.table)
        
        # Reset hit/miss counters
        :ets.insert(:performance_optimizations, {{:cache, cache_name}, %{
          config |
          hits: 0,
          misses: 0
        }})
        
        :ok
    end
  end
  
  @doc """
  Gets cache statistics.
  
  ## Parameters
  
  - `cache_name` - Name of the cache
  
  ## Returns
  
  A map with cache statistics.
  """
  def get_cache_stats(cache_name) do
    case :ets.lookup(:performance_optimizations, {:cache, cache_name}) do
      [] ->
        {:error, :not_found}
        
      [{_, config}] ->
        # Get current size
        size = :ets.info(config.table, :size)
        
        # Calculate hit ratio
        total_requests = config.hits + config.misses
        hit_ratio = if total_requests > 0 do
          config.hits / total_requests
        else
          0.0
        end
        
        # Return stats
        {:ok, %{
          size: size,
          max_size: config.max_size,
          ttl_ms: config.ttl,
          hits: config.hits,
          misses: config.misses,
          hit_ratio: hit_ratio
        }}
    end
  end
  
  # Private helpers
  
  defp create_default_rate_limiters do
    # Create rate limiters for system operations
    RateLimiter.create("system_writes", :token_bucket, [
      rate: 10000,
      burst: 20000
    ])
    
    RateLimiter.create("system_reads", :token_bucket, [
      rate: 50000,
      burst: 100000
    ])
    
    RateLimiter.create("agent_updates", :token_bucket, [
      rate: 5000,
      burst: 10000
    ])
  end
  
  defp calculate_optimal_concurrency(workload, schedulers, process_count, process_limit) do
    # Base concurrency on available schedulers
    base_concurrency = schedulers
    
    # Adjust based on workload type
    workload_factor = case workload do
      :cpu_bound -> 1.0
      :io_bound -> 4.0
      :balanced -> 2.0
      _ -> 1.0
    end
    
    # Calculate process headroom
    process_headroom = (process_limit - process_count) / process_limit
    
    # Apply factors
    optimal = round(base_concurrency * workload_factor * process_headroom)
    
    # Ensure reasonable limits
    min(max(1, optimal), schedulers * 4)
  end
  
  defp track_optimization(workload, optimization_type, original_opts, optimized_opts) do
    # Store in ETS for later analysis
    :ets.insert(:performance_optimizations, {{:optimization, workload, optimization_type}, %{
      original: original_opts,
      optimized: optimized_opts,
      timestamp: System.monotonic_time(:millisecond)
    }})
  end
  
  defp get_system_load do
    # Calculate a load value between 0.0 and 1.0
    # Based on a combination of factors
    
    # Process utilization
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    process_util = process_count / process_limit
    
    # Memory utilization
    memory = :erlang.memory()
    total_memory = memory[:total]
    system_memory_kb = case :os.type() do
      {:unix, _} ->
        {mem_info, 0} = System.cmd("grep", ["MemTotal", "/proc/meminfo"])
        case Regex.run(~r/MemTotal:\s+(\d+)/, mem_info) do
          [_, kb] -> String.to_integer(kb)
          _ -> 8 * 1024 * 1024 # Fallback - assume 8GB
        end
        
      _ ->
        8 * 1024 * 1024 # Fallback - assume 8GB
    end
    
    memory_util = total_memory / (system_memory_kb * 1024)
    
    # Message queue load
    queue_load = get_message_queue_load()
    
    # Combine factors
    0.4 * process_util + 0.3 * memory_util + 0.3 * queue_load
  end
  
  defp get_message_queue_load do
    # Sample some processes to get message queue load
    Process.list()
    |> Enum.take_random(100)
    |> Enum.map(fn pid ->
      case Process.info(pid, :message_queue_len) do
        {:message_queue_len, len} -> len
        _ -> 0
      end
    end)
    |> Enum.sum()
    |> then(fn total -> min(total / 1000, 1.0) end)
  end
  
  defp recovering?(config, now) do
    case config.last_active do
      nil -> false
      last_active -> now - last_active < config.recovery_time
    end
  end
  
  defp increment_cache_hits(cache_name, config) do
    :ets.insert(:performance_optimizations, {{:cache, cache_name}, %{
      config |
      hits: config.hits + 1
    }})
  end
  
  defp increment_cache_misses(cache_name, config) do
    :ets.insert(:performance_optimizations, {{:cache, cache_name}, %{
      config |
      misses: config.misses + 1
    }})
  end
  
  defp evict_entries(table, policy) do
    case policy do
      :lru ->
        # LRU: evict oldest entries
        # We'll evict 20% of the entries
        size = :ets.info(table, :size)
        to_evict = round(size * 0.2)
        
        # Find oldest entries
        all_entries = :ets.tab2list(table)
        sorted_by_expiry = Enum.sort_by(all_entries, fn {_, _, expires_at} -> expires_at end)
        
        # Delete oldest entries
        Enum.take(sorted_by_expiry, to_evict)
        |> Enum.each(fn {key, _, _} ->
          :ets.delete(table, key)
        end)
        
      :lfu ->
        # For LFU, we'd need to track access frequency
        # This is a simplified version that doesn't actually implement LFU
        # We'll just evict 20% of random entries
        size = :ets.info(table, :size)
        to_evict = round(size * 0.2)
        
        # Get all keys
        all_entries = :ets.tab2list(table)
        
        # Delete random entries
        Enum.take_random(all_entries, to_evict)
        |> Enum.each(fn {key, _, _} ->
          :ets.delete(table, key)
        end)
    end
  end
  
  defp adaptive_tuning_loop(interval) do
    # Perform adaptive tuning
    tune_performance_parameters()
    
    # Schedule next tuning
    Process.sleep(interval)
    adaptive_tuning_loop(interval)
  end
  
  defp tune_performance_parameters do
    # Get configuration
    [{_, config}] = :ets.lookup(:performance_optimizer, :config)
    
    # Get current system metrics if available
    system_load = get_system_load()
    
    # Tune rate limiters
    tune_rate_limiters(system_load, config.learning_rate)
    
    # Log tuning
    Logger.debug("Performed adaptive tuning", %{
      system_load: system_load
    })
  end
  
  defp tune_rate_limiters(system_load, learning_rate) do
    # Adjust rate limiters based on system load
    # If system is lightly loaded, increase rates
    # If system is heavily loaded, decrease rates
    
    adjustment_factor = cond do
      system_load < 0.3 -> 1.0 + learning_rate
      system_load > 0.7 -> 1.0 - learning_rate
      true -> 1.0
    end
    
    # Update main rate limiters
    update_rate_limiter("system_writes", adjustment_factor)
    update_rate_limiter("system_reads", adjustment_factor)
    update_rate_limiter("agent_updates", adjustment_factor)
  end
  
  defp update_rate_limiter(name, adjustment_factor) do
    # Get current stats
    case RateLimiter.get_stats(name) do
      {:ok, stats} ->
        # Calculate new rate
        current_rate = case stats.type do
          :token_bucket -> stats.rate_per_second
          :leaky_bucket -> stats.drain_rate_per_second
          :fixed_window -> stats.max_count / (stats.window_size_ms / 1000)
          :sliding_window -> stats.max_count / (stats.window_size_ms / 1000)
        end
        
        new_rate = round(current_rate * adjustment_factor)
        
        # Update limiter if rate changed
        if new_rate != current_rate do
          RateLimiter.update(name, [rate: new_rate])
        end
        
      {:error, _} ->
        # Limiter not found, do nothing
        :ok
    end
  end
end