defmodule Automata.Infrastructure.Registry.DistributedRegistryTest do
  use ExUnit.Case
  use Automata.Test.DistributedTestCase
  
  alias Automata.Infrastructure.Registry.DistributedRegistry
  
  setup do
    # Start registry for individual tests
    start_supervised!(DistributedRegistry)
    :ok
  end
  
  describe "distributed registry" do
    test "registers and looks up processes" do
      # Register self with some key
      test_key = {:test, "process-#{System.unique_integer([:positive])}"}
      :ok = DistributedRegistry.register(test_key)
      
      # Lookup should find it
      assert DistributedRegistry.lookup(test_key) == [self()]
    end
    
    test "handles multiple registrations" do
      # Register multiple processes
      test_keys = for i <- 1..5 do
        key = {:test, "process-#{i}"}
        pid = spawn(fn -> Process.sleep(10_000) end)
        
        # Register pid with key
        :ok = DistributedRegistry.register(key, pid)
        
        # Return key and pid
        {key, pid}
      end
      
      # Verify all registrations
      for {key, pid} <- test_keys do
        assert DistributedRegistry.lookup(key) == [pid]
      end
      
      # Clean up
      for {_key, pid} <- test_keys do
        Process.exit(pid, :kill)
      end
    end
    
    test "automatically removes dead processes" do
      # Register a process that dies
      test_key = {:test, "dying-process"}
      
      # Create a process that will die
      pid = spawn(fn -> :ok end)
      
      # Wait for process to die
      :timer.sleep(100)
      
      # Register it anyway (should be allowed but not stored)
      :ok = DistributedRegistry.register(test_key, pid)
      
      # Lookup should not find it
      assert DistributedRegistry.lookup(test_key) == []
    end
    
    test "handles process exit" do
      # Register a process that will exit
      test_key = {:test, "exiting-process"}
      
      # Create a process that will exit after a short time
      pid = spawn(fn -> Process.sleep(100) end)
      
      # Register it
      :ok = DistributedRegistry.register(test_key, pid)
      
      # Initially lookup should find it
      assert DistributedRegistry.lookup(test_key) == [pid]
      
      # Wait for process to exit
      :timer.sleep(200)
      
      # Lookup should not find it anymore
      assert DistributedRegistry.lookup(test_key) == []
    end
    
    @tag :distributed
    test "works across nodes", %{nodes: [node1, node2]} do
      # Create a process on node1
      {pid1, test_key} = on_node(node1, fn ->
        test_key = {:test, "node1-process"}
        :ok = DistributedRegistry.register(test_key)
        {self(), test_key}
      end)
      
      # Wait for synchronization
      :timer.sleep(500)
      
      # Lookup from node2 should find the process on node1
      result = call_on(node2, DistributedRegistry, :lookup, [test_key])
      
      # Result contains the remote PID
      assert length(result) == 1
      [found_pid] = result
      
      # Convert PIDs to strings for comparison (since PIDs from different nodes don't compare directly)
      assert inspect(found_pid) == inspect(pid1)
    end
    
    @tag :distributed
    test "synchronizes registrations across joining nodes", %{nodes: [node1, node2]} do
      # Register on node1
      test_key = {:test, "sync-test"}
      pid1 = on_node(node1, fn ->
        :ok = DistributedRegistry.register(test_key)
        self()
      end)
      
      # Wait for synchronization
      :timer.sleep(500)
      
      # Start a third node and connect it
      {:ok, [node3]} = start_nodes(1)
      connect_nodes([node1, node2, node3])
      
      # Load code on node3
      load_automata(node3)
      
      # Start registry on node3
      call_on(node3, Application, :ensure_all_started, [:automata])
      
      # Wait for synchronization
      :timer.sleep(1000)
      
      # Lookup from node3 should find the process on node1
      result = call_on(node3, DistributedRegistry, :lookup, [test_key])
      
      # Result contains the remote PID
      assert length(result) == 1
      [found_pid] = result
      
      # Convert PIDs to strings for comparison
      assert inspect(found_pid) == inspect(pid1)
      
      # Clean up
      stop_nodes([node3])
    end
    
    @tag :distributed
    test "handles node failures", %{nodes: [node1, node2]} do
      # Register on node2
      test_key = {:test, "node-failure"}
      _pid = on_node(node2, fn ->
        :ok = DistributedRegistry.register(test_key)
        self()
      end)
      
      # Wait for synchronization
      :timer.sleep(500)
      
      # Verify registration is visible on node1
      result_before = call_on(node1, DistributedRegistry, :lookup, [test_key])
      assert length(result_before) == 1
      
      # Kill node2
      stop_nodes([node2])
      
      # Wait for failure detection
      :timer.sleep(1000)
      
      # Verify registration is removed on node1
      result_after = call_on(node1, DistributedRegistry, :lookup, [test_key])
      assert result_after == []
    end
  end
end