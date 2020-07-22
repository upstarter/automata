# Users create world containing their automata. These are created in the
# world/ directory.  Users define their own custom modules which `use
# Automaton` as a macro. By overriding the `update()` function and returning a
# status as one of `:running`, `:failure`, `:success`, or `:aborted` the core
# system will run the MAB's as defined and handle normal errors with
# restarts. Users define error handling outside generic MAB capabilities.

defmodule MockMAB1 do
  use Automaton,
    # required
    type: :epsilon_greedy_bandit,
    # optional
    # num_epochs: 20,
    # required
    num_arms: 12,
    # required
    # number of episodes
    num_ep: 8,
    # required
    num_iter: 3000
end
