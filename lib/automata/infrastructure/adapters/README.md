# Automata Core Adapter System

This directory contains adapters that bridge between the original Automata core architecture and the new distributed architecture. These adapters maintain compatibility with existing code while enabling the use of the new infrastructure components.

## Purpose

The adapter system serves several purposes:

1. **Compatibility**: Allow existing code to continue working with minimal changes
2. **Migration Path**: Provide a clear path for migrating from the old to the new architecture
3. **Feature Access**: Enable old-style code to access new architecture features
4. **Performance**: Improve performance by leveraging distributed capabilities behind the scenes

## Components

The adapter system consists of the following components:

- **SupervisorAdapter**: Replaces `Automata.Supervisor`, maintaining the same interface
- **AutomataSupervisorAdapter**: Replaces `Automata.AutomataSupervisor`
- **ServerAdapter**: Replaces `Automata.Server`
- **AutomatonSupervisorAdapter**: Replaces `Automata.AutomatonSupervisor`
- **AgentServerAdapter**: Replaces `Automaton.AgentServer`
- **AgentSupervisorAdapter**: Replaces `Automaton.AgentSupervisor`
- **RegistryAdapter**: Provides distributed registry using Horde.Registry

## Entry Points

The main entry points to the adapter system are:

1. **Automata.CoreAdapter**: The top-level module for accessing the adapters
2. **Automata.legacy_***: Functions in the main Automata module for backward compatibility

## Usage

To use the adapter system, replace calls to the original core modules with calls to the corresponding adapter functions:

```elixir
# Instead of
Automata.Operator.run(world_config)

# Use
Automata.legacy_start(world_config)

# Or directly
Automata.CoreAdapter.start(world_config)
```

See the MIGRATION_GUIDE.md file for more detailed migration instructions.

## Implementation Notes

The adapters maintain compatibility by:

1. Implementing the same public API as the original modules
2. Using the same process naming conventions
3. Preserving the same message patterns
4. Maintaining the same error handling behaviors

Under the hood, they use the new architecture's components:

1. Distributed supervision using Horde
2. Event-based communication using Phoenix.PubSub
3. Registry-based process lookup
4. Enhanced error handling and telemetry

## Development Guidelines

When modifying the adapter system:

1. Maintain backward compatibility at all costs
2. Add comprehensive tests for each adapter
3. Document any subtle differences in behavior
4. Include examples of both old and new usage patterns
5. Provide migration guidance for each component

## Deprecation Timeline

The adapter system is intended as a transitional aid, not a permanent feature. The long-term plan is to:

1. Maintain full compatibility for at least one major version cycle
2. Gradually deprecate specific features in subsequent minor versions
3. Provide detailed migration guidance for each deprecated feature
4. Eventually remove the adapter system in a future major version