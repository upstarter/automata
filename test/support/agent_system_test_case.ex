defmodule Automata.Test.AgentSystemTestCase do
  @moduledoc """
  A helper module for testing the agent system.
  
  This module provides utilities for:
  - Creating and managing agents
  - Observing agent behavior
  - Testing agent interactions
  
  ## Example
  
  ```elixir
  defmodule MyAgentTest do
    use Automata.Test.AgentSystemTestCase
    
    test "agent processes ticks correctly" do
      agent_id = create_test_agent(:behavior_tree)
      
      # Send ticks to the agent
      tick_agent(agent_id)
      
      # Assert on agent state
      assert_agent_status(agent_id, :ready)
    end
  end
  ```
  """
  
  use ExUnit.CaseTemplate
  
  alias Automata.Infrastructure.AgentSystem.{AgentServer, Registry}
  alias Automata.Infrastructure.State.DistributedBlackboard
  alias Automata.Test.Mocks
  alias Automata.Test.AssertUtils
  
  using do
    quote do
      import Automata.Test.AgentSystemTestCase
      import Automata.Test.AssertUtils
      
      # Start Blackboard and Registry for tests
      setup do
        # Register mock agent type
        Registry.register(Automata.Test.Mocks.MockAgent)
        
        # Clean blackboard before each test
        clean_blackboard()
        
        :ok
      end
    end
  end
  
  # Test Setup
  
  @doc """
  Cleans the distributed blackboard before tests.
  """
  def clean_blackboard do
    # Find all agent entries
    keys = DistributedBlackboard.get_all()
    |> Enum.filter(fn {{type, _}, _} -> type == :agent end)
    |> Enum.map(fn {key, _} -> key end)
    
    # Remove each one
    Enum.each(keys, &DistributedBlackboard.delete/1)
  end
  
  # Agent Management
  
  @doc """
  Creates a test agent with the specified type.
  
  Returns the agent ID if successful.
  
  ## Options
  
  - `:world_id` - World ID for the agent (default: "test-world")
  - `:node_type` - Node type for behavior tree agents (default: :sequence)
  - `:tick_freq` - Tick frequency for the agent (default: 50)
  - `:settings` - Additional settings for the agent (default: %{})
  - `:auto_tick` - Whether to automatically tick the agent (default: false)
  """
  def create_test_agent(type, opts \\ []) do
    agent_id = "test-agent-#{System.unique_integer([:positive])}"
    world_id = Keyword.get(opts, :world_id, "test-world")
    
    # Create agent config
    config = case type do
      :behavior_tree ->
        node_type = Keyword.get(opts, :node_type, :sequence)
        
        %{
          id: agent_id,
          type: :behavior_tree,
          node_type: node_type,
          world_id: world_id,
          tick_freq: Keyword.get(opts, :tick_freq, 50),
          settings: Keyword.get(opts, :settings, %{}),
          auto_tick: Keyword.get(opts, :auto_tick, false),
          children: Keyword.get(opts, :children, [])
        }
        
      :mock_agent ->
        %{
          id: agent_id,
          type: :mock_agent,
          world_id: world_id,
          tick_freq: Keyword.get(opts, :tick_freq, 50),
          settings: Keyword.get(opts, :settings, %{}),
          auto_tick: Keyword.get(opts, :auto_tick, false)
        }
        
      other ->
        %{
          id: agent_id,
          type: other,
          world_id: world_id,
          tick_freq: Keyword.get(opts, :tick_freq, 50),
          settings: Keyword.get(opts, :settings, %{}),
          auto_tick: Keyword.get(opts, :auto_tick, false)
        }
    end
    
    # Start the agent
    {:ok, _pid} = AgentServer.start_agent(agent_id, world_id, config)
    
    # Wait for agent to initialize
    AssertUtils.assert_eventually(fn ->
      AgentServer.status(agent_id) in [:ready, :running]
    end)
    
    agent_id
  end
  
  @doc """
  Sends a tick to an agent.
  
  ## Options
  
  - `:wait` - Whether to wait for the tick to complete (default: true)
  - `:timeout` - Timeout for waiting (default: 1000 ms)
  """
  def tick_agent(agent_id, opts \\ []) do
    wait = Keyword.get(opts, :wait, true)
    timeout = Keyword.get(opts, :timeout, 1000)
    
    # Get initial tick count
    initial_info = AgentServer.info(agent_id)
    initial_count = initial_info.tick_count
    
    # Send tick
    AgentServer.tick(agent_id)
    
    if wait do
      # Wait for tick to complete
      AssertUtils.assert_eventually(fn ->
        info = AgentServer.info(agent_id)
        info.tick_count > initial_count
      end, timeout: timeout, message: "Tick did not complete within #{timeout}ms")
    end
    
    :ok
  end
  
  @doc """
  Stops an agent.
  
  ## Options
  
  - `:reason` - Reason for stopping (default: :normal)
  - `:wait` - Whether to wait for the agent to stop (default: true)
  - `:timeout` - Timeout for waiting (default: 1000 ms)
  """
  def stop_agent(agent_id, opts \\ []) do
    reason = Keyword.get(opts, :reason, :normal)
    wait = Keyword.get(opts, :wait, true)
    timeout = Keyword.get(opts, :timeout, 1000)
    
    # Get pid
    pid = Process.whereis(via_tuple(agent_id))
    
    # Stop agent
    if pid && Process.alive?(pid) do
      AgentServer.stop(agent_id, reason)
      
      if wait do
        # Wait for agent to stop
        AssertUtils.assert_eventually(fn ->
          Process.whereis(via_tuple(agent_id)) == nil
        end, timeout: timeout, message: "Agent did not stop within #{timeout}ms")
      end
    end
    
    :ok
  end
  
  # Assertions
  
  @doc """
  Asserts that an agent has the expected status.
  
  ## Options
  
  - `:timeout` - Maximum time to wait for the status (default: 1000 ms)
  """
  def assert_agent_status(agent_id, expected_status, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    
    AssertUtils.assert_eventually(fn ->
      AgentServer.status(agent_id) == expected_status
    end, timeout: timeout, message: "Agent #{agent_id} did not reach status #{expected_status} within #{timeout}ms")
  end
  
  @doc """
  Asserts that an agent's tick count is at least the expected value.
  
  ## Options
  
  - `:timeout` - Maximum time to wait for the tick count (default: 1000 ms)
  """
  def assert_agent_tick_count(agent_id, min_count, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    
    AssertUtils.assert_eventually(fn ->
      info = AgentServer.info(agent_id)
      info.tick_count >= min_count
    end, timeout: timeout, message: "Agent #{agent_id} did not reach tick count #{min_count} within #{timeout}ms")
  end
  
  @doc """
  Asserts that an agent is registered in the blackboard.
  
  ## Options
  
  - `:timeout` - Maximum time to wait for registration (default: 1000 ms)
  """
  def assert_agent_in_blackboard(agent_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    
    AssertUtils.assert_eventually(fn ->
      case DistributedBlackboard.get({:agent, agent_id}) do
        nil -> false
        _ -> true
      end
    end, timeout: timeout, message: "Agent #{agent_id} was not registered in blackboard within #{timeout}ms")
  end
  
  # Private helpers
  
  defp via_tuple(id) do
    {:via, Registry, {Automata.Infrastructure.AgentSystem.AgentRegistry, id}}
  end
end