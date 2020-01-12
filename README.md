# [Automaton](https://en.wikipedia.org/wiki/Automaton)

## An framework for building concurrent and fault-tolerant [autonomous decentralized systems](https://en.wikipedia.org/wiki/Autonomous_decentralized_system).

#### Work in Progress - not ready for production systems

## Requirements
#### Functional Requirements:
##### 1. Library of system level behavior tree control nodes
  - Sequence
  - Selector
  - Parallel
  - Priority
  - Random
  - In-node Decorators


##### 2. Library of protocols for 2 user-defined execution (action & condition) nodes

##### 3. Concurrent, Scalable Blackboard System using ETS. Allow many isolated trees to run concurrently.


#### Performance Requirements:
1. Concurrency
2. High availability
3. Fault Tolerance
4. Scalability
5. Modularity

## Roadmap

Q1 2020 - Fully Functional Basic Sequence, Selector, Random control node capabilities

Q2 2020 - Parallel, Priority control nodes, In-node Decorators, ETS Blackboard System

## Implementation
##### [Behavior trees](https://en.wikipedia.org/wiki/Behavior_tree_(artificial_intelligence,_robotics_and_control)) are increasingly used in place of finite state machines (FSM's) and other AI control architectures due to improved properties of modularity, flexibility and efficiency of implementation. The aim is to keep the trees focused on actions and utilize a to-be-determined external decision making system (fsm, utility, stochastic, ?).

##### [Elixir](https://elixir-lang.org/) & [OTP](https://en.wikipedia.org/wiki/Open_Telecom_Platform) provide the primitives for robust AI systems which can sense and act in soft real time across many dimensions concurrently.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `automaton` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:automaton, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/automaton](https://hexdocs.pm/automaton).
