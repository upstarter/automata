defmodule Automata.Infrastructure.Resilience.CircuitBreaker do
  @moduledoc """
  Circuit Breaker implementation to prevent cascading failures.
  
  The circuit breaker pattern:
  - Tracks failures in dependent components
  - Opens the circuit when failure thresholds are exceeded
  - Prevents further calls to failing dependencies
  - Periodically tests if the dependency has recovered
  - Resumes normal operation once recovery is confirmed
  
  States:
  - :closed - Normal operation, calls go through to the service
  - :open - Service is failing, calls immediately return with error
  - :half_open - Testing if service has recovered, limited calls permitted
  """
  
  use GenServer
  require Logger
  alias Automata.Infrastructure.Resilience.Error
  
  @default_retry_timeout 30_000  # 30 seconds
  @default_failure_threshold 5   # 5 failures
  @default_reset_timeout 60_000  # 60 seconds
  
  # Client API
  
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_name(name))
  end
  
  @doc """
  Executes a function with circuit breaker protection.
  
  If the circuit is open, returns {:error, :circuit_open} immediately.
  If the circuit is closed, executes the function and tracks failures.
  If the circuit is half-open, executes the function and decides whether to close or re-open.
  
  Options:
  - timeout: Maximum time to wait for function execution (default: 5000 ms)
  """
  def execute(name, function, opts \\ []) when is_function(function, 0) do
    timeout = Keyword.get(opts, :timeout, 5000)
    
    try do
      case GenServer.call(via_name(name), {:execute, function, timeout}, timeout + 1000) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    catch
      :exit, {:timeout, _} ->
        GenServer.cast(via_name(name), {:execution_timeout, timeout})
        {:error, Error.new(:timeout, "Circuit breaker execution timed out after #{timeout}ms", %{circuit: name})}
    end
  end
  
  @doc """
  Forces the circuit to open, preventing all calls from going through.
  """
  def force_open(name, reason \\ "Circuit manually opened") do
    GenServer.call(via_name(name), {:force_open, reason})
  end
  
  @doc """
  Forces the circuit to close, allowing calls to go through.
  """
  def force_close(name) do
    GenServer.call(via_name(name), :force_close)
  end
  
  @doc """
  Gets the current state of the circuit.
  """
  def get_state(name) do
    GenServer.call(via_name(name), :get_state)
  end
  
  @doc """
  Gets statistics about the circuit.
  """
  def get_stats(name) do
    GenServer.call(via_name(name), :get_stats)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    Logger.info("Starting circuit breaker: #{name}")
    
    state = %{
      name: name,
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure: nil,
      last_success: nil,
      total_failures: 0,
      total_successes: 0,
      open_since: nil,
      reason: nil,
      failure_threshold: Keyword.get(opts, :failure_threshold, @default_failure_threshold),
      retry_timeout: Keyword.get(opts, :retry_timeout, @default_retry_timeout),
      reset_timeout: Keyword.get(opts, :reset_timeout, @default_reset_timeout)
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:execute, function, timeout}, _from, state) do
    case state.state do
      :open ->
        # Circuit is open, return error immediately
        {:reply, {:error, Error.new(:circuit_open, "Circuit '#{state.name}' is open: #{state.reason}", %{
          circuit: state.name,
          open_since: state.open_since
        })}, state}
        
      :half_open ->
        # Circuit is half-open, try execution and decide whether to close or re-open
        handle_half_open(function, timeout, state)
        
      :closed ->
        # Circuit is closed, normal operation
        handle_closed(function, timeout, state)
    end
  end
  
  @impl true
  def handle_call({:force_open, reason}, _from, state) do
    new_state = %{state | 
      state: :open, 
      open_since: DateTime.utc_now(),
      reason: reason
    }
    schedule_retry(new_state.retry_timeout)
    
    Logger.warning("Circuit '#{state.name}' manually opened: #{reason}")
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:force_close, _from, state) do
    new_state = %{state | 
      state: :closed, 
      failure_count: 0,
      success_count: 0,
      open_since: nil,
      reason: nil
    }
    
    Logger.info("Circuit '#{state.name}' manually closed")
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      name: state.name,
      state: state.state,
      failure_count: state.failure_count,
      success_count: state.success_count,
      total_failures: state.total_failures,
      total_successes: state.total_successes,
      last_failure: state.last_failure,
      last_success: state.last_success,
      open_since: state.open_since,
      reason: state.reason
    }
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_cast({:execution_timeout, timeout}, state) do
    # Handle timeout as a failure
    new_state = record_failure(state, "Execution timed out after #{timeout}ms")
    
    # Check if we need to open the circuit
    new_state = maybe_open_circuit(new_state)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:retry, state) do
    if state.state == :open do
      # Transition to half-open
      Logger.info("Circuit '#{state.name}' transitioning to half-open state")
      
      {:noreply, %{state | state: :half_open}}
    else
      # Already transitioned, do nothing
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(:reset, state) do
    if state.state == :half_open do
      # No successes in half-open, go back to open
      Logger.warning("Circuit '#{state.name}' failed recovery test, returning to open state")
      
      new_state = %{state | 
        state: :open, 
        open_since: DateTime.utc_now(),
        reason: "Failed recovery test"
      }
      
      schedule_retry(new_state.retry_timeout)
      {:noreply, new_state}
    else
      # Already transitioned, do nothing
      {:noreply, state}
    end
  end
  
  # Private helpers
  
  defp handle_closed(function, timeout, state) do
    try do
      result = execute_with_timeout(function, timeout)
      case result do
        {:ok, value} ->
          # Success
          new_state = record_success(state)
          {:reply, {:ok, value}, new_state}
          
        {:error, error} ->
          # Error
          new_state = record_failure(state, error)
          new_state = maybe_open_circuit(new_state)
          {:reply, {:error, error}, new_state}
      end
    rescue
      exception ->
        error = Error.from_exception(exception, %{circuit: state.name})
        new_state = record_failure(state, error)
        new_state = maybe_open_circuit(new_state)
        {:reply, {:error, error}, new_state}
    end
  end
  
  defp handle_half_open(function, timeout, state) do
    try do
      result = execute_with_timeout(function, timeout)
      case result do
        {:ok, value} ->
          # Success in half-open state, close the circuit
          Logger.info("Circuit '#{state.name}' recovery successful, closing circuit")
          
          new_state = %{state | 
            state: :closed, 
            failure_count: 0,
            success_count: 0,
            last_success: DateTime.utc_now(),
            total_successes: state.total_successes + 1,
            open_since: nil,
            reason: nil
          }
          
          {:reply, {:ok, value}, new_state}
          
        {:error, error} ->
          # Failure in half-open state, go back to open
          Logger.warning("Circuit '#{state.name}' recovery failed, reopening circuit")
          
          new_state = %{state | 
            state: :open, 
            last_failure: DateTime.utc_now(),
            total_failures: state.total_failures + 1,
            open_since: DateTime.utc_now(),
            reason: "Recovery test failed: #{inspect(error)}"
          }
          
          schedule_retry(new_state.retry_timeout)
          {:reply, {:error, error}, new_state}
      end
    rescue
      exception ->
        error = Error.from_exception(exception, %{circuit: state.name})
        
        Logger.warning("Circuit '#{state.name}' recovery test raised exception, reopening circuit")
        
        new_state = %{state | 
          state: :open, 
          last_failure: DateTime.utc_now(),
          total_failures: state.total_failures + 1,
          open_since: DateTime.utc_now(),
          reason: "Recovery test exception: #{Exception.message(exception)}"
        }
        
        schedule_retry(new_state.retry_timeout)
        {:reply, {:error, error}, new_state}
    end
  end
  
  defp execute_with_timeout(function, timeout) do
    task = Task.async(fn -> 
      try do
        {:ok, function.()}
      rescue
        exception -> {:error, Error.from_exception(exception)}
      catch
        kind, reason -> 
          {:error, Error.new(:unexpected_error, "#{kind}: #{inspect(reason)}")}
      end
    end)
    
    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, Error.new(:timeout, "Execution timed out after #{timeout}ms")}
    end
  end
  
  defp record_success(state) do
    %{state | 
      success_count: state.success_count + 1,
      total_successes: state.total_successes + 1,
      last_success: DateTime.utc_now()
    }
  end
  
  defp record_failure(state, error) do
    %{state | 
      failure_count: state.failure_count + 1,
      total_failures: state.total_failures + 1,
      last_failure: DateTime.utc_now(),
      reason: if(is_binary(error), do: error, else: inspect(error))
    }
  end
  
  defp maybe_open_circuit(state) do
    if state.failure_count >= state.failure_threshold do
      Logger.warning("Circuit '#{state.name}' opened after #{state.failure_count} failures: #{state.reason}")
      
      new_state = %{state | 
        state: :open, 
        open_since: DateTime.utc_now()
      }
      
      # Schedule retry
      schedule_retry(new_state.retry_timeout)
      
      new_state
    else
      state
    end
  end
  
  defp schedule_retry(timeout) do
    Process.send_after(self(), :retry, timeout)
  end
  
  defp via_name(name) do
    if is_binary(name) do
      {:via, Registry, {Automata.Infrastructure.Resilience.Registry, name}}
    else
      name
    end
  end
end

defmodule Automata.Infrastructure.Resilience.CircuitBreakerSupervisor do
  @moduledoc """
  Supervisor for circuit breakers.
  """
  use DynamicSupervisor
  require Logger
  
  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @impl true
  def init(_) do
    Logger.info("Starting Circuit Breaker Supervisor")
    DynamicSupervisor.init(strategy: :one_for_one)
  end
  
  @doc """
  Creates a new circuit breaker.
  
  Options:
  - name: Name of the circuit breaker (required)
  - failure_threshold: Number of failures before opening (default: 5)
  - retry_timeout: Time to wait before trying half-open (default: 30s)
  - reset_timeout: Time to wait for successful test in half-open (default: 60s)
  """
  def create(opts) do
    # Ensure name is provided
    case Keyword.fetch(opts, :name) do
      {:ok, name} when is_binary(name) or is_atom(name) ->
        # Start circuit breaker
        cb_spec = %{
          id: name,
          start: {
            Automata.Infrastructure.Resilience.CircuitBreaker,
            :start_link,
            [opts]
          }
        }
        
        DynamicSupervisor.start_child(__MODULE__, cb_spec)
        
      _ ->
        {:error, :invalid_name}
    end
  end
  
  @doc """
  Stops a circuit breaker.
  """
  def stop(name) do
    # Find the circuit breaker process
    case Registry.lookup(Automata.Infrastructure.Resilience.Registry, name) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        
      [] ->
        {:error, :not_found}
    end
  end
  
  @doc """
  Lists all circuit breakers.
  """
  def list do
    Registry.select(
      Automata.Infrastructure.Resilience.Registry,
      [{
        {:"$1", :"$2", :"$3"},
        [],
        [{{:"$1", :"$2", :"$3"}}]
      }]
    )
  end
end