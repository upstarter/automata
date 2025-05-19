defmodule Automata.Infrastructure.Performance.RateLimiter do
  @moduledoc """
  Rate limiter for controlling throughput of operations in the Automata system.
  
  This module provides several rate limiting algorithms:
  - Token bucket: Smooths traffic by accumulating tokens over time
  - Leaky bucket: Controls the flow rate by dripping requests steadily
  - Fixed window: Limits operations in fixed time windows
  - Sliding window: Provides smoother transitions between windows
  
  Rate limiting is useful for:
  - Protecting system resources from overload
  - Ensuring fair resource allocation between components
  - Preventing cascading failures due to traffic spikes
  - Meeting external API rate limits
  """
  
  use GenServer
  require Logger
  alias Automata.Infrastructure.Resilience.{Telemetry, Logger}
  
  # Rate limiter types
  @limiter_types [:token_bucket, :leaky_bucket, :fixed_window, :sliding_window]
  
  # Client API
  
  @doc """
  Starts the rate limiter.
  
  ## Options
  
  - `:name` - Optional name for the rate limiter (default: module name)
  - `:cleanup_interval` - Interval for cleaning up expired limiters (default: 60_000ms)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Creates a new rate limiter for an operation.
  
  ## Parameters
  
  - `operation` - Name of the operation to limit
  - `type` - Type of rate limiter (:token_bucket, :leaky_bucket, :fixed_window, :sliding_window)
  - `opts` - Options for the rate limiter
    - `:rate` - Operations per second (required)
    - `:burst` - Maximum burst size (required for token/leaky bucket)
    - `:window` - Window size in milliseconds (required for window limiters)
    - `:distributed` - Whether the limiter should be distributed (default: false)
  
  ## Examples
  
  ```elixir
  # Token bucket limiter - 100 ops/sec with bursts up to 500
  RateLimiter.create("api_requests", :token_bucket, rate: 100, burst: 500)
  
  # Fixed window limiter - 1000 ops per 60 seconds
  RateLimiter.create("database_writes", :fixed_window, rate: 1000, window: 60_000)
  ```
  """
  def create(operation, type, opts) when type in @limiter_types and is_list(opts) do
    GenServer.call(__MODULE__, {:create, operation, type, opts})
  end
  
  @doc """
  Checks if an operation is allowed under the rate limit.
  
  ## Parameters
  
  - `operation` - Name of the operation to check
  - `count` - Number of operations to request (default: 1)
  
  ## Returns
  
  - `{:ok, info}` if the operation is allowed
  - `{:error, :rate_limited, info}` if the operation would exceed the rate limit
  """
  def check(operation, count \\ 1) do
    GenServer.call(__MODULE__, {:check, operation, count})
  end
  
  @doc """
  Throttles an operation, waiting if necessary to conform to the rate limit.
  
  ## Parameters
  
  - `operation` - Name of the operation to throttle
  - `count` - Number of operations to request (default: 1)
  - `timeout` - Maximum time to wait in milliseconds (default: 5000)
  
  ## Returns
  
  - `:ok` if the operation is allowed
  - `{:error, :timeout}` if the timeout is reached
  """
  def throttle(operation, count \\ 1, timeout \\ 5000) do
    case check(operation, count) do
      {:ok, _info} ->
        :ok
        
      {:error, :rate_limited, info} ->
        # Calculate how long to wait
        wait_time = min(info.wait_time_ms, timeout)
        
        if wait_time > 0 do
          Logger.debug("Rate limiting operation", %{
            operation: operation,
            count: count,
            wait_time_ms: wait_time
          })
          
          # Wait for the specified time
          Process.sleep(wait_time)
          
          # Retry after waiting
          throttle(operation, count, timeout - wait_time)
        else
          {:error, :timeout}
        end
    end
  end
  
  @doc """
  Executes a function with rate limiting applied.
  
  ## Parameters
  
  - `operation` - Name of the operation to limit
  - `function` - Function to execute
  - `opts` - Options
    - `:count` - Number of operations (default: 1)
    - `:timeout` - Maximum wait time (default: 5000ms)
    - `:on_rate_limited` - Function to call when rate limited (optional)
  
  ## Returns
  
  - Return value of the function if allowed
  - `{:error, :rate_limited}` if rate limited and no on_rate_limited function
  """
  def execute(operation, function, opts \\ []) when is_function(function) do
    count = Keyword.get(opts, :count, 1)
    timeout = Keyword.get(opts, :timeout, 5000)
    on_rate_limited = Keyword.get(opts, :on_rate_limited)
    
    case throttle(operation, count, timeout) do
      :ok ->
        # Track execution
        GenServer.cast(__MODULE__, {:record_execution, operation, count})
        
        # Execute the function
        function.()
        
      {:error, :timeout} = error ->
        if on_rate_limited do
          on_rate_limited.(error)
        else
          error
        end
    end
  end
  
  @doc """
  Gets statistics for a rate limiter.
  
  ## Parameters
  
  - `operation` - Name of the operation
  """
  def get_stats(operation) do
    GenServer.call(__MODULE__, {:get_stats, operation})
  end
  
  @doc """
  Updates the configuration of a rate limiter.
  
  ## Parameters
  
  - `operation` - Name of the operation
  - `opts` - New options for the rate limiter
  """
  def update(operation, opts) do
    GenServer.call(__MODULE__, {:update, operation, opts})
  end
  
  @doc """
  Removes a rate limiter.
  
  ## Parameters
  
  - `operation` - Name of the operation
  """
  def remove(operation) do
    GenServer.call(__MODULE__, {:remove, operation})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    Logger.info("Starting Rate Limiter")
    
    # Create ETS table for rate limiters
    :ets.new(:rate_limiters, [:named_table, :set, :protected])
    
    # Get cleanup interval
    cleanup_interval = Keyword.get(opts, :cleanup_interval, 60_000)
    
    # Schedule cleanup
    schedule_cleanup(cleanup_interval)
    
    {:ok, %{
      limiters: %{},
      cleanup_interval: cleanup_interval
    }}
  end
  
  @impl true
  def handle_call({:create, operation, type, opts}, _from, state) do
    # Validate required options
    with {:ok, validated_opts} <- validate_limiter_options(type, opts) do
      # Create limiter state based on type
      limiter_state = initialize_limiter(type, validated_opts)
      
      # Store in ETS for quick access
      :ets.insert(:rate_limiters, {operation, type, validated_opts, limiter_state})
      
      # Update state
      limiters = Map.put(state.limiters, operation, %{
        type: type,
        opts: validated_opts,
        created_at: System.system_time(:millisecond),
        executions: 0,
        throttled: 0
      })
      
      Logger.info("Created rate limiter", %{
        operation: operation,
        type: type,
        rate: validated_opts[:rate]
      })
      
      {:reply, :ok, %{state | limiters: limiters}}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:check, operation, count}, _from, state) do
    # Look up limiter in ETS
    case :ets.lookup(:rate_limiters, operation) do
      [{^operation, type, opts, limiter_state}] ->
        now = System.system_time(:millisecond)
        
        # Check if operation is allowed based on limiter type
        case check_limit(type, limiter_state, count, opts, now) do
          {:allow, new_state} ->
            # Update limiter state
            :ets.insert(:rate_limiters, {operation, type, opts, new_state})
            
            # Get limiter info
            info = get_limiter_info(type, new_state, opts)
            
            # Return allowed
            {:reply, {:ok, info}, state}
            
          {:deny, wait_time, new_state} ->
            # Update limiter state
            :ets.insert(:rate_limiters, {operation, type, opts, new_state})
            
            # Increment throttled count
            limiters = update_in(state.limiters, [operation, :throttled], &(&1 + 1))
            
            # Get limiter info with wait time
            info = get_limiter_info(type, new_state, opts)
            |> Map.put(:wait_time_ms, wait_time)
            
            # Record telemetry
            Telemetry.execute(
              [:automata, :performance, :rate_limited],
              %{count: 1, wait_time: wait_time},
              %{operation: operation, type: type}
            )
            
            # Return denied with wait time
            {:reply, {:error, :rate_limited, info}, %{state | limiters: limiters}}
        end
        
      [] ->
        # No limiter found, allow the operation
        {:reply, {:ok, %{operation: operation, limited: false}}, state}
    end
  end
  
  @impl true
  def handle_cast({:record_execution, operation, count}, state) do
    # Update execution count if limiter exists
    limiters = case Map.get(state.limiters, operation) do
      nil ->
        state.limiters
        
      limiter ->
        Map.put(state.limiters, operation, %{limiter | executions: limiter.executions + count})
    end
    
    # Record telemetry
    Telemetry.execute(
      [:automata, :performance, :rate_limiter, :execution],
      %{count: count},
      %{operation: operation}
    )
    
    {:noreply, %{state | limiters: limiters}}
  end
  
  @impl true
  def handle_call({:get_stats, operation}, _from, state) do
    case Map.get(state.limiters, operation) do
      nil ->
        {:reply, {:error, :not_found}, state}
        
      limiter ->
        # Look up current state from ETS
        state_info = case :ets.lookup(:rate_limiters, operation) do
          [{^operation, type, opts, limiter_state}] ->
            get_limiter_info(type, limiter_state, opts)
            
          [] ->
            %{}
        end
        
        # Combine with metadata
        stats = Map.merge(limiter, state_info)
        
        {:reply, {:ok, stats}, state}
    end
  end
  
  @impl true
  def handle_call({:update, operation, new_opts}, _from, state) do
    case :ets.lookup(:rate_limiters, operation) do
      [{^operation, type, opts, _limiter_state}] ->
        # Merge existing and new options
        merged_opts = Keyword.merge(opts, new_opts)
        
        # Validate options
        with {:ok, validated_opts} <- validate_limiter_options(type, merged_opts) do
          # Create new limiter state
          limiter_state = initialize_limiter(type, validated_opts)
          
          # Update ETS
          :ets.insert(:rate_limiters, {operation, type, validated_opts, limiter_state})
          
          # Update state
          limiters = update_in(state.limiters, [operation, :opts], fn _ -> validated_opts end)
          
          Logger.info("Updated rate limiter", %{
            operation: operation,
            type: type,
            rate: validated_opts[:rate]
          })
          
          {:reply, :ok, %{state | limiters: limiters}}
        else
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
        
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:remove, operation}, _from, state) do
    # Remove from ETS
    :ets.delete(:rate_limiters, operation)
    
    # Remove from state
    limiters = Map.delete(state.limiters, operation)
    
    Logger.info("Removed rate limiter", %{
      operation: operation
    })
    
    {:reply, :ok, %{state | limiters: limiters}}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Cleanup any expired rate limiters in distributed mode
    now = System.system_time(:millisecond)
    
    # Schedule next cleanup
    schedule_cleanup(state.cleanup_interval)
    
    {:noreply, state}
  end
  
  # Private helpers
  
  defp validate_limiter_options(:token_bucket, opts) do
    required = [:rate, :burst]
    
    case validate_required_options(opts, required) do
      :ok ->
        rate = Keyword.get(opts, :rate)
        burst = Keyword.get(opts, :burst)
        
        if rate <= 0 do
          {:error, "Rate must be positive"}
        else
          if burst <= 0 do
            {:error, "Burst must be positive"}
          else
            {:ok, opts}
          end
        end
        
      {:error, _} = error ->
        error
    end
  end
  
  defp validate_limiter_options(:leaky_bucket, opts) do
    validate_limiter_options(:token_bucket, opts)
  end
  
  defp validate_limiter_options(:fixed_window, opts) do
    required = [:rate, :window]
    
    case validate_required_options(opts, required) do
      :ok ->
        rate = Keyword.get(opts, :rate)
        window = Keyword.get(opts, :window)
        
        if rate <= 0 do
          {:error, "Rate must be positive"}
        else
          if window <= 0 do
            {:error, "Window must be positive"}
          else
            {:ok, opts}
          end
        end
        
      {:error, _} = error ->
        error
    end
  end
  
  defp validate_limiter_options(:sliding_window, opts) do
    required = [:rate, :window]
    
    case validate_required_options(opts, required) do
      :ok ->
        rate = Keyword.get(opts, :rate)
        window = Keyword.get(opts, :window)
        
        if rate <= 0 do
          {:error, "Rate must be positive"}
        else
          if window <= 0 do
            {:error, "Window must be positive"}
          else
            # Set resolution (number of sub-windows) if not specified
            resolution = Keyword.get(opts, :resolution, 10)
            {:ok, Keyword.put(opts, :resolution, resolution)}
          end
        end
        
      {:error, _} = error ->
        error
    end
  end
  
  defp validate_required_options(opts, required) do
    missing = Enum.filter(required, fn key -> not Keyword.has_key?(opts, key) end)
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required options: #{inspect(missing)}"}
    end
  end
  
  defp initialize_limiter(:token_bucket, opts) do
    rate = Keyword.get(opts, :rate)
    burst = Keyword.get(opts, :burst)
    
    now = System.system_time(:millisecond)
    
    %{
      last_refill: now,
      tokens: burst,
      rate_per_ms: rate / 1000,
      max_tokens: burst
    }
  end
  
  defp initialize_limiter(:leaky_bucket, opts) do
    rate = Keyword.get(opts, :rate)
    burst = Keyword.get(opts, :burst)
    
    now = System.system_time(:millisecond)
    
    %{
      last_drip: now,
      bucket_level: 0,
      max_level: burst,
      drip_rate_per_ms: rate / 1000
    }
  end
  
  defp initialize_limiter(:fixed_window, opts) do
    rate = Keyword.get(opts, :rate)
    window = Keyword.get(opts, :window)
    
    now = System.system_time(:millisecond)
    window_start = div(now, window) * window
    
    %{
      window_start: window_start,
      count: 0,
      rate: rate,
      window: window
    }
  end
  
  defp initialize_limiter(:sliding_window, opts) do
    rate = Keyword.get(opts, :rate)
    window = Keyword.get(opts, :window)
    resolution = Keyword.get(opts, :resolution, 10)
    
    now = System.system_time(:millisecond)
    sub_window_size = div(window, resolution)
    current_window = div(now, sub_window_size)
    
    %{
      windows: %{current_window => 0},
      resolution: resolution,
      rate: rate,
      window: window,
      sub_window_size: sub_window_size
    }
  end
  
  defp check_limit(:token_bucket, state, count, opts, now) do
    # Get time since last refill
    time_passed = now - state.last_refill
    
    # Calculate token refill
    new_tokens = state.tokens + time_passed * state.rate_per_ms
    new_tokens = min(new_tokens, state.max_tokens)
    
    if new_tokens >= count do
      # Allow operation
      new_state = %{
        state |
        tokens: new_tokens - count,
        last_refill: now
      }
      
      {:allow, new_state}
    else
      # Calculate wait time
      tokens_needed = count - new_tokens
      wait_time = ceil(tokens_needed / state.rate_per_ms)
      
      # Deny operation
      new_state = %{
        state |
        tokens: new_tokens,
        last_refill: now
      }
      
      {:deny, wait_time, new_state}
    end
  end
  
  defp check_limit(:leaky_bucket, state, count, opts, now) do
    # Get time since last drip
    time_passed = now - state.last_drip
    
    # Calculate dripped amount
    dripped = time_passed * state.drip_rate_per_ms
    new_level = max(0, state.bucket_level - dripped)
    
    if new_level + count <= state.max_level do
      # Allow operation
      new_state = %{
        state |
        bucket_level: new_level + count,
        last_drip: now
      }
      
      {:allow, new_state}
    else
      # Calculate wait time
      overflow = new_level + count - state.max_level
      wait_time = ceil(overflow / state.drip_rate_per_ms)
      
      # Deny operation
      new_state = %{
        state |
        bucket_level: new_level,
        last_drip: now
      }
      
      {:deny, wait_time, new_state}
    end
  end
  
  defp check_limit(:fixed_window, state, count, opts, now) do
    window = state.window
    current_window_start = div(now, window) * window
    
    if current_window_start > state.window_start do
      # New window, reset count
      if count <= state.rate do
        # Allow operation
        new_state = %{
          state |
          window_start: current_window_start,
          count: count
        }
        
        {:allow, new_state}
      else
        # Deny operation - count exceeds rate
        new_state = %{
          state |
          window_start: current_window_start,
          count: 0
        }
        
        # Wait until next window
        wait_time = current_window_start + window - now
        {:deny, wait_time, new_state}
      end
    else
      # Same window
      if state.count + count <= state.rate do
        # Allow operation
        new_state = %{
          state |
          count: state.count + count
        }
        
        {:allow, new_state}
      else
        # Deny operation
        # Wait until next window
        wait_time = current_window_start + window - now
        {:deny, wait_time, state}
      end
    end
  end
  
  defp check_limit(:sliding_window, state, count, opts, now) do
    sub_window_size = state.sub_window_size
    current_window = div(now, sub_window_size)
    
    # Retain only relevant windows
    windows_to_keep = current_window - div(state.window, sub_window_size) + 1
    relevant_windows = Enum.filter(state.windows, fn {window, _} ->
      window >= current_window - windows_to_keep
    end)
    |> Map.new()
    
    # Calculate current count across all relevant windows
    total_count = Enum.reduce(relevant_windows, 0, fn {_, count}, acc ->
      acc + count
    end)
    
    if total_count + count <= state.rate do
      # Allow operation
      new_windows = Map.update(relevant_windows, current_window, count, &(&1 + count))
      
      new_state = %{
        state |
        windows: new_windows
      }
      
      {:allow, new_state}
    else
      # Deny operation
      # Calculate when enough requests will expire to allow this one
      sorted_windows = Enum.sort(relevant_windows)
      
      # Calculate how many requests need to expire
      needed = total_count + count - state.rate
      
      # Find the window where enough requests expire
      {wait_window, _} = Enum.reduce_while(sorted_windows, {current_window + 1, needed}, fn {window, window_count}, {target, still_needed} ->
        if still_needed <= 0 do
          {:halt, {target, 0}}
        else
          {:cont, {window + 1, still_needed - window_count}}
        end
      end)
      
      # Calculate wait time
      wait_time = (wait_window * sub_window_size) - now
      wait_time = max(0, wait_time)
      
      {:deny, wait_time, %{state | windows: relevant_windows}}
    end
  end
  
  defp get_limiter_info(:token_bucket, state, opts) do
    now = System.system_time(:millisecond)
    time_passed = now - state.last_refill
    current_tokens = min(state.tokens + time_passed * state.rate_per_ms, state.max_tokens)
    
    %{
      type: :token_bucket,
      current_tokens: current_tokens,
      max_tokens: state.max_tokens,
      rate_per_second: opts[:rate],
      capacity_percent: current_tokens / state.max_tokens * 100
    }
  end
  
  defp get_limiter_info(:leaky_bucket, state, opts) do
    now = System.system_time(:millisecond)
    time_passed = now - state.last_drip
    dripped = time_passed * state.drip_rate_per_ms
    current_level = max(0, state.bucket_level - dripped)
    
    %{
      type: :leaky_bucket,
      current_level: current_level,
      max_level: state.max_level,
      drain_rate_per_second: opts[:rate],
      fullness_percent: current_level / state.max_level * 100
    }
  end
  
  defp get_limiter_info(:fixed_window, state, opts) do
    now = System.system_time(:millisecond)
    remaining_window = state.window_start + state.window - now
    
    %{
      type: :fixed_window,
      current_count: state.count,
      max_count: state.rate,
      window_size_ms: state.window,
      remaining_window_ms: max(0, remaining_window),
      usage_percent: state.count / state.rate * 100
    }
  end
  
  defp get_limiter_info(:sliding_window, state, opts) do
    now = System.system_time(:millisecond)
    current_window = div(now, state.sub_window_size)
    
    # Calculate current count
    windows_to_keep = current_window - div(state.window, state.sub_window_size) + 1
    relevant_windows = Enum.filter(state.windows, fn {window, _} ->
      window >= current_window - windows_to_keep
    end)
    
    total_count = Enum.reduce(relevant_windows, 0, fn {_, count}, acc ->
      acc + count
    end)
    
    %{
      type: :sliding_window,
      current_count: total_count,
      max_count: state.rate,
      window_size_ms: state.window,
      resolution: state.resolution,
      usage_percent: total_count / state.rate * 100
    }
  end
  
  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
end