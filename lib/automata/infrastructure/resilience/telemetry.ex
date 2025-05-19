defmodule Automata.Infrastructure.Resilience.Telemetry do
  @moduledoc """
  Telemetry integration for the Automata system.
  
  This module provides functions for:
  - Emitting telemetry events
  - Defining telemetry event handlers
  - Collecting and reporting system metrics
  """
  
  require Logger
  
  @doc """
  Executes a telemetry event with the given measurements and metadata.
  
  Example:
      Telemetry.execute([:automata, :http, :request], %{duration: 200}, %{path: "/api/status"})
  """
  def execute(event_name, measurements, metadata \\ %{}) when is_list(event_name) do
    # Add timestamp to measurements if not present
    measurements = Map.put_new(measurements, :system_time, System.system_time(:millisecond))
    
    # Add node name to metadata if not present
    node_name = Node.self()
    metadata = Map.put_new(metadata, :node, node_name)
    
    # Execute telemetry event
    :telemetry.execute(event_name, measurements, metadata)
    
    # Return event details for potential further processing
    %{
      event: event_name,
      measurements: measurements,
      metadata: metadata
    }
  end
  
  @doc """
  Attaches a handler to the specified telemetry events.
  
  Example:
      Telemetry.attach_handler(:http_request_handler, 
        [:automata, :http, :request], 
        fn event, measurements, metadata, config ->
          Logger.info("HTTP request to #{metadata.path} took #{measurements.duration}ms")
        end,
        %{threshold: 500}
      )
  """
  def attach_handler(handler_id, event_names, handler_function, config \\ %{}) 
    when is_atom(handler_id) and is_list(event_names) and is_function(handler_function, 4)
  do
    :telemetry.attach(handler_id, event_names, handler_function, config)
  end
  
  @doc """
  Detaches a previously attached telemetry handler.
  """
  def detach_handler(handler_id) when is_atom(handler_id) do
    :telemetry.detach(handler_id)
  end
  
  @doc """
  Span for tracing the execution of a function.
  """
  def span(span_name, function, metadata \\ %{}) when is_function(function, 0) do
    start_time = System.monotonic_time(:microsecond)
    start_event = [:automata, :span, :start]
    
    # Execute the start event
    execute(
      start_event,
      %{system_time: System.system_time()},
      Map.merge(%{span_name: span_name}, metadata)
    )
    
    # Execute the function
    try do
      result = function.()
      
      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time
      
      # Execute the stop event
      execute(
        [:automata, :span, :stop],
        %{duration: duration},
        Map.merge(%{span_name: span_name, status: :success}, metadata)
      )
      
      result
    rescue
      exception ->
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time
        
        # Execute the exception event
        execute(
          [:automata, :span, :exception],
          %{duration: duration},
          Map.merge(
            %{
              span_name: span_name,
              status: :error,
              error: Exception.message(exception),
              stacktrace: Exception.format_stacktrace(__STACKTRACE__)
            },
            metadata
          )
        )
        
        reraise exception, __STACKTRACE__
    end
  end
  
  @doc """
  Sets up default telemetry handlers for the Automata system.
  """
  def setup_default_handlers do
    # Handler for operation duration
    attach_handler(
      :operation_duration,
      [:automata, :operation, :duration],
      &handle_operation_duration/4
    )
    
    # Handler for log events
    attach_handler(
      :log_events,
      [:automata, :log, :debug, :automata, :log, :info, :automata, :log, :warning, :automata, :log, :error, :automata, :log, :critical],
      &handle_log_event/4
    )
    
    # Handler for circuit breaker events
    attach_handler(
      :circuit_breaker_state_change,
      [:automata, :circuit_breaker, :state_change],
      &handle_circuit_breaker_state_change/4
    )
    
    # Handler for automaton lifecycle events
    attach_handler(
      :automaton_lifecycle,
      [:automata, :automaton, :start, :automata, :automaton, :stop],
      &handle_automaton_lifecycle/4
    )
    
    # Handler for error events
    attach_handler(
      :error_events,
      [:automata, :error, :occurred],
      &handle_error_event/4
    )
    
    :ok
  end
  
  @doc """
  Reports current system metrics.
  """
  def report_system_metrics do
    # Collect memory statistics
    memory = :erlang.memory()
    
    # Collect process statistics
    process_count = :erlang.system_info(:process_count)
    
    # Collect scheduler statistics
    scheduler_count = :erlang.system_info(:schedulers)
    
    # Execute telemetry event with system metrics
    execute(
      [:automata, :system, :metrics],
      %{
        total_memory: memory[:total],
        process_memory: memory[:processes],
        atom_memory: memory[:atom],
        binary_memory: memory[:binary],
        ets_memory: memory[:ets],
        process_count: process_count,
        scheduler_count: scheduler_count
      }
    )
  end
  
  # Handler functions
  
  defp handle_operation_duration(_event, %{duration: duration}, %{operation: operation} = metadata, _config) do
    # Convert microseconds to milliseconds for readability
    duration_ms = duration / 1000.0
    
    # Log slow operations (over 1 second)
    if duration_ms > 1000 do
      Logger.warning("Slow operation detected: #{operation} took #{Float.round(duration_ms, 2)}ms", 
        Map.take(metadata, [:operation, :status, :correlation_id])
      )
    end
  end
  
  defp handle_log_event(_event, _measurements, %{level: :critical} = metadata, _config) do
    # For critical logs, we might want to send alerts
    send_critical_alert(metadata.message, metadata)
  end
  
  defp handle_log_event(_event, _measurements, _metadata, _config) do
    # We could implement persistence or other processing here
    :ok
  end
  
  defp handle_circuit_breaker_state_change(_event, _measurements, %{from: from, to: to, name: name, reason: reason}, _config) do
    case to do
      :open -> 
        Logger.warning("Circuit '#{name}' changed from #{from} to #{to}: #{reason}")
      _ -> 
        Logger.info("Circuit '#{name}' changed from #{from} to #{to}: #{reason}")
    end
  end
  
  defp handle_automaton_lifecycle([:automata, :automaton, :start], _measurements, metadata, _config) do
    Logger.info("Automaton started: #{metadata.id}", Map.take(metadata, [:id, :type, :version]))
  end
  
  defp handle_automaton_lifecycle([:automata, :automaton, :stop], _measurements, metadata, _config) do
    Logger.info("Automaton stopped: #{metadata.id}", Map.take(metadata, [:id, :type, :reason]))
  end
  
  defp handle_error_event(_event, _measurements, metadata, _config) do
    Logger.error("Error occurred: #{metadata.error_type} - #{metadata.message}", 
      Map.take(metadata, [:error_id, :error_type, :node, :module])
    )
  end
  
  # Internal functions
  
  defp send_critical_alert(message, metadata) do
    # In a real implementation, this could send alerts via various channels
    Logger.error("CRITICAL ALERT: #{message}", metadata)
    
    # We could also use an event bus to notify subscribers
    if Process.whereis(Automata.Infrastructure.Event.EventBus) do
      Automata.Infrastructure.Event.EventBus.publish(%{
        type: :critical_alert,
        payload: %{
          message: message,
          metadata: metadata
        },
        metadata: %{
          timestamp: DateTime.utc_now(),
          source: __MODULE__
        }
      })
    end
  end
end