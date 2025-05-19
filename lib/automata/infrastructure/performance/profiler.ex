defmodule Automata.Infrastructure.Performance.Profiler do
  @moduledoc """
  Profiling tools for analyzing system performance bottlenecks.
  
  This module provides utilities for:
  - Function profiling with call graphs
  - Memory usage analysis
  - Process monitoring
  - Message queue tracking
  - Reduction counting
  
  These tools help identify performance bottlenecks in the system.
  """
  
  alias Automata.Infrastructure.Resilience.Logger
  
  # Profiling functions
  
  @doc """
  Profiles a function and generates a detailed analysis.
  
  ## Parameters
  
  - `name` - Name of the profile
  - `function` - Function to profile
  - `opts` - Profiling options
    - `:type` - Type of profiling (:time, :memory, :reductions, :all)
    - `:output` - Output format (:text, :map)
    - `:sort_by` - How to sort results (:time, :calls, :memory)
  
  ## Returns
  
  A profiling report in the specified format.
  
  ## Examples
  
  ```elixir
  Profiler.profile_function("my_critical_operation", fn ->
    MyCriticalModule.perform_operation()
  end, type: :all)
  ```
  """
  def profile_function(name, function, opts \\ []) when is_function(function) do
    type = Keyword.get(opts, :type, :time)
    output = Keyword.get(opts, :output, :text)
    sort_by = Keyword.get(opts, :sort_by, :time)
    
    Logger.info("Starting function profiling", %{
      name: name,
      type: type
    })
    
    # Choose profiling method based on type
    profile_result = case type do
      :time ->
        profile_function_time(function)
        
      :memory ->
        profile_function_memory(function)
        
      :reductions ->
        profile_function_reductions(function)
        
      :all ->
        # Run all profiling types
        time_profile = profile_function_time(function)
        memory_profile = profile_function_memory(function)
        reductions_profile = profile_function_reductions(function)
        
        # Combine results
        Map.merge(time_profile, memory_profile)
        |> Map.merge(reductions_profile)
    end
    
    # Add profile name and metadata
    result = Map.merge(profile_result, %{
      name: name,
      type: type,
      timestamp: DateTime.utc_now()
    })
    
    # Format output
    formatted_result = case output do
      :text ->
        format_profile_result(result, sort_by)
        
      :map ->
        result
    end
    
    # Log completion
    Logger.info("Function profiling completed", %{
      name: name,
      type: type
    })
    
    formatted_result
  end
  
  @doc """
  Profiles memory usage in the system.
  
  ## Parameters
  
  - `opts` - Profiling options
    - `:top_n` - Number of top processes to include (default: 10)
    - `:min_memory` - Minimum memory threshold in bytes (default: 0)
    - `:sort_by` - How to sort results (:memory, :reductions, :message_queue)
  
  ## Returns
  
  A memory profiling report.
  
  ## Examples
  
  ```elixir
  Profiler.profile_memory(top_n: 20, min_memory: 1_000_000)
  ```
  """
  def profile_memory(opts \\ []) do
    top_n = Keyword.get(opts, :top_n, 10)
    min_memory = Keyword.get(opts, :min_memory, 0)
    sort_by = Keyword.get(opts, :sort_by, :memory)
    
    Logger.info("Starting memory profiling")
    
    # Get memory usage by module
    module_memory = get_module_memory()
    
    # Get process memory
    process_memory = get_process_memory()
    
    # Get ETS tables memory
    ets_memory = get_ets_memory()
    
    # Get overall system memory
    system_memory = :erlang.memory()
    
    # Find top memory-using processes
    top_processes = get_top_processes(sort_by, top_n, min_memory)
    
    # Create report
    report = %{
      system: %{
        total: system_memory[:total],
        processes: system_memory[:processes],
        atom: system_memory[:atom],
        binary: system_memory[:binary],
        code: system_memory[:code],
        ets: system_memory[:ets]
      },
      modules: module_memory,
      top_processes: top_processes,
      ets_tables: ets_memory,
      timestamp: DateTime.utc_now()
    }
    
    Logger.info("Memory profiling completed")
    
    report
  end
  
  @doc """
  Profiles process activity in the system.
  
  ## Parameters
  
  - `duration` - Duration to monitor in milliseconds (default: 5000)
  - `opts` - Profiling options
    - `:top_n` - Number of top processes to include (default: 10)
    - `:poll_interval` - Interval between samples in milliseconds (default: 100)
    - `:sort_by` - How to sort results (:reductions, :memory, :message_queue)
  
  ## Returns
  
  A process activity profiling report.
  
  ## Examples
  
  ```elixir
  Profiler.profile_processes(10_000, poll_interval: 500, sort_by: :reductions)
  ```
  """
  def profile_processes(duration \\ 5000, opts \\ []) do
    top_n = Keyword.get(opts, :top_n, 10)
    poll_interval = Keyword.get(opts, :poll_interval, 100)
    sort_by = Keyword.get(opts, :sort_by, :reductions)
    
    Logger.info("Starting process profiling", %{
      duration_ms: duration,
      poll_interval: poll_interval
    })
    
    # Take initial sample
    initial_sample = take_process_sample()
    
    # Sleep for first interval
    Process.sleep(poll_interval)
    
    # Start collecting samples
    {samples, processes} = collect_process_samples(
      duration - poll_interval,
      poll_interval,
      [initial_sample],
      %{}
    )
    
    # Analyze samples
    process_activity = analyze_process_samples(samples, processes, sort_by, top_n)
    
    # Create report
    report = %{
      duration_ms: duration,
      samples: length(samples),
      poll_interval_ms: poll_interval,
      total_processes: map_size(processes),
      top_processes: process_activity,
      timestamp: DateTime.utc_now()
    }
    
    Logger.info("Process profiling completed", %{
      samples: length(samples),
      processes: map_size(processes)
    })
    
    report
  end
  
  @doc """
  Profiles message passing in the system.
  
  ## Parameters
  
  - `duration` - Duration to monitor in milliseconds (default: 5000)
  - `opts` - Profiling options
    - `:top_n` - Number of top processes to include (default: 10)
    - `:trace_ratio` - Ratio of messages to trace (0.0-1.0, default: 0.01)
  
  ## Returns
  
  A message passing profiling report.
  
  ## Examples
  
  ```elixir
  Profiler.profile_messages(10_000, trace_ratio: 0.05)
  ```
  """
  def profile_messages(duration \\ 5000, opts \\ []) do
    top_n = Keyword.get(opts, :top_n, 10)
    trace_ratio = Keyword.get(opts, :trace_ratio, 0.01)
    
    Logger.info("Starting message profiling", %{
      duration_ms: duration,
      trace_ratio: trace_ratio
    })
    
    # Create a tracer process
    {:ok, tracer_pid} = MessageTracer.start_link(trace_ratio)
    
    # Turn on tracing
    :erlang.trace(:all, true, [:send, :receive, {:tracer, tracer_pid}])
    
    # Wait for duration
    Process.sleep(duration)
    
    # Turn off tracing
    :erlang.trace(:all, false, [:send, :receive])
    
    # Get results
    trace_results = MessageTracer.get_results(tracer_pid)
    
    # Analyze message patterns
    message_patterns = analyze_message_patterns(trace_results, top_n)
    
    # Create report
    report = %{
      duration_ms: duration,
      trace_ratio: trace_ratio,
      total_messages: trace_results.total_messages,
      message_patterns: message_patterns,
      top_senders: trace_results.top_senders,
      top_receivers: trace_results.top_receivers,
      timestamp: DateTime.utc_now()
    }
    
    Logger.info("Message profiling completed", %{
      total_messages: trace_results.total_messages
    })
    
    report
  end
  
  @doc """
  Continuously monitors system health and reports anomalies.
  
  ## Parameters
  
  - `duration` - Duration to monitor in milliseconds (default: 60000)
  - `opts` - Monitoring options
    - `:poll_interval` - Interval between checks in milliseconds (default: 1000)
    - `:memory_threshold` - Memory growth threshold percentage (default: 10.0)
    - `:process_threshold` - Process growth threshold percentage (default: 20.0)
    - `:message_queue_threshold` - Message queue threshold (default: 1000)
  
  ## Returns
  
  A system health monitoring report.
  
  ## Examples
  
  ```elixir
  Profiler.monitor_health(3_600_000, poll_interval: 5000)
  ```
  """
  def monitor_health(duration \\ 60000, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 1000)
    memory_threshold = Keyword.get(opts, :memory_threshold, 10.0)
    process_threshold = Keyword.get(opts, :process_threshold, 20.0)
    message_queue_threshold = Keyword.get(opts, :message_queue_threshold, 1000)
    
    Logger.info("Starting health monitoring", %{
      duration_ms: duration,
      poll_interval: poll_interval
    })
    
    # Take initial sample
    initial_sample = %{
      memory: :erlang.memory(),
      process_count: :erlang.system_info(:process_count),
      timestamp: System.monotonic_time(:millisecond)
    }
    
    # Initialize state
    state = %{
      start_time: System.monotonic_time(:millisecond),
      samples: [initial_sample],
      anomalies: [],
      peak_memory: initial_sample.memory[:total],
      peak_processes: initial_sample.process_count
    }
    
    # Run monitoring loop
    final_state = monitor_loop(
      duration,
      poll_interval,
      state,
      memory_threshold,
      process_threshold,
      message_queue_threshold
    )
    
    # Calculate statistics
    samples = Enum.reverse(final_state.samples)
    memory_series = Enum.map(samples, & &1.memory[:total])
    process_series = Enum.map(samples, & &1.process_count)
    
    avg_memory = Enum.sum(memory_series) / length(memory_series)
    avg_processes = Enum.sum(process_series) / length(process_series)
    
    memory_growth_rate = if length(samples) > 1 do
      (List.last(memory_series) - hd(memory_series)) / hd(memory_series) * 100
    else
      0.0
    end
    
    process_growth_rate = if length(samples) > 1 do
      (List.last(process_series) - hd(process_series)) / hd(process_series) * 100
    else
      0.0
    end
    
    # Create report
    report = %{
      duration_ms: duration,
      samples: length(samples),
      poll_interval_ms: poll_interval,
      peak_memory: final_state.peak_memory,
      peak_processes: final_state.peak_processes,
      avg_memory: avg_memory,
      avg_processes: avg_processes,
      memory_growth_rate: memory_growth_rate,
      process_growth_rate: process_growth_rate,
      anomalies: Enum.reverse(final_state.anomalies),
      timestamp: DateTime.utc_now()
    }
    
    Logger.info("Health monitoring completed", %{
      samples: length(samples),
      anomalies: length(final_state.anomalies)
    })
    
    report
  end
  
  # Private helpers for function profiling
  
  defp profile_function_time(function) do
    # Start time profiling
    :eprof.start()
    :eprof.start_profiling([self()])
    
    # Execute function
    result = function.()
    
    # Stop profiling
    :eprof.stop_profiling()
    
    # Analyze and format results
    # Using a reference process to avoid printing to terminal
    analyze_pid = spawn(fn -> receive do :done -> :ok end end)
    :eprof.analyze(:total, {:procs, analyze_pid})
    
    # Parse the results
    total_time = :eprof.total_time()
    
    # Get the analysis data from the profiler
    analysis = :eprof.get_procs(analyze_pid, total_time)
    
    # Clean up
    :eprof.stop()
    send(analyze_pid, :done)
    
    # Format results
    formatted_analysis = format_eprof_results(analysis)
    
    %{
      result: result,
      profile_type: :time,
      total_time_us: div(total_time, 1000), # convert from microseconds
      function_calls: formatted_analysis
    }
  end
  
  defp profile_function_memory(function) do
    # Get memory before
    memory_before = :erlang.memory()
    
    # Execute function
    result = function.()
    
    # Get memory after
    memory_after = :erlang.memory()
    
    # Calculate differences
    memory_diff = Enum.map(memory_before, fn {type, before_val} ->
      after_val = memory_after[type]
      diff = after_val - before_val
      {type, diff}
    end)
    |> Map.new()
    
    # Format results
    %{
      result: result,
      profile_type: :memory,
      memory_change: memory_diff,
      memory_before: memory_before,
      memory_after: memory_after
    }
  end
  
  defp profile_function_reductions(function) do
    # Get reductions before
    {:reductions, reductions_before} = Process.info(self(), :reductions)
    
    # Execute function
    result = function.()
    
    # Get reductions after
    {:reductions, reductions_after} = Process.info(self(), :reductions)
    
    # Calculate difference
    reductions = reductions_after - reductions_before
    
    # Format results
    %{
      result: result,
      profile_type: :reductions,
      reductions: reductions
    }
  end
  
  defp format_eprof_results(analysis) do
    # Extract function call data
    Enum.map(analysis, fn {pid, {_process_type, _total_calls, _total_time, functions}} ->
      # Format pid
      pid_str = inspect(pid)
      
      # Format functions
      formatted_functions = Enum.map(functions, fn {{module, function, arity}, {count, time}} ->
        %{
          module: module,
          function: function,
          arity: arity,
          calls: count,
          time_us: div(time, 1000),
          percent: 0 # Will be calculated later
        }
      end)
      
      {pid_str, formatted_functions}
    end)
    |> Map.new()
  end
  
  # Private helpers for memory profiling
  
  defp get_module_memory do
    # This is an approximation as Erlang doesn't provide direct module memory usage
    :code.all_loaded()
    |> Enum.map(fn {module, binary} ->
      # Estimate module memory from code size
      size = byte_size(binary)
      {module, size}
    end)
    |> Enum.sort_by(fn {_, size} -> size end, :desc)
    |> Map.new()
  end
  
  defp get_process_memory do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:memory, :registered_name]) do
        [{:memory, memory}, {:registered_name, name}] ->
          {pid, %{memory: memory, name: name}}
          
        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end
  
  defp get_ets_memory do
    :ets.all()
    |> Enum.map(fn table ->
      try do
        info = :ets.info(table)
        {table, %{
          memory: info[:memory] * :erlang.system_info(:wordsize),
          size: info[:size],
          type: info[:type],
          owner: info[:owner]
        }}
      rescue
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end
  
  defp get_top_processes(sort_by, top_n, min_memory) do
    # Get all processes
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [
        :memory,
        :reductions,
        :message_queue_len,
        :registered_name,
        :current_function,
        :initial_call
      ]) do
        [memory: mem, reductions: reds, message_queue_len: queue_len, registered_name: name, current_function: current, initial_call: initial] ->
          {pid, %{
            pid: pid,
            memory: mem,
            reductions: reds,
            message_queue_len: queue_len,
            name: if(name == [], do: nil, else: name),
            current_function: current,
            initial_call: initial
          }}
          
        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn {_, info} -> info.memory >= min_memory end)
    
    # Sort by the selected criterion
    sort_field = case sort_by do
      :memory -> fn {_, info} -> info.memory end
      :reductions -> fn {_, info} -> info.reductions end
      :message_queue -> fn {_, info} -> info.message_queue_len end
    end
    
    # Get top N processes
    Enum.sort_by(top_n, sort_field, :desc)
    |> Enum.take(top_n)
    |> Enum.map(fn {_, info} -> info end)
  end
  
  # Private helpers for process profiling
  
  defp take_process_sample do
    # Get all processes info
    processes = Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:reductions, :memory, :message_queue_len]) do
        [reductions: reds, memory: mem, message_queue_len: queue_len] ->
          {pid, %{reductions: reds, memory: mem, message_queue_len: queue_len}}
          
        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
    
    # Return sample with timestamp
    %{
      timestamp: System.monotonic_time(:millisecond),
      processes: processes
    }
  end
  
  defp collect_process_samples(remaining_time, interval, samples, processes) do
    if remaining_time <= 0 do
      # Time's up, return collected samples and process info
      {samples, processes}
    else
      # Take a new sample
      sample = take_process_sample()
      
      # Update processes info with new sample
      updated_processes = Enum.reduce(sample.processes, processes, fn {pid, info}, acc ->
        process_info = Map.get(acc, pid, %{
          samples: 0,
          total_reductions: 0,
          max_memory: 0,
          max_queue_len: 0
        })
        
        # Update process stats
        updated_info = %{
          samples: process_info.samples + 1,
          total_reductions: process_info.total_reductions + info.reductions,
          max_memory: max(process_info.max_memory, info.memory),
          max_queue_len: max(process_info.max_queue_len, info.message_queue_len)
        }
        
        Map.put(acc, pid, updated_info)
      end)
      
      # Sleep for interval
      Process.sleep(interval)
      
      # Continue collecting
      collect_process_samples(
        remaining_time - interval,
        interval,
        [sample | samples],
        updated_processes
      )
    end
  end
  
  defp analyze_process_samples(samples, processes, sort_by, top_n) do
    # Calculate reduction rates
    processes_with_rates = Enum.map(processes, fn {pid, info} ->
      # Get process info
      process_name = case Process.info(pid, :registered_name) do
        {:registered_name, []} -> nil
        {:registered_name, name} -> name
        _ -> nil
      end
      
      # Calculate average reduction rate
      avg_reductions = if info.samples > 0 do
        info.total_reductions / info.samples
      else
        0
      end
      
      # Get final info from last sample if process still exists
      last_sample = hd(samples)
      current_info = Map.get(last_sample.processes, pid)
      
      {pid, Map.merge(info, %{
        pid: pid,
        name: process_name,
        avg_reductions: avg_reductions,
        current: current_info
      })}
    end)
    
    # Sort by the selected criterion
    sort_field = case sort_by do
      :reductions -> fn {_, info} -> info.avg_reductions end
      :memory -> fn {_, info} -> info.max_memory end
      :message_queue -> fn {_, info} -> info.max_queue_len end
    end
    
    # Get top N processes
    Enum.sort_by(processes_with_rates, sort_field, :desc)
    |> Enum.take(top_n)
    |> Enum.map(fn {_, info} -> info end)
  end
  
  # Private helpers for message profiling
  
  defp analyze_message_patterns(trace_results, top_n) do
    # Calculate common message patterns
    patterns = Enum.reduce(trace_results.messages, %{}, fn msg, acc ->
      # Extract pattern from message
      pattern = extract_message_pattern(msg.message)
      
      # Update pattern count
      Map.update(acc, pattern, 1, &(&1 + 1))
    end)
    
    # Sort patterns by frequency
    Enum.sort_by(patterns, fn {_, count} -> count end, :desc)
    |> Enum.take(top_n)
    |> Enum.map(fn {pattern, count} ->
      %{
        pattern: pattern,
        count: count,
        percentage: count / trace_results.total_messages * 100
      }
    end)
  end
  
  defp extract_message_pattern(message) do
    # Pattern extraction logic
    # This is a simplified version, you can make it more sophisticated
    cond do
      is_tuple(message) and tuple_size(message) > 0 ->
        # For tuples, keep the tag but replace values with placeholders
        tag = elem(message, 0)
        arity = tuple_size(message) - 1
        "#{tag}/#{arity}"
        
      is_list(message) ->
        "list/#{length(message)}"
        
      is_map(message) ->
        "map/#{map_size(message)}"
        
      is_binary(message) ->
        "binary/#{byte_size(message)}"
        
      true ->
        "#{inspect(message)}"
    end
  end
  
  # Private helpers for health monitoring
  
  defp monitor_loop(remaining_time, interval, state, memory_threshold, process_threshold, message_queue_threshold) do
    if remaining_time <= 0 do
      # Time's up, return state
      state
    else
      # Take a new sample
      sample = %{
        memory: :erlang.memory(),
        process_count: :erlang.system_info(:process_count),
        timestamp: System.monotonic_time(:millisecond)
      }
      
      # Check for anomalies
      {new_state, new_anomalies} = check_for_anomalies(
        state,
        sample,
        memory_threshold,
        process_threshold,
        message_queue_threshold
      )
      
      # Log anomalies
      if new_anomalies != [] do
        Enum.each(new_anomalies, fn anomaly ->
          Logger.warning("Health anomaly detected", %{
            type: anomaly.type,
            value: anomaly.value,
            threshold: anomaly.threshold
          })
        end)
      end
      
      # Sleep for interval
      Process.sleep(interval)
      
      # Continue monitoring
      monitor_loop(
        remaining_time - interval,
        interval,
        new_state,
        memory_threshold,
        process_threshold,
        message_queue_threshold
      )
    end
  end
  
  defp check_for_anomalies(state, sample, memory_threshold, process_threshold, message_queue_threshold) do
    # Initialize new anomalies list
    new_anomalies = []
    
    # Check memory growth
    new_anomalies = if length(state.samples) >= 2 do
      prev_sample = hd(state.samples)
      prev_memory = prev_sample.memory[:total]
      current_memory = sample.memory[:total]
      
      memory_growth_percent = (current_memory - prev_memory) / prev_memory * 100
      
      if memory_growth_percent > memory_threshold do
        [%{
          type: :memory_growth,
          value: memory_growth_percent,
          threshold: memory_threshold,
          timestamp: sample.timestamp
        } | new_anomalies]
      else
        new_anomalies
      end
    else
      new_anomalies
    end
    
    # Check process growth
    new_anomalies = if length(state.samples) >= 2 do
      prev_sample = hd(state.samples)
      prev_processes = prev_sample.process_count
      current_processes = sample.process_count
      
      process_growth_percent = (current_processes - prev_processes) / prev_processes * 100
      
      if process_growth_percent > process_threshold do
        [%{
          type: :process_growth,
          value: process_growth_percent,
          threshold: process_threshold,
          timestamp: sample.timestamp
        } | new_anomalies]
      else
        new_anomalies
      end
    else
      new_anomalies
    end
    
    # Check message queues
    new_anomalies = check_message_queues(new_anomalies, message_queue_threshold, sample.timestamp)
    
    # Update state
    new_state = %{
      state |
      samples: [sample | state.samples],
      anomalies: new_anomalies ++ state.anomalies,
      peak_memory: max(state.peak_memory, sample.memory[:total]),
      peak_processes: max(state.peak_processes, sample.process_count)
    }
    
    {new_state, new_anomalies}
  end
  
  defp check_message_queues(anomalies, threshold, timestamp) do
    # Find processes with long message queues
    long_queues = Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:message_queue_len, :registered_name]) do
        [{:message_queue_len, len}, {:registered_name, name}] when len > threshold ->
          %{
            pid: pid,
            queue_length: len,
            name: if(name == [], do: nil, else: name)
          }
          
        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    # If there are processes with long queues, add an anomaly
    if long_queues != [] do
      [%{
        type: :message_queue,
        value: long_queues,
        threshold: threshold,
        timestamp: timestamp
      } | anomalies]
    else
      anomalies
    end
  end
  
  # Formatting helpers
  
  defp format_profile_result(result, sort_by) do
    case result.type do
      :time ->
        format_time_profile(result, sort_by)
        
      :memory ->
        format_memory_profile(result)
        
      :reductions ->
        format_reductions_profile(result)
        
      :all ->
        format_combined_profile(result, sort_by)
    end
  end
  
  defp format_time_profile(result, sort_by) do
    total_time_ms = result.total_time_us / 1000
    
    # Format each process
    process_output = Enum.map(result.function_calls, fn {pid, functions} ->
      # Sort functions
      sorted_functions = case sort_by do
        :time ->
          Enum.sort_by(functions, & &1.time_us, :desc)
          
        :calls ->
          Enum.sort_by(functions, & &1.calls, :desc)
      end
      
      # Format functions
      function_lines = Enum.map(sorted_functions, fn func ->
        time_ms = func.time_us / 1000
        percent = func.time_us / result.total_time_us * 100
        
        "  #{func.module}.#{func.function}/#{func.arity}: #{func.calls} calls, #{Float.round(time_ms, 3)} ms (#{Float.round(percent, 2)}%)"
      end)
      |> Enum.join("\n")
      
      "Process #{pid}:\n#{function_lines}"
    end)
    |> Enum.join("\n\n")
    
    """
    Time Profile: #{result.name}
    Total time: #{Float.round(total_time_ms, 3)} ms
    
    #{process_output}
    """
  end
  
  defp format_memory_profile(result) do
    # Format memory changes
    memory_lines = Enum.map(result.memory_change, fn {type, diff} ->
      diff_mb = diff / (1024 * 1024)
      sign = if diff >= 0, do: "+", else: ""
      "  #{type}: #{sign}#{Float.round(diff_mb, 3)} MB"
    end)
    |> Enum.join("\n")
    
    """
    Memory Profile: #{result.name}
    Memory Changes:
    #{memory_lines}
    """
  end
  
  defp format_reductions_profile(result) do
    """
    Reductions Profile: #{result.name}
    Total reductions: #{result.reductions}
    """
  end
  
  defp format_combined_profile(result, sort_by) do
    # Combined formatting
    """
    #{format_time_profile(result, sort_by)}
    
    #{format_memory_profile(result)}
    
    #{format_reductions_profile(result)}
    """
  end
end

# Helper module for message tracing
defmodule MessageTracer do
  use GenServer
  
  def start_link(trace_ratio) do
    GenServer.start_link(__MODULE__, trace_ratio)
  end
  
  def get_results(pid) do
    GenServer.call(pid, :get_results)
  end
  
  @impl true
  def init(trace_ratio) do
    {:ok, %{
      trace_ratio: trace_ratio,
      messages: [],
      total_messages: 0,
      senders: %{},
      receivers: %{}
    }}
  end
  
  @impl true
  def handle_info({:trace, from_pid, :send, message, to_pid}, state) do
    # Increment total message count
    state = %{state | total_messages: state.total_messages + 1}
    
    # Apply sampling based on trace ratio
    if :rand.uniform() <= state.trace_ratio do
      # Record message
      state = %{state | 
        messages: [%{
          from: from_pid,
          to: to_pid,
          message: message,
          timestamp: System.monotonic_time(:millisecond)
        } | state.messages]
      }
      
      # Update sender stats
      state = update_in(state.senders, fn senders ->
        Map.update(senders, from_pid, 1, &(&1 + 1))
      end)
      
      # Update receiver stats
      state = update_in(state.receivers, fn receivers ->
        Map.update(receivers, to_pid, 1, &(&1 + 1))
      end)
      
      {:noreply, state}
    else
      # Skip recording
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:trace, pid, :receive, message}, state) do
    # Already tracking in send traces
    {:noreply, state}
  end
  
  @impl true
  def handle_info(_msg, state) do
    # Ignore other messages
    {:noreply, state}
  end
  
  @impl true
  def handle_call(:get_results, _from, state) do
    # Get top senders
    top_senders = Enum.sort_by(state.senders, fn {_, count} -> count end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {pid, count} ->
      %{pid: pid, count: count, percentage: count / state.total_messages * 100}
    end)
    
    # Get top receivers
    top_receivers = Enum.sort_by(state.receivers, fn {_, count} -> count end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {pid, count} ->
      %{pid: pid, count: count, percentage: count / state.total_messages * 100}
    end)
    
    # Prepare results
    results = %{
      messages: state.messages,
      total_messages: state.total_messages,
      top_senders: top_senders,
      top_receivers: top_receivers
    }
    
    {:reply, results, state}
  end
end