# Test script for the Automata Foundation Phase
# Run with: elixir -S mix run test_foundation.exs

IO.puts "Starting Automata Foundation Phase test..."

# Ensure application is started
Application.ensure_all_started(:automata)

# Create a test world
{status, world_id} = Automata.create_world(%{
  name: "TestWorld",
  settings: %{
    mode: :development
  }
})

IO.puts "Created world with ID: #{world_id}, status: #{status}"

# Create a test agent
{agent_status, agent_id} = Automata.spawn_agent(world_id, %{
  type: :behavior_tree,
  node_type: :sequence,
  tick_freq: 1000,
  children: []
})

IO.puts "Created agent with ID: #{agent_id}, status: #{agent_status}"

# Wait a moment for everything to initialize
Process.sleep(1000)

# Check world status
world_status = Automata.world_status(world_id)
IO.puts "World status: #{inspect world_status}"

# Check agent status
agent_status = Automata.agent_status(agent_id)
IO.puts "Agent status: #{inspect agent_status}"

# Get system metrics
metrics = Automata.metrics()
IO.puts "System metrics: #{inspect metrics, pretty: true}"

# Get system health
health = Automata.health()
IO.puts "System health: #{inspect health, pretty: true}"

# Tick the agent
Automata.tick_agent(agent_id)
IO.puts "Sent tick to agent: #{agent_id}"

# Wait a moment for the tick to process
Process.sleep(500)

# Check agent status again after tick
agent_status_after_tick = Automata.agent_status(agent_id)
IO.puts "Agent status after tick: #{inspect agent_status_after_tick}"

IO.puts "Test completed successfully!"