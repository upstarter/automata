defmodule Automata.Infrastructure.Resilience.Logger do
  @moduledoc """
  Enhanced logging system for the Automata system.
  
  This module enhances the standard Elixir Logger with:
  - Standardized structured logging
  - Context and correlation IDs for request tracing
  - Integration with telemetry for metrics
  - Log level filtering based on configuration
  - Auto-tagging of log messages based on context
  """
  
  require Logger
  alias Automata.Infrastructure.Resilience.Telemetry

  # Define log levels
  @log_levels [:debug, :info, :warning, :error, :critical]
  
  @doc """
  Logs a debug message with structured metadata.
  """
  def debug(message, metadata \\ %{}) do
    log(:debug, message, metadata)
  end
  
  @doc """
  Logs an info message with structured metadata.
  """
  def info(message, metadata \\ %{}) do
    log(:info, message, metadata)
  end
  
  @doc """
  Logs a warning message with structured metadata.
  """
  def warning(message, metadata \\ %{}) do
    log(:warning, message, metadata)
  end
  
  @doc """
  Logs an error message with structured metadata.
  """
  def error(message, metadata \\ %{}) do
    log(:error, message, metadata)
  end
  
  @doc """
  Logs a critical message with structured metadata.
  """
  def critical(message, metadata \\ %{}) do
    log(:error, "[CRITICAL] " <> message, Map.put(metadata, :level, :critical))
  end
  
  @doc """
  Logs a message with the given level and metadata.
  
  This is the main logging function that:
  1. Enhances metadata with context
  2. Emits telemetry events for metrics collection
  3. Logs the message via standard Logger
  """
  def log(level, message, metadata \\ %{}) when level in @log_levels do
    # Enhance metadata with context
    enhanced_metadata = enhance_metadata(metadata)
    
    # Convert level :warning to :warn for Logger compatibility
    elixir_level = if level == :warning, do: :warn, else: level
    
    # Generate unique log ID for reference
    log_id = Map.get(enhanced_metadata, :log_id, generate_log_id())
    
    # Prepare structured log data
    log_data = %{
      message: message,
      metadata: enhanced_metadata,
      level: level,
      timestamp: DateTime.utc_now(),
      log_id: log_id
    }
    
    # Emit telemetry event before logging
    Telemetry.execute([:automata, :log, level], %{count: 1}, log_data)
    
    # Convert metadata to Keyword list for Logger
    logger_metadata = for {key, value} <- enhanced_metadata, into: [] do
      {key, value}
    end
    
    # Log via standard Logger
    Logger.log(elixir_level, message, logger_metadata)
    
    # Return the log data for potential further processing
    log_data
  end
  
  @doc """
  Sets the current context for the process.
  Context will be included in all log messages from this process.
  """
  def set_context(context) when is_map(context) do
    Process.put(:automata_log_context, context)
  end
  
  @doc """
  Updates the current context for the process.
  """
  def update_context(context) when is_map(context) do
    current = Process.get(:automata_log_context, %{})
    Process.put(:automata_log_context, Map.merge(current, context))
  end
  
  @doc """
  Gets the current context for the process.
  """
  def get_context do
    Process.get(:automata_log_context, %{})
  end
  
  @doc """
  Clears the current context for the process.
  """
  def clear_context do
    Process.delete(:automata_log_context)
  end
  
  @doc """
  Sets a correlation ID for tracking related logs.
  """
  def set_correlation_id(correlation_id) do
    update_context(%{correlation_id: correlation_id})
  end
  
  @doc """
  Gets the current correlation ID.
  """
  def get_correlation_id do
    Map.get(get_context(), :correlation_id)
  end
  
  @doc """
  Wraps a function with context propagation.
  Copies the current context to the new process.
  """
  def with_context(func, additional_context \\ %{}) when is_function(func) do
    current_context = get_context()
    merged_context = Map.merge(current_context, additional_context)
    
    fn ->
      # Set context in the new process
      set_context(merged_context)
      # Execute the function
      result = func.()
      # Clear context to avoid memory leaks
      clear_context()
      result
    end
  end
  
  @doc """
  Wraps a function with a new correlation ID.
  """
  def with_correlation(func) when is_function(func) do
    correlation_id = generate_correlation_id()
    with_context(func, %{correlation_id: correlation_id})
  end
  
  @doc """
  Logs function execution time and result.
  
  Example:
      result = Logger.measure("database_query", fn -> 
        Database.query("SELECT * FROM users") 
      end)
  """
  def measure(operation_name, func, metadata \\ %{}) when is_function(func, 0) do
    start_time = System.monotonic_time(:microsecond)
    
    result = try do
      func.()
    rescue
      exception ->
        # Log exception
        stacktrace = __STACKTRACE__
        error(
          "Error in operation #{operation_name}: #{Exception.message(exception)}",
          Map.merge(metadata, %{
            operation: operation_name,
            error: true,
            exception: exception.__struct__,
            stacktrace: inspect(stacktrace)
          })
        )
        reraise exception, stacktrace
    end
    
    end_time = System.monotonic_time(:microsecond)
    duration_us = end_time - start_time
    duration_ms = duration_us / 1000.0
    
    # Log the operation result
    log_level = if Map.get(metadata, :silence, false), do: :debug, else: :info
    status = if is_tuple(result) and elem(result, 0) == :error, do: :error, else: :success
    
    log(log_level, 
      "Operation #{operation_name} completed in #{Float.round(duration_ms, 2)}ms",
      Map.merge(metadata, %{
        operation: operation_name,
        duration_ms: duration_ms,
        status: status
      })
    )
    
    # Emit telemetry event
    Telemetry.execute(
      [:automata, :operation, :duration],
      %{duration: duration_us},
      %{operation: operation_name, status: status}
    )
    
    result
  end
  
  # Private helpers
  
  defp enhance_metadata(metadata) do
    base_metadata = %{
      node: Node.self(),
      process: inspect(self()),
      module: get_calling_module(),
      log_id: generate_log_id(),
      pid: inspect(self()),
      timestamp: DateTime.utc_now()
    }
    
    # Add context from process dictionary
    context = get_context()
    
    # Merge all metadata, with explicit metadata taking precedence
    Map.merge(Map.merge(base_metadata, context), metadata)
  end
  
  defp get_calling_module do
    case Process.info(self(), :current_stacktrace) do
      {:current_stacktrace, [{_, _, _, _}, {_, _, _, _}, {module, _, _, _} | _]} ->
        module
      _ ->
        nil
    end
  end
  
  defp generate_log_id do
    node_name = Node.self() 
      |> Atom.to_string() 
      |> String.split("@") 
      |> List.first()
      
    "log-#{node_name}-#{System.system_time(:millisecond)}-#{:rand.uniform(1000000)}"
  end
  
  defp generate_correlation_id do
    "corr-#{System.system_time(:millisecond)}-#{:rand.uniform(1000000)}"
  end
end