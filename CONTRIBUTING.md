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

Please join the [slack channel](https://join.slack.com/t/automata-project/shared_invite/zt-cnroo0qs-rhziMz4CjzcVRaIYPc1Pmg) and/or reach out to [ericsteen1@gmail.com](mailto:ericsteen1@gmail.com) if interested!

##### Open Items / TODO
1. Define protocols / data flows between control processes with a [contract checker](https://www.youtube.com/watch?v=rQIE22e0cW8) between all (cc is also an anti-corruption layer? A.K.A. embedded schema).

### Engineering Standards & Best Practices
Check the #dev or #testing channels on [slack]((https://join.slack.com/t/automata-project/shared_invite/zt-cnroo0qs-rhziMz4CjzcVRaIYPc1Pmg)) for questions/info.
#### Design Standards
1. Abstraction & Modularity are key. Spend the time and/or [Ask on the Slack Channel](https://join.slack.com/t/automata-project/shared_invite/zt-cnroo0qs-rhziMz4CjzcVRaIYPc1Pmg) to find the right abstraction. In terms of modularity, If its more than 10-20 lines, put it in a unit Function, Module or Struct that is tested and named well (by its role in the context if possible, rather than its data type or random name).
2. Meta-programming will be heavily used as this is a framework, but it is important to know where it is useful and where its not. It is wise not to overuse clever meta-programming magic (a common complaint about rails). If your not sure, ask. Or use the force Luke (if your a Jedi).
3. Use function pattern matching over for other types of enumeration wherever possible as this is a first-principle in Elixir systems.
4. If your not sure how to do something, rather than do a hack, put a skeleton in place and submit a PR so a more senior engineer can provide guidance.

#### Coding Standards
1. No shortcuts or Rush Jobs. Quality is job #1. We are creating something of very high quality, built to stand the test of time. Strive for 0% technical debt (the best kind of debt). Frameworks are poorly suited to “agile” practices, since they require foresight and a lot of generic capabilities. Today's emphasis on “agile” development is predicated on the developer's ignorance of what is required. Frameworks cannot be developed in that manner, since they are generic and devoid of ultimate functionality. They are all about potential, not actual end-user functionality. If you don't know the best way to do something, ask a core team member, or reach out to the very helpful Elixir community. See the [list of resources](#help).
1. Always think about what can go wrong, what will happen on invalid input, and what might fail, which will help you catch many bugs before they happen.

#### PR Review Standards

1. Code Reviews by core team members are required before merging and must be escalated if there is even the slightest concern of a design/logic flaw or incomplete testing. Imagine your building a rocket to mars and putting you and your family on it. Would you commmit that spaghetti code now?
4. Every PR should have test coverage unless it is a trivial change or is approved by 2 core team members or designated reviewers.
5. The ([BD](https://en.wikipedia.org/wiki/Benevolent_dictator_for_life)) — [upstarter](https://github.com/upstarter), is a major [stickler](https://dictionary.cambridge.org/us/dictionary/english/stickler) when it comes to architecture, design, code quality, accuracy, comprehensiveness. Be warned and feel entirely free to keep him informed of his failures to follow the strict quality requirements. 😉


#### Testing Standards
In Progress. Property Testing? Permutation Testing? Join the conversation on [The Automata Project Slack Channel](https://join.slack.com/t/automata-project/shared_invite/zt-cnroo0qs-rhziMz4CjzcVRaIYPc1Pmg)

1. Unit tests test the unit of behavior, not the unit of implementation. Changing the implementation, without changing the behavior or having to change any of your tests is the goal, although not always possible. So where possible, treat your test objects as black boxes, testing through the public API without calling private methods or tinkering with state.
##### <a name="help"></a>Where to ask for help:

1. [The Automata Project Slack Channel](https://join.slack.com/t/automata-project/shared_invite/zt-cnroo0qs-rhziMz4CjzcVRaIYPc1Pmg)
2. [Elixir Forum](https://elixirforum.com/)
3. [Elixir Slack Channel](https://elixir-slackin.herokuapp.com/)
4. [Stack Overflow](https://stackoverflow.com/questions/tagged/elixir)
5. [Reddit](https://www.reddit.com/r/elixir/)
6. [Quora](https://www.quora.com)
7. [Discord](https://www.discordapp.com)


#### [Code of Conduct](https://www.apache.org/foundation/policies/conduct)
