defmodule Automata.Test.AssertUtils do
  @moduledoc """
  Utilities for making assertions in tests.
  
  This module provides custom assertions that are useful for testing
  distributed systems and asynchronous operations.
  """
  
  import ExUnit.Assertions
  
  @doc """
  Asserts that a condition becomes true within a given timeout.
  
  This is useful for testing asynchronous operations where the result
  might not be immediately available.
  
  ## Examples
  
  ```elixir
  assert_eventually fn -> 
    Registry.lookup(MyRegistry, :my_process) != []
  end
  ```
  
  ## Options
  
  - `:timeout` - Maximum time to wait for the condition (default: 5000 ms)
  - `:delay` - Time to wait between checks (default: 100 ms)
  - `:message` - Custom error message if the condition never becomes true
  """
  def assert_eventually(fun, opts \\ []) when is_function(fun, 0) do
    timeout = Keyword.get(opts, :timeout, 5000)
    delay = Keyword.get(opts, :delay, 100)
    message = Keyword.get(opts, :message, "Condition did not become true within #{timeout}ms")
    
    wait_until(fun, timeout, delay, message)
  end
  
  @doc """
  Asserts that a process is alive.
  
  ## Examples
  
  ```elixir
  pid = spawn(fn -> receive do :stop -> :ok end end)
  assert_alive(pid)
  ```
  """
  def assert_alive(pid) when is_pid(pid) do
    assert Process.alive?(pid), "Expected process #{inspect(pid)} to be alive"
  end
  
  @doc """
  Asserts that a process is registered with the given name.
  
  ## Examples
  
  ```elixir
  assert_registered(:my_process)
  ```
  """
  def assert_registered(name) when is_atom(name) do
    assert Process.whereis(name) != nil, "Expected process #{name} to be registered"
  end
  
  @doc """
  Asserts that a message is received within a given timeout.
  
  ## Examples
  
  ```elixir
  spawn(fn -> send(self(), :hello) end)
  assert_receive_message(:hello)
  ```
  
  ## Options
  
  - `:timeout` - Maximum time to wait for the message (default: 1000 ms)
  """
  def assert_receive_message(expected, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    
    receive do
      ^expected -> :ok
    after
      timeout -> flunk("Expected to receive #{inspect(expected)}, but no message received within #{timeout}ms")
    end
  end
  
  @doc """
  Asserts that a message matching the pattern is received within a given timeout.
  
  ## Examples
  
  ```elixir
  spawn(fn -> send(self(), {:result, 42}) end)
  assert_receive_pattern({:result, x}) when x > 40
  ```
  
  ## Options
  
  - `:timeout` - Maximum time to wait for the message (default: 1000 ms)
  """
  defmacro assert_receive_pattern(pattern, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    
    quote do
      receive do
        unquote(pattern) -> :ok
      after
        unquote(timeout) -> flunk("Expected to receive message matching #{Macro.to_string(unquote(pattern))}, but no matching message received within #{unquote(timeout)}ms")
      end
    end
  end
  
  @doc """
  Asserts that a distributed registry has an entry for the given key.
  
  ## Examples
  
  ```elixir
  assert_registered_in_horde(MyRegistry, :my_process)
  ```
  
  ## Options
  
  - `:timeout` - Maximum time to wait for the registration (default: 5000 ms)
  """
  def assert_registered_in_horde(registry, key, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    
    assert_eventually(fn ->
      case Horde.Registry.lookup(registry, key) do
        [] -> false
        [_|_] -> true
      end
    end, timeout: timeout, message: "Expected #{key} to be registered in #{registry} within #{timeout}ms")
  end
  
  @doc """
  Asserts that a key exists in the distributed blackboard.
  
  ## Examples
  
  ```elixir
  assert_in_blackboard({:agent, "agent-123"})
  ```
  
  ## Options
  
  - `:timeout` - Maximum time to wait for the key to appear (default: 5000 ms)
  """
  def assert_in_blackboard(key, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    
    assert_eventually(fn ->
      case Automata.Infrastructure.State.DistributedBlackboard.get(key) do
        nil -> false
        _ -> true
      end
    end, timeout: timeout, message: "Expected #{inspect(key)} to be in the blackboard within #{timeout}ms")
  end
  
  # Private helpers
  
  defp wait_until(fun, timeout, delay, message) do
    start = System.monotonic_time(:millisecond)
    do_wait_until(fun, start, timeout, delay, message)
  end
  
  defp do_wait_until(fun, start, timeout, delay, message) do
    case fun.() do
      true -> true
      truthy when truthy in [false, nil] ->
        now = System.monotonic_time(:millisecond)
        if now - start < timeout do
          :timer.sleep(delay)
          do_wait_until(fun, start, timeout, delay, message)
        else
          flunk(message)
        end
    end
  end
end