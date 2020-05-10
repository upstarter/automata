
#  ⦿	| Automata | ⦿	⦿ 	⦿	⦿

#### Spawn a [system](http://web.stanford.edu/class/ee380/Abstracts/190123.html) of concurrent, distributed, fault tolerant, and highly available intelligent agents for coordinated and/or uncoordinated action in one or many environments with no central point of failure. This project is Open Source. [![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)


![](particles.gif)

## Project Mission
The Automata Project combines the state-of-the-art AI control techniques with the latest research in autonomous decentralized systems, providing AI designers a flexible framework for creating valuable emergent properties in product ecosystems.

##### This project is in the Alpha stage and not ready for production systems. We need Contributors to get to 1.0. We are eager for your contributions and very happy you found yourself here! Please join the [slack channel](https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA) and/or reach out to [ericsteen1@gmail.com](mailto:ericsteen1@gmail.com) if interested or with any questions. Here are our [contributing guidelines](https://github.com/upstarter/automata/blob/master/CONTRIBUTING.md) and get up to speed on the [wiki](https://github.com/upstarter/automata/wiki).

## Roadmap

#### Note: This will be updated often. The direction of the project will change as the work evolves. We very eagerly welcome any of your thoughts about roadmapping

See the current milestones [here](https://github.com/upstarter/automata/milestones).

## Usage

Testing is currently happening using the mock sequence in `worlds/mock_world_1/mock_automata/mock_seq_1.ex`. This is currently our canonical example of how to design one automaton, which is a behavior tree, and *eventually* communicates with others that you define in `worlds/<mock_world>/<mock_automata>/<mock_bt>`.

Currently, you can run the mock sequence in an iex shell as follows:

```elixir
iex -S mix
iex(1)> send(MockSeq1Server, :update)
```

and tests can be run with debugging capabilities as follows:

```bash
MIX_ENV=test iex -S mix espec spec/unit/core/behavior_test.exs:31
```

where you are running a specific context/it block containing line 31.



## Implementation Overview

### Technologies
 [Elixir](https://elixir-lang.org/) & [OTP](https://en.wikipedia.org/wiki/Open_Telecom_Platform) provide the
 primitives for robust concurrent, fault-tolerant, highly available,
 self-healing distributed systems. Based on the Actor Model <sup>[1](#actorfootnote1)</sup>, a singular Elixir `Process`(Actor) embodies all 3 essential elements of computation: processing, storage, communications. It does so using very lightweight, isolated processes, each with its own stack, heap, communications facilities (mailbox), and garbage collector. The Erlang VM (BEAM), with pre-emptive scheduling, acts somewhat as on operating system on top of an operating system. Pre-emption is good because it prevents bad actors from starving the rest of the system, allowing for higher degrees of concurrency and better interactive performance.

 [Behavior Trees](https://en.wikipedia.org/wiki/Behavior_tree_(artificial_intelligence,_robotics_and_control))
 are increasingly used in place of finite state machines (FSM's) and other AI
 control architectures due to improved properties of modularity, flexibility,
 reusability, and efficiency of implementation. They enable design/development scalability and efficiency.

 [Utility AI](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf)
 is used to keep the automata focused on actions by providing an external system for all decision making support. This significantly reduces the amount of logic/nodes required for an agent and takes the heavy mathematical workload off of designers & action developers.

##### [Read the wiki](https://github.com/upstarter/automata/wiki/Underlying-Technology) for more about the technologies underlying `Automata`.

### Requirements

#### Autonomy is the capacity of agent(s) to achieve a set of coordinated goals by their own means (without human intervention) adapting to environment variations.

It combines five complementary  aspects:
  1. Perception e.g. interpretation of stimuli, removing ambiguity/vagueness from complex input data and determining relevant information based on context/strata/motif specific communications
  2. Reflection e.g. building/updating a faithful environment run-time model
  3. Goal management e.g. choosing among possible goals the most appropriate ones for a given configuration of the environment model
  4. Planning to achieve chosen goals
  5. Self-adaptation e.g. the ability to adjust behavior through learning and reasoning and to change dynamically the goal management and planning processes.


Note that the five aspects are orthogonal. The first two aspects deal with
“understanding” the map of the environment. The third and the forth aspects deal with autonomy of decision. Self adaptation ensures adequacy of decisions with respect to the environment map. See MMLC<sup>[2](#mmlcfootnote1)</sup>.

#### A system is defined as an Autonomous Decentralized System (ADS) if the following 2 properties are satisfied:

 1. Autonomous Controllability: Even if any subsystem fails, is repaired, and/or is newly added, the other subsystems can continue to manage themselves and function.

 2. Autonomous Coordinability: Even if any subsystem fails, is repaired, and/or is newly added, the other subsystems can coordinate their individual objectives among themselves and can function in a coordinated fashion.

## Features

### Functional Features:
#### General


- #### User defined behavior trees
  - Control Nodes currently on the roadmap
    - Selector
    - Sequence
    - Parallel
    - Priority
  - Condition nodes
  - In-node Decorators
  - Helper Nodes for accessing utility AI systems

- #### A Concurrent, Scalable Blackboard Knowledge System
  > The central problem of artificial intelligence is how to express the knowledge needed in order to create intelligent behavior. — John McCarthy, M.I.T/Stanford Professor, Creator of Lisp

  - A global blackboard that can coordinate automata without being a central point of failure.
  - Individual automaton blackboards readable by all automata, writeable by owning automaton

- #### Meta Level Control
  - Meta-level control (triggered each heartbeat) to support agent interaction, any potential network reorganization. Meta-level control is the ability of an agent to optimize its long term performance by choosing and sequencing its deliberation and execution actions appropriately. <sup>[2](#mmlcfootnote1)</sup>


- #### Neuromorphic/Probabilistic computing
  -  potentially bringing the code to the data rather than the other way around.

### Performance Features:
- Concurrency
  - The world is concurrent. For example: we see, hear, and move at the same time. Many global financial instruments are fluctuating at this instance. Concurrency was a core factor in the design of Erlang, making it easy to reason about and debug.
- High availability
  - Elixir is capable of 99.9999999% uptime (31 milliseconds/year of downtime). The main point of the Erlang model is an application that can be expected to run forever, as stated by the inventor — Joe Armstrong (RIP). Talk about unstoppable software!
- Fault Tolerance
  - OTP Supervision Trees and the "fail fast" principle provide strong guarantees for error recovery and self healing systems.
- Scalability & Distribution
  -  Elixir can handle millions of processes (134 million +/-) utilizing all cores without breaking a sweat on a single machine, and easily distributes work onto multiple machines with its builtin distribution mechanisms, and there is CRDT support with [Horde](https://github.com/derekkraan/horde).
  - Behavior trees provide value chain efficiency/scalability (in both design/development and operations/testing) compared to previous state of the art AI control techniques.
- Modularity
  - Modular BT's allow the designer to hierarchically combine independently developed, tested, deployed, and reusable unit behaviors that provide more valuable emergent properties in the large.
- Flexibility
  - A design goal of `Automata` is to allow high flexibility via extreme abstraction (to enable design space evolution, support diversity in applications)
- Simplicity of Implementation
  - Elixir's meta-programming facilities enable very user-friendly API's so developers don't need to know the details of BT's or Automata Theory to get things done, and BT's themselves lend efficiency to the development value chain.

### Applications
- Trading Systems
- Patient Monitoring & Care Systems
- Autonomous Pandemic Testing Drone Units
- Swarm Intelligence / Distributed Robotics
- Intelligent agents with soft realtime multi-dimensional sensory, perception, intuition, and action capabilities
- Multi-Agent Reinforcement Learning
- Mixture of Experts Deep Learning Control Systems (python inter-op with [erlport](http://erlport.org/))
- Blockchain Smart Contract Systems
- A Mega-constellation of satellites
- 3D Printing and Factory Automation
- Product Analytics Systems
- Augmented, Virtual, Mixed Reality
- Smart Home / IOT Systems
- High-Speed Rail Systems (Japan has an ADS railway that learns)
- Chatbot & Game AI's (esp. MMOG user/npc backends)
- QA Testing (BT's are particularly suited to combinatorial testing)
- ? (choose your adventure)


### API
Users create worlds containing their automata in directory structures
corresponding to their BT tree structures. These are created in the worlds/
directory. Trees can be of arbitrary depth. Users define their own custom
modules which `use Automaton` as a macro. By overriding the `update()` function
and returning a status as one of `:running`, `:failure`, `:success`, or `:aborted` the core
system will run the Behavior Tree's as defined and handle normal errors with
restarts. Users define error handling outside generic BT capabilities.

```elixir
defmodule MyAutomaton do
  use Automaton,

    # required
    # one of :sequence, :selector, :parallel, :action (no children), etc...
    node_type: :selector,

    # the heartbeat for this node(subtree), in milliseconds
    # the default is 50ms (mimics the average human brain perception cycle time)
    # heartbeat adaption as meta-level(automata) action, to be changed at runtime
    tick_freq: 50, # 50ms


    # excluded for execution nodes
    # list of child control/action(execution) nodes
    # these run in order for type :selector and :sequence nodes and in parallel
    # for type :parallel, and in a user-defined dynamic order for :priority
    children: [ChildAction1, ChildSequence1, ChildAction2]

    # called every tick, must return status
    def update do
      # reactively and proactively change the world
      # ie.. effect the current environment in phases using either effectors or via communication with other agents
      {:ok, status}
    end
end
```

### Example

Below is a simplified hypothetical example of a sequence node(subtree) for an autonomous "Forex Trader". The first two leafs are condition nodes, and the last two are action nodes.

![automata trader sequence diagram](sequence.png)

###### References
1. <a name="actorfootnote1" href="https://arxiv.org/vc/arxiv/papers/1008/1008.1459v8.pdf">Actor Model</a>

2. <a name="mmlcfootnote1" href="https://www.academia.edu/22145349/Multiagent_meta-level_control_for_radar_coordination">Multi-Agent Meta-Level Control</a>

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `Automata` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:automata, "~> 0.1.0"}
  ]
end
```

## Authors

* **Eric Steen** - [upstarter](https://github.com/upstarter)

See also the list of [contributors](https://github.com/upstarter/automata/contributors) who participated in this project.

## License

This project is licensed under the Apache 2.0 License - see the [License.md](./License.md) file for details or [![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
