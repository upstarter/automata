## Contributing

👍🎉 First off, thanks for taking the time to contribute! 🎉👍 Please reach out to [ericsteen1@gmail.com](mailto:ericsteen1@gmail.com) if you have any questions.

### Welcome to The Automata Project!

##### We are eager for your contributions and very happy you found yourself here! Here are our current needs:

- Elixir Alchemists & Mad Scientists with Design, Architecture, Scalable OTP Best Practices Expertise
- AI, Cognitive Architecture & Behavior Tree Expertise
- ETS, Reinforcement Learning, BlackBoard Systems, & Utility AI Expertise
- Test Coverage
- Documentation
- Senior Code Reviewers to ensure Quality
- Willingness and motivation to learn it all

###### Where to get started contributing
A good place to start is in the [project kanban](https://github.com/upstarter/automata/projects/1). ExUnitially those threads labeled 'good first issue', 'testing'.

Please join the [slack channel](https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA) and/or reach out to [ericsteen1@gmail.com](mailto:ericsteen1@gmail.com) if interested!

### If in doubt, check the [wiki](https://github.com/upstarter/automata/wiki). 🕵️

Definitely check out the [Goals](https://github.com/upstarter/automata/wiki/Goals) on the wiki. This is currently the focal point for the project defining short, medium, and long term problem solving goals across project dimensions. New issues should come from solving these problems "in goal form". Regular brain-storming and question-storming should be conducted with the end game in mind.

See [How it works](https://github.com/upstarter/automata/wiki/How-it-works) for a high level view of the project, and check out the [docs](https://upstarter.github.io/automata/).

See [Future Directions](https://github.com/upstarter/automata/wiki/Future-Directions) for more on what's in the works.

##### <a name="help"></a>Where to ask for help:

1. [The Automata Project Slack Channel](https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA)
2. [Elixir Forum](https://elixirforum.com/)
3. [Elixir Slack Channel](https://elixir-slackin.herokuapp.com/)
4. [Stack Overflow](https://stackoverflow.com/questions/tagged/elixir)
5. [Reddit](https://www.reddit.com/r/elixir/)
6. [Quora](https://www.quora.com)

## Engineering Standards & Best Practices
Check the #dev or #testing channels on [slack]((https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA)) for questions/info.
### Design Standards
1. Abstraction & Modularity are key. Spend the time and/or [Ask on the Slack Channel](https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA) to find the right abstraction. In terms of modularity, If its more than 10-20 lines, put it in a unit Function, Module or Struct that is tested and named well (by its role in the context if possible, rather than its data type or random name).
2. Meta-programming will be heavily used as this is a framework, but it is important to know where it is useful and where its not. It is wise not to overuse clever meta-programming magic. If your not sure, ask, or use the force Luke (if your a Jedi).
3. Use function pattern matching over for other types of enumeration wherever possible as this is a first-principle in Elixir systems.
4. If your not sure how to do something, rather than do a hack, put a skeleton in place and submit a PR so a more senior engineer can provide guidance.

### Coding Standards
1. No shortcuts or Rush Jobs. Quality is job #1. We are creating something of very high quality, built to stand the test of time. Strive for 0% technical debt (the best kind of debt). Frameworks are poorly suited to “agile” practices, since they require foresight and a lot of generic capabilities. Today's emphasis on “agile” development is predicated on the developer's ignorance of what is required. Frameworks cannot be developed in that manner, since they are generic and devoid of ultimate functionality. They are all about potential, not actual end-user functionality. If you don't know the best way to do something, ask a core team member, or reach out to the very helpful Elixir community. See the [list of resources](#help).
2. Always think about what can go wrong, what will happen on invalid input, and what might fail, which will help you catch many bugs before they happen.

### PR Review Standards

1. Code Reviews by core team members are required before merging and must be escalated if there is even the slightest concern of a design/logic flaw or incomplete testing. Imagine your building a rocket to mars and putting you and your family on it. Would you commmit that spaghetti code now?
4. Every PR should have test coverage unless it is a trivial change or is approved by 2 core team members or designated reviewers.
5. The [BD](https://en.wikipedia.org/wiki/Benevolent_dictator_for_life) — [upstarter](https://github.com/upstarter), is a [stickler](https://dictionary.cambridge.org/us/dictionary/english/stickler) when it comes to architecture, design, code quality, accuracy, comprehensiveness. Be warned the project has very high standards as it must, and feel entirely free to keep him informed of his failures to follow the strict quality requirements. 😉 Don't take it personally if you receive a communication similar to this when a PR is not up to standards:

    > Apologies, but this work cannot be accepted as it is. Perhaps there is a way it can be improved upon, but as it stands it will not be merged.

### Testing Standards
In Progress. Property Testing? Permutation Testing? Join the conversation on [The Automata Project Slack Channel](https://join.slack.com/t/automata-project/shared_invite/zt-e4fqrmo4-7ujuZwzXHNCGVrZb1aVZmA)

1. Unit tests test the unit of behavior, not the unit of implementation. Changing the implementation, without changing the behavior or having to change any of your tests is the goal, although not always possible. So where possible, treat your test objects as black boxes, testing through the public API without calling private methods or tinkering with state.

### Special notes for Automata developers
- See [ex_doc recommendations](https://hexdocs.pm/elixir/writing-documentation.html#recommendations) for documentation guidelines.
- DEBUGGING NOTE: anytime you see an error or warning that is in one of the mock sequence modules, it probably isn't. It is probably in one of the modules in core that get injected into them. This is the nature of meta-programming debugging. If anyone with experience debugging a heavily meta-programmed application, please chime in.



#### [Code of Conduct](https://www.apache.org/foundation/policies/conduct)
