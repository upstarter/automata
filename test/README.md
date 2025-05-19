# Automata Testing Framework

This directory contains the testing framework for the Automata system. The framework is designed to support testing of distributed systems and provides utilities for testing the various components of Automata.

## Directory Structure

- `fixtures/` - Test fixtures and example implementations for tests
- `integration/` - Integration tests that test interactions between multiple components
- `support/` - Support modules for testing, including utilities and shared test cases
- `unit/` - Unit tests for individual components

## Test Categories

Tests are categorized using tags:

- **Default** - Basic fast tests that run on every test command
- **Slow** - Tests that take longer to run (tagged with `@tag :slow`)
- **Distributed** - Tests that require multiple nodes (tagged with `@tag :distributed`)
- **Pending** - Tests that are not yet implemented or are disabled (tagged with `@tag :pending`)

## Running Tests

### Basic Tests

```bash
mix test
```

### Unit Tests Only

```bash
mix test test/unit
```

### Integration Tests Only

```bash
mix test test/integration
```

### Including Slow Tests

```bash
mix test --include slow
```

### Including Distributed Tests

```bash
mix test --include distributed
```

### Running All Tests

```bash
mix test --include distributed --include slow
```

### Makefile Targets

For convenience, a Makefile is provided with several targets:

```bash
make test            # Run basic tests
make test-unit       # Run unit tests only
make test-integration # Run integration tests only
make test-distributed # Run distributed tests
make test-all        # Run all tests including slow ones
```

## Testing Support Modules

The `support/` directory contains several modules to assist with testing:

### Distributed Testing

`Automata.Test.DistributedTestCase` provides utilities for testing distributed features:

```elixir
defmodule MyDistributedTest do
  use Automata.Test.DistributedTestCase
  
  @tag :distributed
  test "distributes state across nodes", %{nodes: [node1, node2]} do
    # Test distributed functionality
    call_on(node1, Module, :function, [args])
  end
end
```

### Agent System Testing

`Automata.Test.AgentSystemTestCase` provides utilities for testing the agent system:

```elixir
defmodule MyAgentTest do
  use Automata.Test.AgentSystemTestCase
  
  test "agent processes ticks correctly" do
    # Create and interact with test agents
    agent_id = create_test_agent(:behavior_tree)
    tick_agent(agent_id)
    assert_agent_status(agent_id, :ready)
  end
end
```

### Assertions and Utilities

`Automata.Test.AssertUtils` provides additional assertions for asynchronous testing:

```elixir
import Automata.Test.AssertUtils

# Wait for a condition to become true
assert_eventually fn -> 
  Registry.lookup(MyRegistry, :my_process) != []
end

# Assert process registration in Horde
assert_registered_in_horde(MyRegistry, :my_process)

# Assert key exists in the blackboard
assert_in_blackboard({:agent, "agent-123"})
```

### Mocks

`Automata.Test.Mocks` provides mock implementations for testing:

```elixir
alias Automata.Test.Mocks

# Create a mock agent
mock_config = Mocks.agent_config(type: :behavior_tree)

# Use mock action handler
action_config = %{
  action_handler: Mocks.MockActionHandler,
  parameters: %{iterations: 3}
}

# Monitor events
{:ok, _pid} = Mocks.MockEventHandler.start_link()
Mocks.MockEventHandler.handle_event(my_event)
events = Mocks.MockEventHandler.get_events()
```

## Writing Tests

### Unit Tests

Unit tests should focus on testing a single component in isolation. Mock or stub any dependencies.

```elixir
defmodule MyComponentTest do
  use ExUnit.Case
  
  test "component behaves correctly" do
    # Test individual component
  end
end
```

### Integration Tests

Integration tests should test interactions between components.

```elixir
defmodule MyIntegrationTest do
  use ExUnit.Case
  
  test "components work together" do
    # Test interaction between components
  end
end
```

### Distributed Tests

Distributed tests should test functionality across multiple nodes.

```elixir
defmodule MyDistributedTest do
  use Automata.Test.DistributedTestCase
  
  @tag :distributed
  test "works across nodes", %{nodes: nodes} do
    # Test distributed functionality
  end
end
```

## Best Practices

1. **Keep tests fast**: Most tests should run quickly
2. **Use appropriate tags**: Tag slow or distributed tests accordingly
3. **Use assertions**: Use the appropriate assertions for the test case
4. **Test edge cases**: Test failure cases, timeouts, and edge conditions
5. **Clean up resources**: Use `on_exit` or `start_supervised` to clean up resources
6. **Isolate tests**: Each test should be independent of others
7. **Use descriptive names**: Tests should have descriptive names
8. **Group related tests**: Use `describe` blocks to group related tests