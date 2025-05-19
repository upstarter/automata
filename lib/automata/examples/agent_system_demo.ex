defmodule Automata.Examples.AgentSystemDemo do
  @moduledoc """
  Demonstrates the extensible agent system.
  
  This module provides examples of how to use the new extensible agent system
  to create and manage agents of different types.
  
  To run this demo, execute:
  ```
  iex -S mix
  Automata.Examples.AgentSystemDemo.run()
  ```
  """
  
  alias Automata.Infrastructure.AgentSystem.{Registry, AgentServer}
  
  @doc """
  Runs the agent system demonstration.
  """
  def run do
    IO.puts("\n=== Automata Extensible Agent System Demo ===\n")
    
    # Initialize agent system
    IO.puts("Initializing agent system...")
    :ok = Automata.Infrastructure.AgentSystem.Supervisor.register_agent_types()
    
    # List registered agent types
    IO.puts("\n--- Available Agent Types ---")
    agent_types = Registry.list_types()
    
    Enum.each(agent_types, fn type ->
      IO.puts("• #{type.type}: #{type.description}")
      
      if type.features && length(type.features) > 0 do
        feature_list = Enum.map_join(type.features, ", ", &to_string/1)
        IO.puts("  Features: #{feature_list}")
      end
    end)
    
    # Create a behavior tree agent
    IO.puts("\n--- Creating Behavior Tree Agent ---")
    
    bt_config = %{
      type: :behavior_tree,
      node_type: :sequence,
      settings: %{
        description: "Simple demo behavior tree"
      },
      children: [
        %{
          type: :behavior_tree,
          node_type: :action,
          settings: %{
            action_name: "demo_action",
            action_handler: Automata.Examples.AgentSystemDemo.DemoActionHandler,
            parameters: %{
              iterations: 3
            }
          }
        }
      ]
    }
    
    # Validate configuration
    case Registry.validate_config(bt_config) do
      {:ok, validated_config} ->
        IO.puts("Configuration validated successfully")
        
        # Start agent
        agent_id = "demo-agent-#{System.unique_integer([:positive])}"
        world_id = "demo-world"
        
        case AgentServer.start_agent(agent_id, world_id, validated_config) do
          {:ok, _pid} ->
            IO.puts("Agent started successfully with ID: #{agent_id}")
            
            # Wait for agent to initialize
            :timer.sleep(100)
            
            # Get agent status
            status = AgentServer.status(agent_id)
            IO.puts("Agent status: #{status}")
            
            # Get agent info
            info = AgentServer.info(agent_id)
            IO.puts("\nAgent info:")
            IO.puts("  ID: #{info.id}")
            IO.puts("  World: #{info.world_id}")
            IO.puts("  Type: #{info.type}")
            IO.puts("  Status: #{info.status}")
            IO.puts("  Uptime: #{div(info.uptime_ms, 1000)} seconds")
            
            # Send ticks to the agent
            IO.puts("\nSending ticks to the agent...")
            
            Enum.each(1..5, fn i ->
              IO.puts("  Tick #{i}...")
              AgentServer.tick(agent_id)
              :timer.sleep(500)
              
              # Get updated info
              updated_info = AgentServer.info(agent_id)
              IO.puts("  Agent status: #{updated_info.status}, " <>
                "Tick count: #{updated_info.tick_count}")
            end)
            
            # Stop the agent
            IO.puts("\nStopping the agent...")
            AgentServer.stop(agent_id)
            :timer.sleep(100)
            
          {:error, reason} ->
            IO.puts("Failed to start agent: #{inspect(reason)}")
        end
        
      {:error, reason} ->
        IO.puts("Configuration validation failed: #{inspect(reason)}")
    end
    
    IO.puts("\n=== Demo Complete ===\n")
    :ok
  end
  
  # Demo action handler
  defmodule DemoActionHandler do
    @moduledoc """
    Demo action handler for the agent system demo.
    
    This module implements a simple action handler that simulates
    a long-running operation for demonstration purposes.
    """
    
    @doc """
    Starts the action execution.
    """
    def start(context) do
      IO.puts("  Starting demo action with parameters: #{inspect(context.parameters)}")
      
      # Generate action ID
      action_id = "action-#{System.unique_integer([:positive])}"
      
      # Store execution state in process dictionary
      # (In a real implementation, you would use a proper state store)
      Process.put({:demo_action, action_id}, %{
        started_at: System.system_time(:millisecond),
        iterations: context.parameters.iterations,
        current_iteration: 0,
        completed: false
      })
      
      # Return action ID
      {:ok, action_id}
    end
    
    @doc """
    Checks the status of the action.
    """
    def check_status(context) do
      # Get execution state
      action_id = context.action_id
      state = Process.get({:demo_action, action_id})
      
      if is_nil(state) do
        # Action not found
        {:error, :action_not_found}
      else
        if state.completed do
          # Action already completed
          {:complete, :success, %{demo_result: "Action completed successfully"}}
        else
          # Increment iteration counter
          current_iteration = state.current_iteration + 1
          
          # Update state
          new_state = %{state | current_iteration: current_iteration}
          Process.put({:demo_action, action_id}, new_state)
          
          # Check if action is complete
          if current_iteration >= state.iterations do
            # Mark as completed
            Process.put({:demo_action, action_id}, %{new_state | completed: true})
            
            # Return completion
            {:complete, :success, %{
              demo_result: "Action completed after #{current_iteration} iterations"
            }}
          else
            # Still running
            {:running, %{
              demo_progress: "#{current_iteration}/#{state.iterations} iterations"
            }}
          end
        end
      end
    end
  end
end