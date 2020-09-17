defmodule Automata.Types.MCSIM do
  @moduledoc """
  Implements a multi-agent state space representation to infer outcome
  possibilies using *Monte Carlo Simulation* for global optimal sequential
  decisioning. Very useful when the outcome depends on a sequence of actions and
  the total number of outcomes is too large for computation.

  On each global update, each agent makes an independent estimate of their
  future state(s) stochastically by sampling from some local population(s). At
  each stage in the "global population process" (or "reality check"), each agent
  samples from a population and subsequently takes an action to produce an
  estimation of the next state. The sample space can be **categorical**
  (*nominal and/or ordinal*), and/or **numerical** (*discrete or continuous*).

  Global decision making is thus achieved by inference based on the frequency
  distribution of estimated values made by the population of agents(a->) which
  consequently depend on the ontology and environment(s) within which all agents
  are deployed.

  Examines complex aggregations from simple actions, useful for problems where
  we can easily determine and measure the complete set of actions within the
  system but are unsure of the aggregate result. i.e. in f(x) = y, we know f and
  x, but not y.

  For example, in the continuous case using least squares regression — each
  agent updates using **y_i = Alpha + Beta * X_i + E_i**, *where **E_i** is normally
  distributed with mean 0 and variance sigma^2*.

  The meta-level control can communicate estimates produced by one or more mc_sim
  agents to other agent(s), or as global decisioning signals.

  MCSIM can be defined with the tuple: { s, S, {A_i}, E, {Omega_i}, O, h}
    • s, the trial sample set acquired from a population
    • S, state vector for each agent with designated initial distribution b^0
    • A_i, each agents finite, comparable, and orderable set of actions
    • E, estimation model P(s'|s, a->). Computes pdf based on updated states,
      depends on agent vector a->
    • Omega_i, each agents finite set of observations (using the next state and the joint action)
    • O, the observation model: P(o|s', a->), depends on agent vector a->
    • L, dynamic vector assigning number of trials for each agent [a_i .. a_n]
    • h, horizon discount factor vector. Each agent assigned float in [0,1] to emphasize current and near future
      estimates on a per agent basis

  MCSIM
    • Model Free learning (no prior knowledge of state transition variables needed (MDP))
    • Alternative to *Bellman Equation Botstrapping*
    • Requires exploration/exploitation balance

    Pros:
      • Good for measuring the risk of future decisions
      • Efficient inference method for very large dimensional search spaces
      • Can emphasize exploration to emphasize correctness over efficiency
      • Simplification of complex systems
      • Demonstrates scalability and quality in a number of domains including games
        (i.e. Monte Carlo Tree Search (MCTS) with alphago, alphazero, muzero), finance,
        physics

    Cons:
      • Not good for examining simple actions from complex aggregations (i.e. in f(x) = y, we know y but don't know f or x)
      • Doesn't provide the most realistic result
      • Hard to communicate model (teams)


  """

  # alias Automaton.Types.MCSIM.Config.Parser

  defmacro __using__(_opts) do
  end
end
