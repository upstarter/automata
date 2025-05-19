defmodule Automata.Examples.ResilienceDemo do
  @moduledoc """
  Demonstrates the resilience features of the Automata system.
  
  This module provides examples of:
  - Error handling with standard error formats
  - Circuit breaker usage
  - Enhanced logging with context and correlation IDs
  - Telemetry events for metrics
  - Health monitoring
  
  To run this demo, execute:
  ```
  iex -S mix
  Automata.Examples.ResilienceDemo.run()
  ```
  """
  
  alias Automata.Infrastructure.Resilience.{
    CircuitBreaker, 
    CircuitBreakerSupervisor, 
    Error, 
    Health, 
    Logger, 
    Telemetry
  }
  
  @doc """
  Runs the resilience features demonstration.
  """
  def run do
    IO.puts("\n=== Automata Resilience Features Demo ===\n")
    
    # Setup
    IO.puts("Setting up demo...")
    :ok = setup()
    
    # Demonstrate error handling
    IO.puts("\n--- Error Handling Demo ---")
    demo_error_handling()
    
    # Demonstrate circuit breaker
    IO.puts("\n--- Circuit Breaker Demo ---")
    demo_circuit_breaker()
    
    # Demonstrate enhanced logging
    IO.puts("\n--- Enhanced Logging Demo ---")
    demo_enhanced_logging()
    
    # Demonstrate telemetry
    IO.puts("\n--- Telemetry Demo ---")
    demo_telemetry()
    
    # Demonstrate health monitoring
    IO.puts("\n--- Health Monitoring Demo ---")
    demo_health_monitoring()
    
    IO.puts("\n=== Demo Complete ===\n")
    :ok
  end
  
  # Setup helpers
  
  defp setup do
    # Create circuit breakers for demo
    :ok = create_demo_circuit_breakers()
    
    # Register health checks for demo
    :ok = register_demo_health_checks()
    
    # Register demo telemetry handlers
    :ok = register_demo_telemetry_handlers()
    
    :ok
  end
  
  defp create_demo_circuit_breakers do
    # Create a circuit breaker for a demo service
    CircuitBreakerSupervisor.create(
      name: "demo-service",
      failure_threshold: 3,
      retry_timeout: 5_000
    )
    
    # Create a circuit breaker for database operations
    CircuitBreakerSupervisor.create(
      name: "demo-database",
      failure_threshold: 2,
      retry_timeout: 3_000
    )
    
    :ok
  end
  
  defp register_demo_health_checks do
    # Register a demo health check
    Health.register_check(
      fn -> 
        # Simulate a health check that sometimes fails
        if :rand.uniform(10) <= 8 do
          {:ok, "Demo service is healthy"}
        else
          {:error, "Demo service is experiencing issues"}
        end
      end,
      id: "demo-service",
      interval: 5_000
    )
    
    :ok
  end
  
  defp register_demo_telemetry_handlers do
    # Register a demo telemetry handler
    Telemetry.attach_handler(
      :demo_handler,
      [:automata, :demo, :operation],
      fn _event, measurements, metadata, _config ->
        IO.puts("Demo telemetry event received:")
        IO.puts("  - Duration: #{Map.get(measurements, :duration, "N/A")}μs")
        IO.puts("  - Operation: #{Map.get(metadata, :operation, "unknown")}")
        IO.puts("  - Status: #{Map.get(metadata, :status, "unknown")}")
      end
    )
    
    :ok
  end
  
  # Error handling demo
  
  defp demo_error_handling do
    # Create a standard error
    error = Error.new(:validation_error, "Invalid configuration value", %{key: "max_connections", value: -1})
    
    # Log the error
    Error.log(error)
    
    IO.puts("Created and logged a standard error:")
    IO.puts("  Type: #{inspect(error.type)}")
    IO.puts("  Message: #{error.message}")
    IO.puts("  ID: #{error.id}")
    
    # Demonstrate error wrapping
    result = with {:error, reason} <- demo_operation_with_error() do
      Error.wrap({:error, reason}, %{context: "demo"})
    end
    
    IO.puts("\nWrapped an error from an operation:")
    IO.puts("  Result: #{inspect(result)}")
    
    # Show error stats
    stats = Automata.Infrastructure.Resilience.ErrorTracker.get_stats()
    
    IO.puts("\nError stats:")
    IO.puts("  Total errors: #{stats.total}")
    
    :ok
  end
  
  defp demo_operation_with_error do
    {:error, "Connection refused"}
  end
  
  # Circuit breaker demo
  
  defp demo_circuit_breaker do
    # Get initial circuit state
    state = CircuitBreaker.get_state("demo-service")
    IO.puts("Initial circuit state: #{state}")
    
    # Demonstrate successful operation
    IO.puts("\nExecuting successful operation through circuit breaker...")
    
    result = CircuitBreaker.execute("demo-service", fn ->
      IO.puts("  Operation executed successfully")
      :ok
    end)
    
    IO.puts("Result: #{inspect(result)}")
    
    # Demonstrate failing operation
    IO.puts("\nExecuting failing operations to open the circuit...")
    
    # Execute failing operations until circuit opens
    Enum.each(1..4, fn i ->
      result = CircuitBreaker.execute("demo-service", fn ->
        raise "Demo failure #{i}"
      end)
      
      IO.puts("  Attempt #{i} result: #{inspect(result)}")
      
      # Brief pause between attempts
      Process.sleep(100)
    end)
    
    # Check circuit state
    state = CircuitBreaker.get_state("demo-service")
    IO.puts("\nCircuit state after failures: #{state}")
    
    # Try operation with open circuit
    IO.puts("\nAttempting operation with open circuit...")
    
    result = CircuitBreaker.execute("demo-service", fn ->
      IO.puts("This should not execute because circuit is open")
      :ok
    end)
    
    IO.puts("Result: #{inspect(result)}")
    
    # Force close circuit for demo purposes
    CircuitBreaker.force_close("demo-service")
    IO.puts("\nForced circuit to close")
    
    :ok
  end
  
  # Enhanced logging demo
  
  defp demo_enhanced_logging do
    # Simple logging
    Logger.info("This is a simple info message")
    Logger.warning("This is a warning message")
    
    # Structured logging with metadata
    Logger.info("User logged in", %{user_id: "user-123", source_ip: "192.168.1.1"})
    
    # Logging with context
    IO.puts("\nLogging with context...")
    
    Logger.set_context(%{request_id: "req-456", session_id: "sess-789"})
    Logger.info("Processing request")
    Logger.warning("Request parameters invalid", %{params: %{id: "invalid"}})
    Logger.clear_context()
    
    # Logging with correlation ID
    IO.puts("\nLogging with correlation ID...")
    
    Logger.with_correlation(fn ->
      correlation_id = Logger.get_correlation_id()
      Logger.info("Starting operation with correlation ID", %{correlation_id: correlation_id})
      
      # Simulate sub-operation
      Process.sleep(100)
      Logger.info("Sub-operation completed")
      
      # Simulate error
      Logger.error("Operation failed", %{reason: "timeout"})
    end).()
    
    # Measure operation timing
    IO.puts("\nMeasuring operation timing...")
    
    result = Logger.measure("demo-calculation", fn ->
      # Simulate work
      Process.sleep(150)
      {:ok, 42}
    end)
    
    IO.puts("Operation result: #{inspect(result)}")
    
    :ok
  end
  
  # Telemetry demo
  
  defp demo_telemetry do
    # Execute a simple telemetry event
    Telemetry.execute(
      [:automata, :demo, :event],
      %{count: 1},
      %{source: "demo"}
    )
    
    IO.puts("Executed a simple telemetry event")
    
    # Execute an operation with telemetry
    IO.puts("\nExecuting operation with telemetry span...")
    
    result = Telemetry.span("demo-operation", fn ->
      # Simulate work
      Process.sleep(200)
      
      # Execute nested telemetry event
      Telemetry.execute(
        [:automata, :demo, :operation],
        %{duration: 50_000},
        %{operation: "process_data", status: :success}
      )
      
      {:ok, "operation complete"}
    end)
    
    IO.puts("Operation result: #{inspect(result)}")
    
    # Report system metrics
    IO.puts("\nReporting system metrics...")
    Telemetry.report_system_metrics()
    
    :ok
  end
  
  # Health monitoring demo
  
  defp demo_health_monitoring do
    # Get system health
    health = Health.get_system_health()
    
    IO.puts("Current system health:")
    IO.puts("  Status: #{health.status}")
    IO.puts("  Component count: #{map_size(health.components)}")
    
    # Run health checks
    IO.puts("\nRunning all health checks...")
    check_results = Health.run_all_checks()
    
    IO.puts("Health check results:")
    Enum.each(check_results, fn {id, result} ->
      status = if result.status == :ok, do: "✓", else: "✗"
      IO.puts("  #{status} #{id}: #{result.message}")
    end)
    
    # Manually set component health
    IO.puts("\nManually setting component health...")
    
    Health.set_component_health(:demo_component, :degraded, "Simulated performance issue")
    IO.puts("Set demo_component to degraded state")
    
    # Get updated health
    health = Health.get_system_health()
    
    IO.puts("\nUpdated system health:")
    IO.puts("  Status: #{health.status}")
    
    # Reset component health
    Health.set_component_health(:demo_component, :healthy, "Issue resolved")
    IO.puts("\nReset demo_component to healthy state")
    
    :ok
  end
end