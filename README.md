
#  ⦿	| Automata | ⦿	⦿ 	⦿	⦿

### An AI control architecture framework for building autonomous decentralized systems ([ADS](https://en.wikipedia.org/wiki/Autonomous_decentralized_system)).

![](particles.gif)

Spawn a [system](http://web.stanford.edu/class/ee380/Abstracts/190123.html) of concurrent, distributed, fault tolerant, and highly available
intelligent agents for coordinated and/or uncoordinated action in one or many
environments with no central point of failure. This project is Open Source.

## Project Mission & Summary
The Automata Project is a comprehensive framework for Artificial Intelligence Control Architects. It combines the state-of-the-art AI control techniques with the latest research in autonomous decentralized systems.

##### This project is in the Alpha stage and not ready for production systems. We need Contributors to get to 1.0. We are eager for your contributions and very happy you found yourself here! Please join the [slack channel](https://join.slack.com/t/automata-project/shared_invite/zt-cnroo0qs-rhziMz4CjzcVRaIYPc1Pmg) and/or reach out to [ericsteen1@gmail.com](mailto:ericsteen1@gmail.com) if interested or with any questions. Here are our [contributing guidelines](https://github.com/upstarter/automata/blob/master/CONTRIBUTING.md).

## Roadmap

#### Note: This will be updated often. The direction of the project will change as the work evolves. We very eagerly welcome any of your thoughts about roadmapping

See the current milestones [here](https://github.com/upstarter/automata/milestones).

## Usage

Currently, the mock sequence runs when you run `iex -S mix`. This will change of course.

## Implementation Overview

### Technologies
 [Elixir](https://elixir-lang.org/) & [OTP](https://en.wikipedia.org/wiki/Open_Telecom_Platform) provide the
 primitives for robust concurrent, fault-tolerant, highly available,
 self-healing distributed systems. Based on the Actor model, a singular Elixir `Process` embodies all 3 essential elements of computation: processing, storage, communications. It does so using very lightweight, isolated processes, each with its own stack, heap, and communications facilities (mailbox), and garbage collector. The Erlang VM (BEAM), with pre-emptive scheduling, acts somewhat as on operating system on top of an operating system. Pre-emption is good because it prevents bad processes from starving the rest of the system, allowing for higher degrees of concurrency and better interactive performance.

 [Behavior Trees](https://en.wikipedia.org/wiki/Behavior_tree_(artificial_intelligence,_robotics_and_control))
 are increasingly used in place of finite state machines (FSM's) and other AI
 control architectures due to improved properties of modularity, flexibility,
 reusability, and efficiency of implementation. They enable design/development scalability and efficiency.

 [Utility AI](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf)
 is used to keep the automata focused on actions by providing an external system for all decision making support. This significantly reduces the amount of logic/nodes required for an agent and takes the heavy mathematical workload off of action developers.

### Requirements

#### A system is defined as an Autonomous Decentralized System (ADS) if the following 2 properties are satisfied:

 1. Autonomous Controllability: Even if any subsystem fails, is repaired, and/or is newly added, the other subsystems can continue to manage themselves and function.

 2. Autonomous Coordinability: Even if any subsystem fails, is repaired, and/or is newly added, the other subsystems can coordinate their individual objectives among themselves and can function in a coordinated fashion.

    - With `Automata`, while it is a property of the behavior tree implementation that user-defined nodes are independent, it is left to the designer to ensure coordination independence among all nodes in order to satisfy this property.

## Features

### Functional Features:
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
  - A global blackboard that can coordinate automata without being a central point of failure.
  - Individual automaton blackboards readable by all automata, writeable by owning automaton
  - Potentially bringing the code to the data rather than the other way around.


### Performance Features:
- Concurrency
  - The world is concurrent. For example: we see, hear, and move at the same time. Many global financial instruments are fluctuating at this instance. Concurrency was a core factor in the design of the Elixir language, making it easy to reason about and debug.
- High availability
  - Elixir is capable of 99.9999999% uptime (31 milliseconds/year of downtime). The main point of the Elixir model is an application that can be expected to run forever, as stated by the inventor — Joe Armstrong (RIP). Talk about unstoppable software!
- Fault Tolerance
  - OTP Supervision Trees and the "fail fast" principle provide strong guarantees for error recovery and self healing systems.
- Scalability & Distribution
  -  Elixir can handle millions of processes (134 million +/-) utilizing all cores without breaking a sweat on a single machine, and easily distributes work onto multiple machines with its builtin distribution mechanisms, and there is CRDT support with [Horde](https://github.com/derekkraan/horde).
  - Behavior trees provide value stream scalability (design/development and operations/testing).
- Modularity
  - Modular BT's allow the designer to hierarchically combine independently developed, tested, deployed, and reusable unit behaviors that provide more valuable emergent properties in the large.
- Flexibility
  - A design goal of `Automata` is to allow high flexibility (supports many use cases)
- Simplicity of Implementation
  - Elixir's meta-programming facilities enable very user-friendly API's so developers don't need to know the details of BT's or Automata Theory to get things done, and BT's themselves lend efficiency via simplicity to the development value chain.

### Applications
- Trading Systems
- Patient Monitoring & Care Systems
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
Users may create tree structures of arbitrary depth by defining their own custom
modules in the nodes/ directory which `use Automaton` as a macro. By
overriding the `update()` function and returning a status as one of `:running`,
`:failure`, or `:success`, the core system will run the
Behavior Tree's as defined and handle errors and restarts.

```elixir
defmodule MyAutomaton do
  use Automaton,

    # required
    # one of :sequence, :selector, :parallel, :action (no children), etc...
    node_type: :selector,

    # the frequency of updates for this node(subtree), in milliseconds
    # the default is 0 ms, essentially an infinite loop
    tick_freq: 200, # 200ms


    # not included for execution nodes
    # list of child control/action(execution) nodes
    # these run in order for type :selector and :sequence nodes
    # and in parallel for type :parallel, and in some user-defined dynamic order for :priority
    children: [ChildAction1, ChildSequence1, ChildAction2]

    # called every tick, must return status
    def update do
      # reactively and proactively change the world
      {:ok, status}
    end
end
```

### Example

Below is a simplified hypothetical example of a sequence node(subtree) for an autonomous "Forex Trader". The first two leafs are condition nodes, and the last two are action nodes.

![automata trader sequence diagram](sequence.png)

TODO: how to implement the above scenario.

#### Where to read about the technologies underlying `Automata`:

###### The core architecture
- [The Elixir and OTP Guidebook](https://www.manning.com/books/the-little-elixir-and-otp-guidebook). old but very good

- [Elixir in Action, Second Edition](https://www.manning.com/books/elixir-in-action-second-edition). new and very good

###### Libraries & Tooling (WIP)
- [Horde](https://github.com/derekkraan/horde)
- [swarm](https://github.com/bitwalker/swarm)
- [libcluster](https://github.com/bitwalker/libcluster)


###### Behavior Trees
- [CraftAI BT Grammar Basics](https://www.craft.ai/blog/bt-101-behavior-trees-grammar-basics/)

- [Behavior Tree Starter Kit (BTSK)](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter06_The_Behavior_Tree_Starter_Kit.pdf) and corresponding [provided source code](https://github.com/aigamedev/btsk) and in particular [this file](https://github.com/aigamedev/btsk/blob/master/BehaviorTree.cpp).

- [BTSK Video](https://www.youtube.com/watch?v=n4aREFb3SsU)

- [Elixir Behavior Tree](https://github.com/jschomay/elixir-behavior-tree) and the corresponding [elixirconf talk](https://elixirforum.com/t/39-elixirconf-us-2018-behavior-trees-and-battleship-tapping-into-the-power-of-advanced-data-structures-jeff-schomay/16785)

- [BT AI](https://github.com/libgdx/gdx-ai/wiki/Behavior-Trees)

###### The Blackboard
- [Sharing Data in Actions](https://github.com/libgdx/gdx-ai/wiki/Behavior-Trees#using-data-for-inter-task-communication)

- [BlackBoard Architectures](https://books.google.com/books?id=1OJ8EhvuPXAC&pg=PA459&lpg=PA459&dq=blackboard+game+ai&source=bl&ots=iVYGrf_Rzy&sig=ACfU3U31OOqst7Dd7z7fhiH9HoVwBjyVJQ&hl=en&sa=X&ved=2ahUKEwjvxqyR3LHnAhVMrp4KHSSfD4sQ6AEwDHoECAsQAQ#v=onepage&q=blackboard%20game%20ai&f=false)

- [Blackboard Systems](http://gbbopen.org/papers/ai-expert.pdf)

###### Utility AI
- [Behavioral Mathematics](https://www.amazon.com/Behavioral-Mathematics-Game-AI-Applied/dp/1584506849/ref=sr_1_5?keywords=game+behavior+mathematics&qid=1581555478&sr=8-5)

- [Utility AI Design Patterns](https://course.ccs.neu.edu/cs5150f13/readings/dill_designpatterns.pdf)

###### Theoretical
- [Multi-Agent Online Planning with Communication](https://www.aaai.org/ocs/index.php/ICAPS/ICAPS09/paper/viewFile/729/1129)

- [The Complexity of Decentralized Control of Markov Decision Processes (Dec-POMPDP)](https://arxiv.org/pdf/1301.3836.pdf)

- [Decentralized Control of Partially Observable Markov Decision
Processes using Belief Space Macro-actions (Dec-POSMDP)](https://arxiv.org/pdf/1502.06030.pdf)

- [New Research in Multi-Agent Coordination](https://www.intechopen.com/books/applications-of-mobile-robots/a-survey-and-analysis-of-cooperative-multi-agent-robot-systems-challenges-and-directions)

###### Other
- [Beliefs, Desires, Intentions(BDI) Architecture](https://en.wikipedia.org/wiki/Belief%E2%80%93desire%E2%80%93intention_software_model)

- [Entity, Component, System(ECS) Architecture](https://en.wikipedia.org/wiki/Entity_component_system) and [this](https://www.youtube.com/watch?v=7m37kKZ5ohA&t=336s) excellent Empex talk.

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
