defmodule Automata.Integration.DistributedAgentSystemTest do
  use Automata.Test.DistributedTestCase
  
  alias Automata.Infrastructure.AgentSystem.{AgentServer, Registry}
  alias Automata.Infrastructure.State.DistributedBlackboard
  alias Automata.Test.Mocks
  
  @moduletag :distributed
  
  setup %{nodes: [node1, node2]} do
    # Register mock agent on both nodes
    call_on(node1, Registry, :register, [Mocks.MockAgent])
    call_on(node2, Registry, :register, [Mocks.MockAgent])
    
    :ok
  end
  
  describe "multi-node agent system" do
    @tag node_count: 3
    test "agents can be distributed across nodes", %{nodes: [node1, node2, node3]} do
      # Create agents on different nodes
      agent1_id = "agent-1-#{System.unique_integer([:positive])}"
      agent2_id = "agent-2-#{System.unique_integer([:positive])}"
      agent3_id = "agent-3-#{System.unique_integer([:positive])}"
      
      # Configuration for test agents
      config = %{
        type: :mock_agent,
        world_id: "test-world",
        tick_freq: 50,
        settings: %{}
      }
      
      # Start agents on different nodes
      {:ok, _} = call_on(node1, AgentServer, :start_agent, [agent1_id, "test-world", config])
      {:ok, _} = call_on(node2, AgentServer, :start_agent, [agent2_id, "test-world", config])
      {:ok, _} = call_on(node3, AgentServer, :start_agent, [agent3_id, "test-world", config])
      
      # Wait for agents to initialize
      wait_for_agents_ready([
        {node1, agent1_id},
        {node2, agent2_id},
        {node3, agent3_id}
      ])
      
      # Verify agents are registered in the distributed blackboard
      # from any node in the cluster
      assert_eventually fn ->
        blackboard_entries = call_on(node1, DistributedBlackboard, :get_all, [])
        
        # Check if all agents are in the blackboard
        Enum.all?([agent1_id, agent2_id, agent3_id], fn id ->
          Enum.any?(blackboard_entries, fn {{:agent, agent_id}, _data} ->
            agent_id == id
          end)
        end)
      end
      
      # Send ticks to agents from different nodes
      call_on(node2, AgentServer, :tick, [agent1_id]) # Tick agent1 from node2
      call_on(node3, AgentServer, :tick, [agent2_id]) # Tick agent2 from node3
      call_on(node1, AgentServer, :tick, [agent3_id]) # Tick agent3 from node1
      
      # Wait for ticks to be processed
      :timer.sleep(500)
      
      # Check tick counts
      assert_agent_tick_count_on_node(node1, agent1_id, 1)
      assert_agent_tick_count_on_node(node1, agent2_id, 1)
      assert_agent_tick_count_on_node(node1, agent3_id, 1)
    end
    
    test "handles node failures gracefully", %{nodes: [node1, node2]} do
      # Create an agent on node2
      agent_id = "agent-failure-#{System.unique_integer([:positive])}"
      
      # Configuration for test agent
      config = %{
        type: :mock_agent,
        world_id: "test-world",
        tick_freq: 50,
        settings: %{}
      }
      
      # Start agent on node2
      {:ok, _} = call_on(node2, AgentServer, :start_agent, [agent_id, "test-world", config])
      
      # Wait for agent to initialize
      wait_for_agents_ready([{node2, agent_id}])
      
      # Verify agent is registered in the distributed blackboard
      assert_eventually fn ->
        blackboard_entry = call_on(node1, DistributedBlackboard, :get, [{:agent, agent_id}])
        blackboard_entry != nil
      end
      
      # Kill node2
      stop_nodes([node2])
      
      # Wait for node failure to be detected
      :timer.sleep(1000)
      
      # Verify agent state is preserved in the blackboard
      assert_eventually fn ->
        blackboard_entry = call_on(node1, DistributedBlackboard, :get, [{:agent, agent_id}])
        blackboard_entry != nil
      end
    end
  end
  
  # Helper functions
  
  defp wait_for_agents_ready(agent_nodes) do
    assert_eventually fn ->
      Enum.all?(agent_nodes, fn {node, agent_id} ->
        status = call_on(node, AgentServer, :status, [agent_id])
        status in [:ready, :running]
      end)
    end, timeout: 5000
  end
  
  defp assert_agent_tick_count_on_node(node, agent_id, min_count) do
    assert_eventually fn ->
      info = call_on(node, AgentServer, :info, [agent_id])
      info.tick_count >= min_count
    end, timeout: 5000
  end
end