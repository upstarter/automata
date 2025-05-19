defmodule Automata.Examples.CompatibilityExample do
  @moduledoc """
  This example demonstrates how to use both the legacy API (via adapters)
  and the new architecture API side by side.
  
  It shows how to:
  1. Run the same agent system using both APIs
  2. Compare the differences in code structure and API usage
  3. Migrate incrementally from the old to the new architecture
  """
  
  @doc """
  Runs the legacy example using the compatibility adapter.
  """
  def run_legacy_example do
    IO.puts("===== Running Legacy Example =====")
    
    # Define world configuration (old style)
    world_config = %{
      name: :legacy_world,
      type: :mock,
      config: %{
        description: "Legacy world example"
      }
    }
    
    # Define automaton configuration (old style)
    automaton_config = %{
      name: :legacy_automaton,
      type: :behavior_tree,
      initial_state: %{counter: 0},
      root: :sequence_node,
      nodes: [
        %{
          id: :sequence_node,
          type: :sequence,
          children: [:increment_counter, :print_counter]
        },
        %{
          id: :increment_counter,
          type: :action,
          module: Automata.Examples.LegacyIncrementAction,
          config: %{}
        },
        %{
          id: :print_counter,
          type: :action,
          module: Automata.Examples.LegacyPrintAction,
          config: %{}
        }
      ]
    }
    
    # Start the system using legacy API
    {:ok, _} = Automata.legacy_start(world_config)
    IO.puts("Legacy world started")
    
    # Start automaton using legacy API
    {:ok, automaton_pid} = Automata.legacy_start_automaton(automaton_config)
    IO.puts("Legacy automaton started")
    
    # Send tick to the automaton (legacy style)
    send(automaton_pid, :tick)
    :timer.sleep(100) # Give it time to process
    
    # Cleanup
    :ok = Automata.legacy_stop_automaton(automaton_config[:name])
    IO.puts("Legacy automaton stopped")
    
    :ok
  end
  
  @doc """
  Runs the modern example using the new architecture.
  """
  def run_modern_example do
    IO.puts("===== Running Modern Example =====")
    
    # Define world configuration (new style)
    world_config = %{
      name: "modern_world",
      description: "Modern world example",
      settings: %{
        max_agents: 10,
        tick_rate: 1
      },
      environment: %{
        type: "simulated"
      }
    }
    
    # Define agent configuration (new style)
    agent_config = %{
      name: "modern_agent",
      type: "behavior_tree",
      state: %{
        counter: 0
      },
      behavior: %{
        root: "sequence_node",
        nodes: [
          %{
            id: "sequence_node",
            type: "sequence",
            children: ["increment_counter", "print_counter"]
          },
          %{
            id: "increment_counter",
            type: "action",
            module: "Automata.Examples.ModernIncrementAction",
            config: %{}
          },
          %{
            id: "print_counter",
            type: "action",
            module: "Automata.Examples.ModernPrintAction",
            config: %{}
          }
        ]
      }
    }
    
    # Create world using new API
    {:ok, world_id} = Automata.create_world(world_config)
    IO.puts("Modern world created with ID: #{world_id}")
    
    # Spawn agent using new API
    {:ok, agent_id} = Automata.spawn_agent(world_id, agent_config)
    IO.puts("Modern agent spawned with ID: #{agent_id}")
    
    # Tick the agent using new API
    Automata.tick_agent(agent_id)
    :timer.sleep(100) # Give it time to process
    
    # Check agent status
    status = Automata.agent_status(agent_id)
    IO.puts("Modern agent status: #{status}")
    
    # Cleanup
    :ok = Automata.stop_world(world_id)
    IO.puts("Modern world stopped")
    
    :ok
  end
  
  @doc """
  Runs both examples to compare their output.
  """
  def run_comparison do
    run_legacy_example()
    IO.puts("\n")
    run_modern_example()
  end
end

# Legacy actions using the old architecture style
defmodule Automata.Examples.LegacyIncrementAction do
  use Automaton.Types.BT.Action
  
  def init(_) do
    {:ok, %{}}
  end
  
  def update(blackboard, state) do
    # Increment the counter in the blackboard
    new_blackboard = Map.update(blackboard, :counter, 1, &(&1 + 1))
    
    # Return success with updated blackboard
    {:success, new_blackboard, state}
  end
end

defmodule Automata.Examples.LegacyPrintAction do
  use Automaton.Types.BT.Action
  
  def init(_) do
    {:ok, %{}}
  end
  
  def update(blackboard, state) do
    # Print the counter value
    IO.puts("Legacy counter value: #{blackboard[:counter]}")
    
    # Return success without changing the blackboard
    {:success, blackboard, state}
  end
end

# Modern actions using the new architecture style
defmodule Automata.Examples.ModernIncrementAction do
  use Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Action
  
  def init(_) do
    {:ok, %{}}
  end
  
  def update(context, state) do
    # Get current agent state from context
    agent_state = context.agent_state
    
    # Increment the counter in the agent state
    new_agent_state = Map.update(agent_state, :counter, 1, &(&1 + 1))
    
    # Return success with updated agent state
    {:success, new_agent_state, state}
  end
end

defmodule Automata.Examples.ModernPrintAction do
  use Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Action
  
  def init(_) do
    {:ok, %{}}
  end
  
  def update(context, state) do
    # Get current agent state from context
    agent_state = context.agent_state
    
    # Print the counter value
    IO.puts("Modern counter value: #{agent_state[:counter]}")
    
    # Return success without changing the agent state
    {:success, agent_state, state}
  end
end