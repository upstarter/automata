defmodule Automata.Infrastructure.Resilience.CircuitBreakerTest do
  use ExUnit.Case
  import Automata.Test.AssertUtils
  
  alias Automata.Infrastructure.Resilience.{CircuitBreaker, CircuitBreakerSupervisor, Error}
  
  setup do
    # Set up a test circuit breaker
    circuit_name = "test-circuit-#{System.unique_integer([:positive])}"
    
    start_supervised!({
      Registry, 
      keys: :unique, 
      name: Automata.Infrastructure.Resilience.Registry
    })
    
    start_supervised!(CircuitBreakerSupervisor)
    
    {:ok, _pid} = CircuitBreakerSupervisor.create(
      name: circuit_name,
      failure_threshold: 3,
      retry_timeout: 200,  # Short timeout for testing
      reset_timeout: 500   # Short timeout for testing
    )
    
    %{circuit_name: circuit_name}
  end
  
  describe "circuit breaker" do
    test "executes successful functions", %{circuit_name: circuit_name} do
      # Execute a successful function
      result = CircuitBreaker.execute(circuit_name, fn ->
        42
      end)
      
      assert result == {:ok, 42}
      
      # Circuit should remain closed
      assert CircuitBreaker.get_state(circuit_name) == :closed
      
      # Get stats
      stats = CircuitBreaker.get_stats(circuit_name)
      assert stats.success_count == 1
      assert stats.failure_count == 0
    end
    
    test "handles function failures", %{circuit_name: circuit_name} do
      # Execute a failing function
      result = CircuitBreaker.execute(circuit_name, fn ->
        raise "Test error"
      end)
      
      assert match?({:error, _}, result)
      
      # Circuit should still be closed after one failure
      assert CircuitBreaker.get_state(circuit_name) == :closed
      
      # Get stats
      stats = CircuitBreaker.get_stats(circuit_name)
      assert stats.success_count == 0
      assert stats.failure_count == 1
    end
    
    test "opens after threshold failures", %{circuit_name: circuit_name} do
      # Fail multiple times to reach threshold
      for _ <- 1..3 do
        CircuitBreaker.execute(circuit_name, fn ->
          {:error, "Test error"}
        end)
      end
      
      # Circuit should be open
      assert CircuitBreaker.get_state(circuit_name) == :open
      
      # Attempts while open should fail immediately
      start_time = System.monotonic_time(:millisecond)
      result = CircuitBreaker.execute(circuit_name, fn ->
        Process.sleep(1000) # This should not execute
        :ok
      end)
      end_time = System.monotonic_time(:millisecond)
      
      # Should fail quickly without executing function
      assert match?({:error, _}, result)
      assert end_time - start_time < 100
      
      # Get stats
      stats = CircuitBreaker.get_stats(circuit_name)
      assert stats.failure_count >= 3
      assert stats.state == :open
    end
    
    test "transitions to half-open after timeout", %{circuit_name: circuit_name} do
      # Open the circuit
      CircuitBreaker.force_open(circuit_name)
      assert CircuitBreaker.get_state(circuit_name) == :open
      
      # Wait for retry timeout
      assert_eventually fn ->
        CircuitBreaker.get_state(circuit_name) == :half_open
      end, timeout: 1000
    end
    
    test "closes after successful test in half-open state", %{circuit_name: circuit_name} do
      # Open the circuit
      CircuitBreaker.force_open(circuit_name)
      
      # Wait for half-open state
      assert_eventually fn ->
        CircuitBreaker.get_state(circuit_name) == :half_open
      end, timeout: 1000
      
      # Execute successful function in half-open state
      result = CircuitBreaker.execute(circuit_name, fn ->
        :success
      end)
      
      assert result == {:ok, :success}
      
      # Circuit should close
      assert CircuitBreaker.get_state(circuit_name) == :closed
    end
    
    test "reopens after failure in half-open state", %{circuit_name: circuit_name} do
      # Open the circuit
      CircuitBreaker.force_open(circuit_name)
      
      # Wait for half-open state
      assert_eventually fn ->
        CircuitBreaker.get_state(circuit_name) == :half_open
      end, timeout: 1000
      
      # Execute failing function in half-open state
      CircuitBreaker.execute(circuit_name, fn ->
        {:error, "Still failing"}
      end)
      
      # Circuit should reopen
      assert CircuitBreaker.get_state(circuit_name) == :open
    end
    
    test "can be manually controlled", %{circuit_name: circuit_name} do
      # Force open
      :ok = CircuitBreaker.force_open(circuit_name, "Manual open")
      assert CircuitBreaker.get_state(circuit_name) == :open
      
      # Force close
      :ok = CircuitBreaker.force_close(circuit_name)
      assert CircuitBreaker.get_state(circuit_name) == :closed
    end
    
    test "provides accurate statistics", %{circuit_name: circuit_name} do
      # Mix of successes and failures
      CircuitBreaker.execute(circuit_name, fn -> :ok end)
      CircuitBreaker.execute(circuit_name, fn -> :ok end)
      CircuitBreaker.execute(circuit_name, fn -> {:error, "error"} end)
      CircuitBreaker.execute(circuit_name, fn -> :ok end)
      
      # Get stats
      stats = CircuitBreaker.get_stats(circuit_name)
      assert stats.name == circuit_name
      assert stats.success_count == 3
      assert stats.failure_count == 1
      assert stats.total_successes == 3
      assert stats.total_failures == 1
      assert stats.state == :closed
    end
  end
end