## Contributing

👍🎉 First off, thanks for taking the time to contribute! 🎉👍 Please reach out to [ericsteen1@gmail.com](mailto:ericsteen1@gmail.com) if you have any questions.

### Welcome to the Automata project!

##### We are eager for your contributions and very happy you found yourself here! Here are our current needs:

- Elixir Design, Architecture & Coding Best Practices Expertise
- AI, Cognitive Architecture & Behavior Tree Expertise
- ETS, BlackBoard System, Utility AI Expertise
- Test Coverage
- Documentation
- Senior Code Reviewers to ensure Quality
- Willingness and motivation to learn it all

###### Where to get started contributing
A good place to start is in the [project kanban](https://github.com/upstarter/automata/projects/1). Especially those threads labeled 'good first issue', 'testing'.

Please join the [slack channel](https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA) and/or reach out to [ericsteen1@gmail.com](mailto:ericsteen1@gmail.com) if interested!

##### Open Items / current TODO's
1. Define protocols / data flows amongst control processes with a [contract checker](https://www.youtube.com/watch?v=rQIE22e0cW8) between all (cc is also an anti-corruption layer? A.K.A. embedded schema).

## Current Outstanding Questions (brain-storming & [question-storming](https://www.maxjoles.com/blog/question-storming) topics)
- timeouts: user-configurable at composite and/or component level? It seems both would be useful.
- Reactive tree:
  1. do we run user-defined updates async and tick tree until complete (provides reactivity since if/when conditions for a previously processed node change it can be re-activated, overtaking currently running process further in the tree). If so, does this require resetting all the nodes, etc.?
  2. Or do we run user-defined updates synchronously and tick only proceeds when processing complete
- previously processed nodes: when composite node fails/succeeds, do we `GenServer.stop` all previous nodes, or do we keep them running? or something else (`Process.exit`, etc.)

## Future Directions
- to suggest users break up the system heartbeat(update) into phases to improve designs, is there a general abstraction and will there be any needed system support?
- offline learning?
- meta-level control

##### Special notes for Automata devs
- DEBUGGING NOTE: anytime you see an error or warning that is in one of the mock sequence modules, it probably isn't. It is probably in one of the modules in core that get injected into them. This is the nature of meta-programming debugging.

### Engineering Standards & Best Practices
Check the #dev or #testing channels on [slack]((https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA)) for questions/info.
#### Design Standards
1. Abstraction & Modularity are key. Spend the time and/or [Ask on the Slack Channel](https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA) to find the right abstraction. In terms of modularity, If its more than 10-20 lines, put it in a unit Function, Module or Struct that is tested and named well (by its role in the context if possible, rather than its data type or random name).
2. Meta-programming will be heavily used as this is a framework, but it is important to know where it is useful and where its not. It is wise not to overuse clever meta-programming magic. If your not sure, ask, or use the force Luke (if your a Jedi).
3. Use function pattern matching over for other types of enumeration wherever possible as this is a first-principle in Elixir systems.
4. If your not sure how to do something, rather than do a hack, put a skeleton in place and submit a PR so a more senior engineer can provide guidance.

#### Coding Standards
1. No shortcuts or Rush Jobs. Quality is job #1. We are creating something of very high quality, built to stand the test of time. Strive for 0% technical debt (the best kind of debt). Frameworks are poorly suited to “agile” practices, since they require foresight and a lot of generic capabilities. Today's emphasis on “agile” development is predicated on the developer's ignorance of what is required. Frameworks cannot be developed in that manner, since they are generic and devoid of ultimate functionality. They are all about potential, not actual end-user functionality. If you don't know the best way to do something, ask a core team member, or reach out to the very helpful Elixir community. See the [list of resources](#help).
2. Always think about what can go wrong, what will happen on invalid input, and what might fail, which will help you catch many bugs before they happen.

#### PR Review Standards

1. Code Reviews by core team members are required before merging and must be escalated if there is even the slightest concern of a design/logic flaw or incomplete testing. Imagine your building a rocket to mars and putting you and your family on it. Would you commmit that spaghetti code now?
4. Every PR should have test coverage unless it is a trivial change or is approved by 2 core team members or designated reviewers.
5. The [BD](https://en.wikipedia.org/wiki/Benevolent_dictator_for_life) — [upstarter](https://github.com/upstarter), is a [stickler](https://dictionary.cambridge.org/us/dictionary/english/stickler) when it comes to architecture, design, code quality, accuracy, comprehensiveness. Be warned the project has very high standards as it must, and feel entirely free to keep him informed of his failures to follow the strict quality requirements. 😉 Don't take it personally if you receive a communication similar to this when a PR is not up to standards:

    > Apologies, but this work cannot be accepted as it is. Perhaps there is a way it can be improved upon, but as it stands it will not be merged.

#### Testing Standards
In Progress. Property Testing? Permutation Testing? Join the conversation on [The Automata Project Slack Channel](https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA)

1. Unit tests test the unit of behavior, not the unit of implementation. Changing the implementation, without changing the behavior or having to change any of your tests is the goal, although not always possible. So where possible, treat your test objects as black boxes, testing through the public API without calling private methods or tinkering with state.
##### <a name="help"></a>Where to ask for help:

1. [The Automata Project Slack Channel](https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA)
2. [Elixir Forum](https://elixirforum.com/)
3. [Elixir Slack Channel](https://elixir-slackin.herokuapp.com/)
4. [Stack Overflow](https://stackoverflow.com/questions/tagged/elixir)
5. [Reddit](https://www.reddit.com/r/elixir/)
6. [Quora](https://www.quora.com)
7. [Discord](https://www.discordapp.com)


#### [Code of Conduct](https://www.apache.org/foundation/policies/conduct)

### How it works

#### High Level Overview

##### The Automata supervision tree(s)
![automata supervision tree diagram](sup_tree.png)

There are 4 Layers in the supervision tree below the Application
supervisor.

The terminal abstract system control supervisor is the `AutomatonNodeSupervisor`
which supervises the user-defined behavior tree root nodes which become its children when started —
they are the "brains and braun", which are the `CompositeServer` and the `CompositeSupervisor`.

The `CompositeServer` is injected into the user-defined automaton and is the "mastermind" of their BT's, starting, stopping, and handling messages from the user-defined nodes as children of `CompositeSupervisor`. All nodes are components of a composite as root control nodes should always have children, of which some are `CompositeServer`'s, and some are `ActionServer`'s.

When the system starts, each root node configured in `lib/automata.ex` is started and run as a `GenServer`. These root nodes start and add their children to their own `CompositeSupervisor` since they are `CompositeServer`'s.

The children are started as either OTP `DyanmicSupervisor`'s (for composite nodes, each with its own `CompositeSupervisor` & `CompositeServer`).  Every node in the tree is a child of a composite as the root is always a `CompositeServer`.

When the control system encounters and starts a `CompositeServer` node (sequence, selector, etc..), the current `CompositeSupervisor` supervises the node as a `CompositeServer` & `CompositeSupervisor` pair via the `CompositeServer`.

When the control system encounters and starts a `ComponentServer` node (action, decorator, etc..), the current `CompositeSupervisor` supervises that single node as a `GenServer`.

 The `CompositeSupervisor` handles fault tolerance of user-defined BT nodes.

It starts the user defined nodes as children of `AutomatonNodeSupervisor`, which
is kept lean for fault tolerance purposes.

The following is a breakdown of roles and responsibilities in the system (corresponding to files in `lib/automata/core/`):

###### The Core Supervision Tree (in `lib/automata/core/control`)
This tree is the management & fault tolerance mechanism for the parsing and validation of user config, as well as controlling the instantiation of the user-defined behavior trees.
- `Automata.Supervisor`
  - on application start, this supervisor process starts the `AutomataSupervisor` and it's corresponding `Server`. It is started with strategy `:one_for_one` to ensure that the `AutomatonSupervisor` is independently self-healing
- `Automata.Server`
  - acts as the "brains" of the `AutomataSupervisor` to keep the supervisor lean and mean. It starts the `Automata.AutomatonSupervisor`, passing the user-defined config, which flows through the entire tree. This data flow is a
  core concern of the project.
- `Automata.AutomatonSupervisor`
  - this process acts as supervisor to each `AutomatonNodeSupervisor` and has strategy `:one_for_all` to ensure that errors restart the entire supervision tree including the GenServers (`AutomatonServer`). It delegates the spawning of the user-defined BT nodes to the `AutomatonServer` which currently handles most of the logic.
- `AutomatonNodeSupervisor`
  - runs concurrently, independently, and with `restart: permanent`. This supervisor is the root of the user-defined behavior trees.
- `AutomatonServer`
  - this node parses and validates the user configuration and creates and manages OTP event callbacks of the user-defined behavior tree root node.

###### The Automata
These files are the core functionality of the user-defined automata which are GenServer's that are injected into the user-defined modules and provide the interface to/from the control parts and the rest of the system.

- `Automaton`
  - this is the primary user interface boundary point which provides user config to the rest of the system.
- `Automaton.Behavior`
  - this is the interface (a behaviour in elixir) that is implemented by all user-defined nodes, providing the most general policy for BT-ness.
- `Automaton.Action`
  - this is the interface for action(execution) nodes — where the world is changed, reactively and proactively

###### The Blackboard

- Global Blackboard
  - all nodes share this knowledge store
  - the automata will act upon seeing certain data changes in the global blackboard
- Individual Node Blackboards
  - node blackboards use protected tables for knowledge sharing – all processes can read, one process has write access
  - the automaton will act upon seeing certain data changes in the global blackboard
