defmodule Automata.Infrastructure.AgentSystem.AgentServerTest do
  use ExUnit.Case
  use Automata.Test.AgentSystemTestCase
  
  alias Automata.Infrastructure.AgentSystem.AgentServer
  alias Automata.Test.Mocks
  
  setup do
    # Register mock agent type if not already registered
    Registry.register(Mocks.MockAgent)
    :ok
  end
  
  describe "agent lifecycle" do
    test "starts and initializes properly" do
      # Create a test agent
      agent_id = create_test_agent(:mock_agent)
      
      # Check status
      assert_agent_status(agent_id, :ready)
      
      # Check blackboard registration
      assert_agent_in_blackboard(agent_id)
      
      # Get agent info
      info = AgentServer.info(agent_id)
      assert info.id == agent_id
      assert info.type == :mock_agent
      assert info.status == :ready
      assert info.tick_count == 0
    end
    
    test "processes ticks" do
      # Create a test agent
      agent_id = create_test_agent(:mock_agent)
      
      # Send ticks
      tick_agent(agent_id)
      tick_agent(agent_id)
      tick_agent(agent_id)
      
      # Check tick count
      assert_agent_tick_count(agent_id, 3)
      
      # Get agent info
      info = AgentServer.info(agent_id)
      assert info.tick_count == 3
    end
    
    test "auto-ticks when configured" do
      # Create a test agent with auto_tick enabled
      agent_id = create_test_agent(:mock_agent, auto_tick: true)
      
      # Wait for ticks to accumulate
      assert_agent_tick_count(agent_id, 3, timeout: 5000)
    end
    
    test "stops cleanly" do
      # Create a test agent
      agent_id = create_test_agent(:mock_agent)
      
      # Stop the agent
      stop_agent(agent_id)
      
      # Check that agent process is gone
      assert Process.whereis(via_tuple(agent_id)) == nil
      
      # Check blackboard is updated with terminated status
      assert_eventually fn ->
        case DistributedBlackboard.get({:agent, agent_id}) do
          nil -> false
          data -> data.status == :terminated
        end
      end
    end
  end
  
  describe "behavior tree agents" do
    test "executes a simple sequence" do
      # Create a behavior tree agent with a sequence node
      agent_id = create_test_agent(:behavior_tree, 
        node_type: :sequence,
        children: [
          %{
            type: :behavior_tree,
            node_type: :action,
            settings: %{
              action_name: "test_action",
              action_handler: Mocks.MockActionHandler,
              parameters: %{iterations: 2}
            }
          }
        ]
      )
      
      # Send ticks - first tick will start the action
      tick_agent(agent_id)
      
      # Check status
      assert_agent_status(agent_id, :running)
      
      # Second tick will complete the action
      tick_agent(agent_id)
      
      # Check status
      assert_agent_status(agent_id, :ready)
    end
    
    test "handles immediate completion" do
      # Create a behavior tree agent with an action that completes immediately
      agent_id = create_test_agent(:behavior_tree, 
        node_type: :action,
        settings: %{
          action_name: "immediate_action",
          action_handler: Mocks.MockActionHandler,
          parameters: %{immediate: true}
        }
      )
      
      # Send tick
      tick_agent(agent_id)
      
      # Check status - should be ready since action completed immediately
      assert_agent_status(agent_id, :ready)
    end
    
    test "handles failures" do
      # Create a behavior tree agent with an action that fails
      agent_id = create_test_agent(:behavior_tree, 
        node_type: :action,
        settings: %{
          action_name: "failing_action",
          action_handler: Mocks.MockActionHandler,
          parameters: %{fail: true}
        }
      )
      
      # Send tick
      tick_agent(agent_id)
      
      # Check status - should be ready (failure state handled)
      assert_agent_status(agent_id, :ready)
      
      # Check info for error
      info = AgentServer.info(agent_id)
      assert info.error_count > 0
    end
  end
  
  # Helper functions
  
  defp via_tuple(id) do
    {:via, Registry, {Automata.Infrastructure.AgentSystem.AgentRegistry, id}}
  end
end