# Users create world containing their automata. These are created in the
# world/ directory.  Users define their own custom modules which `use
# Automaton` as a macro. By overriding the `update()` function and returning a
# status as one of `:running`, `:failure`, `:success`, or `:aborted` the core
# system will run the MAB's as defined and handle normal errors with
# restarts. Users define error handling outside generic MAB capabilities.

defmodule MockMAB1 do
  use Automaton,
    # required
    type: :bandit,
    # optional
    # num_epochs: 20,
    # required
    num_arms: 12,
    # required
    # number of episodes
    num_ep: 10,
    # required
    num_iter: 2000

  # action_probs: [for(_ <- 1..12, do: 5)]
end
