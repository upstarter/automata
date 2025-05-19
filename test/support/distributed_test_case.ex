defmodule Automata.Test.DistributedTestCase do
  @moduledoc """
  A helper module for testing distributed features of the Automata system.
  
  This module provides utilities for:
  - Starting and stopping multiple nodes
  - Connecting nodes in a cluster
  - Running tasks across nodes
  - Observing distributed state
  
  ## Example
  
  ```elixir
  defmodule MyDistributedTest do
    use Automata.Test.DistributedTestCase
    
    test "distributes state across nodes", %{nodes: [node1, node2]} do
      # Start your distributed components
      {:ok, _} = start_supervised_on(node1, {MyComponent, [name: :my_component]})
      
      # Test that they can work together
      assert call_on(node2, MyComponent, :get_state, []) == :expected_state
    end
  end
  ```
  """
  
  use ExUnit.CaseTemplate
  
  @default_cookie :automata_test
  
  using do
    quote do
      import Automata.Test.DistributedTestCase
      
      # Import additional test utilities
      import Automata.Test.AssertUtils
      
      # Define setup helpers that can be used in tests
      setup context do
        # Start nodes if requested
        node_count = Map.get(context, :node_count, 2)
        
        if Map.get(context, :distributed, true) do
          {:ok, nodes} = start_nodes(node_count)
          on_exit(fn -> stop_nodes(nodes) end)
          
          # Connect the nodes in a cluster
          connect_nodes(nodes)
          
          # Add nodes to context
          Map.put(context, :nodes, nodes)
        else
          context
        end
      end
    end
  end
  
  # Node Management
  
  @doc """
  Starts multiple Elixir nodes for distributed testing.
  
  Returns `{:ok, [node1, node2, ...]}` if successful,
  or `{:error, reason}` if node creation fails.
  
  ## Options
  
  - `:prefix` - Prefix for node names (default: "automata_test")
  - `:cookie` - Cookie for node authentication (default: :automata_test)
  """
  def start_nodes(count, opts \\ []) when is_integer(count) and count > 0 do
    prefix = Keyword.get(opts, :prefix, "automata_test")
    cookie = Keyword.get(opts, :cookie, @default_cookie)
    
    # Generate unique names for nodes
    node_names = Enum.map(1..count, fn i ->
      :"#{prefix}_#{i}_#{System.unique_integer([:positive])}"
    end)
    
    # Start nodes
    nodes = Enum.map(node_names, fn name ->
      {:ok, node} = :slave.start(host(), name, erl_flags(cookie))
      node
    end)
    
    # Load code on each node
    Enum.each(nodes, &load_automata/1)
    
    {:ok, nodes}
  end
  
  @doc """
  Stops nodes that were started for testing.
  """
  def stop_nodes(nodes) when is_list(nodes) do
    Enum.each(nodes, fn node ->
      :slave.stop(node)
    end)
  end
  
  @doc """
  Connects nodes to form a cluster.
  """
  def connect_nodes(nodes) when is_list(nodes) do
    # Make all nodes visible to each other
    Enum.each(nodes, fn node ->
      Enum.each(List.delete(nodes, node), fn other_node ->
        :rpc.call(node, Node, :connect, [other_node])
      end)
    end)
    
    # Wait for connections to establish
    :timer.sleep(100)
    
    # Verify connections
    Enum.all?(nodes, fn node ->
      visible = :rpc.call(node, Node, :list, [])
      length(visible) >= length(nodes) - 1
    end)
  end
  
  # RPC Helpers
  
  @doc """
  Calls a function on a remote node.
  
  Returns the result of the function call.
  """
  def call_on(node, module, function, args) when is_atom(node) and is_atom(module) and is_atom(function) and is_list(args) do
    :rpc.call(node, module, function, args)
  end
  
  @doc """
  Starts a supervised process on a remote node.
  
  Returns the result of the start_supervised operation.
  """
  def start_supervised_on(node, spec) when is_atom(node) do
    :rpc.call(node, ExUnit.Callbacks, :start_supervised, [spec])
  end
  
  @doc """
  Executes a function on a remote node and waits for the result.
  
  This is useful for more complex operations that need to be performed
  on a specific node.
  """
  def on_node(node, fun) when is_atom(node) and is_function(fun, 0) do
    parent = self()
    ref = make_ref()
    
    :rpc.call(node, Node, :spawn, [fn ->
      result = fun.()
      send(parent, {ref, result})
    end])
    
    receive do
      {^ref, result} -> result
    after
      30_000 -> raise "Timeout waiting for result from node #{node}"
    end
  end
  
  # Private helpers
  
  defp host do
    host = to_string(:net_adm.localhost())
    
    case :inet.gethostbyname(to_charlist(host)) do
      {:ok, {:hostent, host, _, _, _, _}} -> host
      _ -> raise "Could not resolve host"
    end
  end
  
  defp erl_flags(cookie) do
    "-setcookie #{cookie} -connect_all false -kernel dist_auto_connect never"
  end
  
  defp load_automata(node) do
    # Get the current code path
    code_path = :code.get_path()
    
    # Add code paths on the remote node
    :rpc.call(node, :code, :add_paths, [code_path])
    
    # Start required applications on the remote node
    :rpc.call(node, Application, :ensure_all_started, [:mix])
    :rpc.call(node, Application, :ensure_all_started, [:logger])
    
    # Sync the configuration
    :rpc.call(node, Application, :put_all_env, [
      :automata,
      Application.get_all_env(:automata)
    ])
    
    # Start the Automata application on the remote node
    :rpc.call(node, Application, :ensure_all_started, [:automata])
  end
end