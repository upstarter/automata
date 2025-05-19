defmodule Automata.Infrastructure.Resilience.Error do
  @moduledoc """
  Error handling framework for the Automata system.
  
  This module provides standardized error types, propagation mechanisms,
  and utilities for handling errors consistently throughout the system.
  """
  
  @doc """
  Creates a standardized error struct with additional context information.
  """
  def new(type, message, metadata \\ %{}) do
    %{
      type: type,
      message: message,
      metadata: Map.merge(default_metadata(), metadata),
      stacktrace: get_stacktrace(),
      id: generate_error_id()
    }
  end
  
  @doc """
  Converts an exception into a standardized error.
  """
  def from_exception(exception, metadata \\ %{}) when is_exception(exception) do
    type = exception.__struct__
    message = Exception.message(exception)
    stacktrace = get_stacktrace()
    
    %{
      type: type,
      message: message,
      metadata: Map.merge(default_metadata(), metadata),
      stacktrace: stacktrace,
      id: generate_error_id()
    }
  end
  
  @doc """
  Maps a :error tuple into a standardized error.
  """
  def wrap({:error, reason}, metadata \\ %{}) do
    error = case reason do
      %{__exception__: true} = exception ->
        from_exception(exception, metadata)
        
      error when is_map(error) and Map.has_key?(error, :type) and Map.has_key?(error, :message) ->
        # Already in our error format, just add/update metadata
        Map.update!(error, :metadata, &Map.merge(&1, metadata))
        
      other ->
        new(:unexpected_error, "Unexpected error: #{inspect(other)}", metadata)
    end
    
    {:error, error}
  end
  
  @doc """
  Creates a function that will wrap errors returned by the given function.
  Useful for mapping errors from external APIs into our standard format.
  """
  def wrap_errors(fun, metadata \\ %{}) when is_function(fun) do
    fn args ->
      try do
        case fun.(args) do
          {:ok, result} -> {:ok, result}
          {:error, _} = error -> wrap(error, metadata)
          other -> {:ok, other}  # Not an error tuple, return as is
        end
      rescue
        exception ->
          {:error, from_exception(exception, metadata)}
      end
    end
  end
  
  @doc """
  Logs an error using the appropriate level and sends to error tracking.
  """
  def log(error, level \\ :error, additional_metadata \\ %{}) do
    # Combine metadata
    metadata = Map.merge(error.metadata, additional_metadata)
    
    # Log with appropriate level
    case level do
      :debug -> Logger.debug(error.message, metadata)
      :info -> Logger.info(error.message, metadata)
      :warning -> Logger.warning(error.message, metadata)
      :error -> Logger.error(error.message, metadata)
    end
    
    # Send to error tracking
    Automata.Infrastructure.Resilience.ErrorTracker.track(error)
    
    # Return the error
    error
  end
  
  @doc """
  Returns true if the error is of the specified type.
  """
  def is_type?(error, type) do
    error.type == type
  end
  
  @doc """
  Returns a human-readable string representation of the error.
  """
  def to_string(error) do
    """
    Error[#{error.id}]: #{inspect(error.type)} - #{error.message}
    Origin: #{error.metadata.node} at #{error.metadata.timestamp}
    #{format_stacktrace(error.stacktrace)}
    """
  end
  
  # Private helpers
  
  defp default_metadata do
    %{
      node: Node.self(),
      timestamp: DateTime.utc_now(),
      process: self(),
      module: get_calling_module()
    }
  end
  
  defp get_stacktrace do
    case Process.info(self(), :current_stacktrace) do
      {:current_stacktrace, stacktrace} -> 
        # Skip internal frames
        Enum.drop(stacktrace, 3)
      _ -> 
        []
    end
  end
  
  defp get_calling_module do
    case get_stacktrace() do
      [{module, _, _, _} | _] -> module
      _ -> nil
    end
  end
  
  defp generate_error_id do
    node_name = Node.self() 
      |> Atom.to_string() 
      |> String.split("@") 
      |> List.first()
      
    "err-#{node_name}-#{System.system_time(:millisecond)}-#{:rand.uniform(1000000)}"
  end
  
  defp format_stacktrace(stacktrace) do
    stacktrace
    |> Exception.format_stacktrace()
    |> String.split("\n")
    |> Enum.map(fn line -> "  #{line}" end)
    |> Enum.join("\n")
  end
end

defmodule Automata.Infrastructure.Resilience.ErrorTracker do
  @moduledoc """
  Tracks errors across the system for analysis and reporting.
  """
  use GenServer
  require Logger
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Tracks an error for future analysis.
  """
  def track(error) do
    GenServer.cast(__MODULE__, {:track, error})
  end
  
  @doc """
  Gets an error by ID.
  """
  def get(error_id) do
    GenServer.call(__MODULE__, {:get, error_id})
  end
  
  @doc """
  Gets errors matching the given criteria.
  """
  def find(criteria \\ %{}) do
    GenServer.call(__MODULE__, {:find, criteria})
  end
  
  @doc """
  Gets summary statistics about tracked errors.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Clears all error history.
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("Starting Error Tracker")
    
    # Initialize ETS table to store errors
    :ets.new(:automata_errors, [:set, :protected, :named_table])
    
    # Initialize state
    state = %{
      errors: %{},  # Map of error_id -> error
      by_type: %{}, # Map of type -> [error_id]
      by_node: %{}, # Map of node -> [error_id]
      by_module: %{}, # Map of module -> [error_id]
      count: 0,
      last_cleared: DateTime.utc_now()
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:track, error}, state) do
    # Store error in ETS
    :ets.insert(:automata_errors, {error.id, error})
    
    # Update indexes
    type = error.type
    node = error.metadata.node
    module = error.metadata.module
    
    by_type = Map.update(state.by_type, type, [error.id], fn ids -> [error.id | ids] end)
    by_node = Map.update(state.by_node, node, [error.id], fn ids -> [error.id | ids] end)
    by_module = Map.update(state.by_module, module, [error.id], fn ids -> [error.id | ids] end)
    
    # Update state
    new_state = %{state | 
      errors: Map.put(state.errors, error.id, error),
      by_type: by_type,
      by_node: by_node,
      by_module: by_module,
      count: state.count + 1
    }
    
    # Publish error event
    publish_error_event(error)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:get, error_id}, _from, state) do
    case :ets.lookup(:automata_errors, error_id) do
      [{^error_id, error}] ->
        {:reply, {:ok, error}, state}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:find, criteria}, _from, state) do
    # Filter errors based on criteria
    errors = find_errors(state, criteria)
    {:reply, {:ok, errors}, state}
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total: state.count,
      by_type: map_size_by_key(state.by_type),
      by_node: map_size_by_key(state.by_node),
      by_module: map_size_by_key(state.by_module),
      last_cleared: state.last_cleared
    }
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_call(:clear, _from, _state) do
    # Clear ETS table
    :ets.delete_all_objects(:automata_errors)
    
    # Reset state
    new_state = %{
      errors: %{},
      by_type: %{},
      by_node: %{},
      by_module: %{},
      count: 0,
      last_cleared: DateTime.utc_now()
    }
    
    {:reply, :ok, new_state}
  end
  
  # Private helpers
  
  defp find_errors(state, criteria) do
    cond do
      Map.has_key?(criteria, :id) ->
        id = Map.get(criteria, :id)
        case Map.get(state.errors, id) do
          nil -> []
          error -> [error]
        end
        
      Map.has_key?(criteria, :type) ->
        type = Map.get(criteria, :type)
        get_errors_by_ids(state, Map.get(state.by_type, type, []))
        
      Map.has_key?(criteria, :node) ->
        node = Map.get(criteria, :node)
        get_errors_by_ids(state, Map.get(state.by_node, node, []))
        
      Map.has_key?(criteria, :module) ->
        module = Map.get(criteria, :module)
        get_errors_by_ids(state, Map.get(state.by_module, module, []))
        
      true ->
        Map.values(state.errors)
    end
  end
  
  defp get_errors_by_ids(state, ids) do
    ids
    |> Enum.map(fn id -> Map.get(state.errors, id) end)
    |> Enum.reject(&is_nil/1)
  end
  
  defp map_size_by_key(map) do
    map
    |> Enum.map(fn {key, values} -> {key, length(values)} end)
    |> Map.new()
  end
  
  defp publish_error_event(error) do
    if Process.whereis(Automata.Infrastructure.Event.EventBus) do
      event = %{
        type: :error_occurred,
        payload: %{
          error_id: error.id,
          error_type: error.type,
          message: error.message,
          node: error.metadata.node,
          module: error.metadata.module
        },
        metadata: %{
          timestamp: DateTime.utc_now(),
          source: __MODULE__
        }
      }
      
      Automata.Infrastructure.Event.EventBus.publish(event)
    end
  end
end

defmodule Automata.Infrastructure.Resilience.ErrorEvent do
  @moduledoc """
  Error-related events for the system.
  """
  
  @doc """
  Creates an error_occurred event.
  """
  def error_occurred(error) do
    %{
      type: :error_occurred,
      payload: %{
        error_id: error.id,
        error_type: error.type,
        message: error.message,
        node: error.metadata.node,
        module: error.metadata.module
      },
      metadata: %{
        timestamp: DateTime.utc_now(),
        source: __MODULE__
      }
    }
  end
  
  @doc """
  Creates an error_recovered event.
  """
  def error_recovered(error, resolution) do
    %{
      type: :error_recovered,
      payload: %{
        error_id: error.id,
        error_type: error.type,
        message: error.message,
        resolution: resolution
      },
      metadata: %{
        timestamp: DateTime.utc_now(),
        source: __MODULE__
      }
    }
  end
end