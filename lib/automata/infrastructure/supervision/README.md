# Distributed Supervision Adapters

This directory contains adapter modules that bridge between the old supervision tree and the new distributed supervisors.

## Architecture

The adapter system consists of several components:

- **SupervisorAdapter**: Replaces `Automata.Supervisor`, maintaining the same interface but using distributed components
- **AutomataSupervisorAdapter**: Replaces `Automata.AutomataSupervisor`, forwarding operations to the distributed supervisor
- **ServerAdapter**: Replaces `Automata.Server`, handling the same lifecycle management but with distributed components
- **AutomatonSupervisorAdapter**: Replaces `Automata.AutomatonSupervisor`, supervising individual agents in a distributed way
- **RegistryAdapter**: Provides a distributed registry using Horde.Registry
- **Adapters**: Entry point module with convenience functions for the adapter system

## How It Works

1. The adapter modules implement the same interface as the original modules
2. They forward calls to the new distributed components (using Horde)
3. This maintains compatibility with existing code while providing distributed capabilities

## Usage

To use the adapter system instead of the original supervision tree:

```elixir
# Instead of
Automata.Supervisor.start_link(world_config)

# Use
Automata.Infrastructure.Supervision.Adapters.start_supervision_system(world_config)
```

The adapter system automatically handles the transition to distributed components while
maintaining the same interface for client code.

## Benefits

- Seamless transition to distributed architecture
- Maintained compatibility with existing code
- Improved fault tolerance and scalability
- Support for multi-node deployments

## Implementation Details

The adapter system uses [Horde](https://hexdocs.pm/horde/Horde.html) for distributed process registry and supervision.
This allows processes to be distributed across multiple nodes while maintaining
the same guarantees as standard OTP supervisors.