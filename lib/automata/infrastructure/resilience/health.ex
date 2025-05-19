defmodule Automata.Infrastructure.Resilience.Health do
  @moduledoc """
  Health monitoring and reporting for the Automata system.
  
  This module provides:
  - Health checking components of the system
  - Graceful degradation policies
  - Automatic recovery mechanisms
  - System health reporting
  """
  
  use GenServer
  require Logger
  alias Automata.Infrastructure.Resilience.{Error, Logger, Telemetry}
  
  # Health check statuses
  @health_statuses [:healthy, :degraded, :unhealthy]
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Registers a health check function for periodic execution.
  
  Options:
  - id: Unique identifier for the health check
  - interval: How often to run the check in milliseconds (default: 60_000)
  - timeout: Maximum time the check can run (default: 5_000)
  - critical: If true, the check is critical for system health (default: false)
  """
  def register_check(check_fn, opts \\ []) when is_function(check_fn, 0) do
    id = Keyword.get(opts, :id, "check-#{System.unique_integer([:positive])}")
    interval = Keyword.get(opts, :interval, 60_000)
    timeout = Keyword.get(opts, :timeout, 5_000)
    critical = Keyword.get(opts, :critical, false)
    
    GenServer.call(__MODULE__, {:register_check, %{
      id: id,
      function: check_fn,
      interval: interval,
      timeout: timeout,
      critical: critical,
      last_run: nil,
      last_result: nil,
      failures: 0
    }})
  end
  
  @doc """
  Deregisters a health check.
  """
  def deregister_check(id) do
    GenServer.call(__MODULE__, {:deregister_check, id})
  end
  
  @doc """
  Returns the current health status of the system.
  """
  def get_system_health do
    GenServer.call(__MODULE__, :get_system_health)
  end
  
  @doc """
  Returns the current health status of a specific component.
  """
  def get_component_health(component) do
    GenServer.call(__MODULE__, {:get_component_health, component})
  end
  
  @doc """
  Returns the current health status of all components.
  """
  def get_all_component_health do
    GenServer.call(__MODULE__, :get_all_component_health)
  end
  
  @doc """
  Manually marks a component as healthy/unhealthy.
  """
  def set_component_health(component, status, reason \\ nil) when status in @health_statuses do
    GenServer.call(__MODULE__, {:set_component_health, component, status, reason})
  end
  
  @doc """
  Runs all health checks immediately and returns the results.
  """
  def run_all_checks do
    GenServer.call(__MODULE__, :run_all_checks, 60_000)
  end
  
  @doc """
  Runs a specific health check immediately and returns the result.
  """
  def run_check(id) do
    GenServer.call(__MODULE__, {:run_check, id}, 60_000)
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    Logger.info("Starting Health Monitor")
    
    # Initialize state
    state = %{
      checks: %{},  # Map of check_id -> check_config
      components: %{},  # Map of component_name -> health_status
      system_status: :healthy,
      started_at: DateTime.utc_now(),
      last_full_check: nil
    }
    
    # Start timer for regular health check
    schedule_check_run()
    
    # Register health checks for core components
    if Keyword.get(opts, :register_default_checks, true) do
      register_default_checks()
    end
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:register_check, check_config}, _from, state) do
    # Add check to state
    checks = Map.put(state.checks, check_config.id, check_config)
    
    # Schedule initial run
    Process.send_after(self(), {:run_check, check_config.id}, 0)
    
    {:reply, {:ok, check_config.id}, %{state | checks: checks}}
  end
  
  @impl true
  def handle_call({:deregister_check, id}, _from, state) do
    # Remove check from state
    checks = Map.delete(state.checks, id)
    
    {:reply, :ok, %{state | checks: checks}}
  end
  
  @impl true
  def handle_call(:get_system_health, _from, state) do
    # Return overall system health status
    system_health = %{
      status: state.system_status,
      components: state.components,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      checks: map_size(state.checks),
      last_check: state.last_full_check
    }
    
    {:reply, system_health, state}
  end
  
  @impl true
  def handle_call({:get_component_health, component}, _from, state) do
    # Return component health status
    component_status = Map.get(state.components, component, :unknown)
    
    {:reply, component_status, state}
  end
  
  @impl true
  def handle_call(:get_all_component_health, _from, state) do
    # Return all component health statuses
    {:reply, state.components, state}
  end
  
  @impl true
  def handle_call({:set_component_health, component, status, reason}, _from, state) do
    # Update component health status
    components = Map.put(state.components, component, %{
      status: status,
      reason: reason,
      last_updated: DateTime.utc_now()
    })
    
    # Recalculate system status
    system_status = calculate_system_status(components)
    
    # Send telemetry event
    Telemetry.execute(
      [:automata, :health, :component, :status_change],
      %{count: 1},
      %{
        component: component,
        status: status,
        reason: reason,
        previous_status: state.components[component]
      }
    )
    
    # Log significant changes
    if status == :unhealthy do
      Logger.warning("Component #{component} marked as unhealthy: #{reason}")
    end
    
    {:reply, :ok, %{state | components: components, system_status: system_status}}
  end
  
  @impl true
  def handle_call(:run_all_checks, _from, state) do
    # Run all checks
    check_results = Enum.map(state.checks, fn {id, _} ->
      {id, run_health_check(id, state.checks[id])}
    end)
    |> Map.new()
    
    # Update state with check results
    updated_checks = Enum.reduce(check_results, state.checks, fn {id, result}, acc ->
      update_check_state(acc, id, result)
    end)
    
    # Update component health based on check results
    {components, system_status} = update_health_from_checks(updated_checks, state.components)
    
    {:reply, check_results, %{state | 
      checks: updated_checks, 
      components: components, 
      system_status: system_status,
      last_full_check: DateTime.utc_now()
    }}
  end
  
  @impl true
  def handle_call({:run_check, id}, _from, state) do
    case Map.get(state.checks, id) do
      nil ->
        {:reply, {:error, :not_found}, state}
        
      check ->
        # Run the specified check
        result = run_health_check(id, check)
        
        # Update check state
        updated_checks = update_check_state(state.checks, id, result)
        
        # Update component health based on check results
        {components, system_status} = update_health_from_checks(updated_checks, state.components)
        
        {:reply, result, %{state | 
          checks: updated_checks, 
          components: components, 
          system_status: system_status 
        }}
    end
  end
  
  @impl true
  def handle_info(:run_checks, state) do
    # Run all health checks
    {_check_results, updated_state} = handle_call(:run_all_checks, self(), state)
    |> elem(2)
    
    # Publish health telemetry
    publish_health_telemetry(updated_state)
    
    # Schedule next run
    schedule_check_run()
    
    {:noreply, updated_state}
  end
  
  @impl true
  def handle_info({:run_check, id}, state) do
    case Map.get(state.checks, id) do
      nil ->
        {:noreply, state}
        
      check ->
        # Run the check
        result = run_health_check(id, check)
        
        # Update check state
        updated_checks = update_check_state(state.checks, id, result)
        
        # Update component health based on check results
        {components, system_status} = update_health_from_checks(updated_checks, state.components)
        
        # Schedule next run
        Process.send_after(self(), {:run_check, id}, check.interval)
        
        {:noreply, %{state | 
          checks: updated_checks, 
          components: components, 
          system_status: system_status 
        }}
    end
  end
  
  # Private helpers
  
  defp register_default_checks do
    # Register system checks
    register_check(
      fn -> check_system_resources() end,
      id: "system-resources",
      interval: 30_000,
      critical: true
    )
    
    # Register process registry check
    if Process.whereis(Automata.Infrastructure.Registry.DistributedRegistry) do
      register_check(
        fn -> check_distributed_registry() end,
        id: "distributed-registry",
        interval: 30_000,
        critical: true
      )
    end
    
    # Register cluster status check
    register_check(
      fn -> check_cluster_status() end,
      id: "cluster-status",
      interval: 60_000
    )
    
    # Register event bus check
    if Process.whereis(Automata.Infrastructure.Event.EventBus) do
      register_check(
        fn -> check_event_bus() end,
        id: "event-bus",
        interval: 30_000,
        critical: true
      )
    end
    
    # Register circuit breaker status check
    register_check(
      fn -> check_circuit_breakers() end,
      id: "circuit-breakers",
      interval: 30_000
    )
  end
  
  defp run_health_check(id, check) do
    start_time = System.monotonic_time(:millisecond)
    
    result = try do
      # Run the check with a timeout
      task = Task.async(check.function)
      case Task.yield(task, check.timeout) || Task.shutdown(task) do
        {:ok, result} -> 
          %{status: :ok, result: result, message: "Check passed"}
          
        nil -> 
          %{status: :error, result: nil, message: "Check timed out after #{check.timeout}ms"}
      end
    rescue
      exception ->
        %{
          status: :error, 
          result: nil, 
          message: "Check failed with exception: #{Exception.message(exception)}",
          exception: exception
        }
    end
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    # Publish telemetry event for the check
    Telemetry.execute(
      [:automata, :health, :check, :completed],
      %{duration: duration},
      %{
        check_id: id,
        status: result.status,
        message: result.message
      }
    )
    
    # Add duration to result
    Map.put(result, :duration, duration)
  end
  
  defp update_check_state(checks, id, result) do
    check = Map.get(checks, id)
    
    # Update failures count
    failures = if result.status == :error do
      check.failures + 1
    else
      0
    end
    
    # Update check state
    Map.put(checks, id, %{check | 
      last_run: DateTime.utc_now(),
      last_result: result,
      failures: failures
    })
  end
  
  defp update_health_from_checks(checks, components) do
    # Update components based on check results
    components = Enum.reduce(checks, components, fn {id, check}, acc ->
      component_key = String.split(id, "-") |> List.first() |> String.to_atom()
      
      if check.last_result do
        component_status = if check.last_result.status == :ok do
          :healthy
        else
          if check.failures >= 3 do
            :unhealthy
          else
            :degraded
          end
        end
        
        # Only update if the component isn't already in a worse state
        existing = Map.get(acc, component_key, %{status: :healthy})
        
        if component_status_value(component_status) > component_status_value(existing.status) do
          acc
        else
          Map.put(acc, component_key, %{
            status: component_status,
            reason: check.last_result.message,
            last_updated: DateTime.utc_now()
          })
        end
      else
        acc
      end
    end)
    
    # Calculate overall system status
    system_status = calculate_system_status(components)
    
    {components, system_status}
  end
  
  defp calculate_system_status(components) do
    # Check if any critical components are unhealthy
    critical_unhealthy = Enum.any?(components, fn {component, health} ->
      is_critical_component?(component) and health.status == :unhealthy
    end)
    
    if critical_unhealthy do
      :unhealthy
    else
      # Check if any components are unhealthy
      any_unhealthy = Enum.any?(components, fn {_component, health} ->
        health.status == :unhealthy
      end)
      
      # Check if any components are degraded
      any_degraded = Enum.any?(components, fn {_component, health} ->
        health.status == :degraded
      end)
      
      cond do
        any_unhealthy -> :degraded
        any_degraded -> :degraded
        true -> :healthy
      end
    end
  end
  
  defp component_status_value(:healthy), do: 0
  defp component_status_value(:degraded), do: 1
  defp component_status_value(:unhealthy), do: 2
  defp component_status_value(_), do: 3
  
  defp is_critical_component?(:system), do: true
  defp is_critical_component?(:distributed_registry), do: true
  defp is_critical_component?(:event_bus), do: true
  defp is_critical_component?(_), do: false
  
  defp schedule_check_run do
    Process.send_after(self(), :run_checks, 60_000) # Run all checks every minute
  end
  
  defp publish_health_telemetry(state) do
    # Convert component status to numeric values for metrics
    component_metrics = Enum.map(state.components, fn {component, health} ->
      {component, component_status_value(health.status)}
    end)
    |> Map.new()
    
    # Publish telemetry event for overall health
    Telemetry.execute(
      [:automata, :health, :system],
      %{
        status: component_status_value(state.system_status),
        components: map_size(state.components),
        checks: map_size(state.checks)
      },
      %{
        components: component_metrics
      }
    )
  end
  
  # Health check implementations
  
  defp check_system_resources do
    # Check memory usage
    memory = :erlang.memory()
    total_memory = memory[:total]
    process_memory = memory[:processes]
    memory_threshold = 1024 * 1024 * 1024 # 1GB
    
    # Check process count
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    process_threshold = process_limit * 0.8
    
    # Check scheduler utilization
    scheduler_count = :erlang.system_info(:schedulers)
    
    cond do
      total_memory > memory_threshold ->
        {:error, "High memory usage: #{div(total_memory, 1024 * 1024)} MB"}
        
      process_count > process_threshold ->
        {:error, "High process count: #{process_count}/#{process_limit}"}
        
      true ->
        {:ok, %{
          total_memory_mb: div(total_memory, 1024 * 1024),
          process_memory_mb: div(process_memory, 1024 * 1024),
          process_count: process_count,
          process_limit: process_limit,
          scheduler_count: scheduler_count
        }}
    end
  end
  
  defp check_distributed_registry do
    registry = Automata.Infrastructure.Registry.DistributedRegistry
    
    if Process.whereis(registry) do
      # Check if registry is responsive
      try do
        # Try a simple lookup operation
        registry.all_members()
        {:ok, "Registry is responsive"}
      rescue
        _ -> {:error, "Registry operation failed"}
      end
    else
      {:error, "Registry process not found"}
    end
  end
  
  defp check_cluster_status do
    # Check connected nodes
    nodes = Node.list()
    
    if nodes == [] do
      {:ok, "Node is not in a cluster"}
    else
      # Check if nodes are responsive
      unresponsive = Enum.filter(nodes, fn node ->
        not Node.ping(node) == :pong
      end)
      
      if unresponsive == [] do
        {:ok, %{connected_nodes: length(nodes)}}
      else
        {:error, "Unresponsive nodes: #{inspect(unresponsive)}"}
      end
    end
  end
  
  defp check_event_bus do
    event_bus = Automata.Infrastructure.Event.EventBus
    
    if Process.whereis(event_bus) do
      # Check if event bus is responsive
      try do
        # Publish a test event
        test_event = %{
          type: :health_check,
          payload: %{timestamp: DateTime.utc_now()},
          metadata: %{source: __MODULE__}
        }
        
        event_bus.publish(test_event)
        {:ok, "Event bus is responsive"}
      rescue
        _ -> {:error, "Event bus operation failed"}
      end
    else
      {:error, "Event bus process not found"}
    end
  end
  
  defp check_circuit_breakers do
    supervisor = Automata.Infrastructure.Resilience.CircuitBreakerSupervisor
    
    if Process.whereis(supervisor) do
      # Get all circuit breakers
      circuit_breakers = supervisor.list()
      
      # Check if any circuit breakers are open
      open_circuits = Enum.filter(circuit_breakers, fn {name, _pid, _} ->
        Automata.Infrastructure.Resilience.CircuitBreaker.get_state(name) == :open
      end)
      
      if open_circuits == [] do
        {:ok, %{circuit_count: length(circuit_breakers)}}
      else
        {:warning, "Open circuits: #{inspect(Enum.map(open_circuits, fn {name, _, _} -> name end))}"}
      end
    else
      {:ok, "Circuit breaker supervisor not started"}
    end
  end
end