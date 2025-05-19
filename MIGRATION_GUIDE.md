# Migration Guide: From Core to Distributed Architecture

This guide helps you migrate your code from Automata's original core architecture to the new distributed architecture.

## Overview

Automata has undergone a major architectural redesign to support:

- Full distribution across multiple nodes
- Enhanced fault tolerance and self-healing
- Better separation of concerns
- More flexible agent models
- Improved performance and scalability

This migration guide will help you transition your existing code to use the new architecture.

## Migration Approaches

You have two approaches to migrate:

1. **Adapter Approach**: Use the compatibility adapter layer (minimal code changes, recommended for existing applications)
2. **Full Migration**: Fully migrate to the new architecture (more code changes, recommended for new applications)

## Using the Compatibility Layer

The compatibility layer is provided through the `Automata.CoreAdapter` module and legacy functions in the main `Automata` module.

### Step 1: Update your dependencies

Ensure your `mix.exs` file has the latest version of Automata:

```elixir
def deps do
  [
    {:automata, "~> 2.0"}
  ]
end
```

### Step 2: Update your code to use the legacy API

Change from:

```elixir
# Starting the system
Automata.Operator.run(world_config)

# Starting an automaton
Automata.Server.start_automaton(automaton_config)

# Stopping an automaton
Automata.Server.stop_automaton(:my_automaton)

# Listing automata
Automata.Server.list_automata()
```

To:

```elixir
# Starting the system
Automata.legacy_start(world_config)

# Starting an automaton
Automata.legacy_start_automaton(automaton_config)

# Stopping an automaton
Automata.legacy_stop_automaton(:my_automaton)

# Listing automata
Automata.legacy_list_automata()
```

## Full Migration to New Architecture

For new applications or when you want to fully migrate to the new architecture, follow these steps:

### Step 1: Update World Configuration

Replace:

```elixir
world_config = %{
  name: :my_world,
  # Other configuration
}

Automata.Operator.run(world_config)
```

With:

```elixir
world_config = %{
  name: "my_world",
  description: "My world description",
  # Other configuration
}

{:ok, world_id} = Automata.create_world(world_config)
```

### Step 2: Update Agent Creation

Replace:

```elixir
automaton_config = %{
  name: :my_agent,
  type: :behavior_tree,
  # Other configuration
}

Automata.Server.start_automaton(automaton_config)
```

With:

```elixir
agent_config = %{
  name: "my_agent",
  type: "behavior_tree",
  # Other configuration
}

{:ok, agent_id} = Automata.spawn_agent(world_id, agent_config)
```

### Step 3: Update Agent Interaction

Replace:

```elixir
# Send a message to an agent
send(MyAgentServer, :tick)

# Get agent state
state = :sys.get_state(MyAgentServer)
```

With:

```elixir
# Send a tick to an agent
Automata.tick_agent(agent_id)

# Get agent status
status = Automata.agent_status(agent_id)
```

## Behavior Tree Migration

If you're using behavior trees, you'll need to update your node definitions:

### Old Style:

```elixir
defmodule MyAction do
  use Automaton.Types.BT.Action

  def init(_) do
    {:ok, %{}}
  end

  def update(_blackboard, state) do
    # Action logic
    {:success, state}
  end
end
```

### New Style:

```elixir
defmodule MyAction do
  use Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Action

  def init(_) do
    {:ok, %{}}
  end

  def update(_context, state) do
    # Action logic
    {:success, state}
  end
end
```

## Configuration Schema Changes

The new architecture uses strict schema validation. Configuration now looks like:

```elixir
world_config = %{
  name: "my_world",
  description: "My world description",
  settings: %{
    max_agents: 100,
    tick_rate: 20
  },
  environment: %{
    type: "simulated",
    dimensions: [100, 100]
  }
}
```

## Testing Changes

Update your tests to use the new agent API:

```elixir
test "agent behavior" do
  {:ok, world_id} = Automata.create_world(%{name: "test_world"})
  {:ok, agent_id} = Automata.spawn_agent(world_id, %{name: "test_agent", type: "behavior_tree"})
  
  Automata.tick_agent(agent_id)
  status = Automata.agent_status(agent_id)
  
  assert status == :running
end
```

## Advanced Features in the New Architecture

The new architecture provides several advanced features not available in the core architecture:

1. **Autonomous Governance** - Self-regulation, distributed governance, adaptive institutions
2. **Integration & Deployment** - API endpoints, deployment infrastructure, evaluation framework
3. **Collective Intelligence** - Knowledge synthesis, emergent specialization, belief propagation
4. **Neural-Symbolic Integration** - Connecting symbolic reasoning with neural networks
5. **Contextual Reasoning** - Context-aware decision making

See the documentation for details on these advanced features.

## Need Help?

If you're having trouble migrating, please:

1. Check the API documentation
2. See the examples in the `lib/automata/examples` directory
3. File an issue on the GitHub repository

## Deprecation Timeline

The legacy API will be maintained for at least one major version cycle, but we encourage migration to the new architecture as soon as possible to take advantage of the new features and improvements.