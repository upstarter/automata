defmodule Automaton.Types.DECPOMDP do
  @moduledoc """
  Implements the Decentralized Partially Observable Markov Decision Process
  (DEC-POMDP) state space representation for multi-agent control and prediction.
  Each agent is goal-oriented, i.e. associated with a distinct, high-level goal
  which it attempts to achieve.

  At every stage the environment is in a particular state. This state emits a
  joint observation according to the observation model from which each agent
  observes its individual perception. Then each agent selects an action,
  together forming the joint action, which leads to a state transition
  according to the transition model . means that in a Dec-POMDP, communication
  has no special semantics.

  An agent can focuses on planning over a finite horizon, for which the
  (undiscounted) expected cumulative reward is the commonly used optimality
  criterion. The planning problem thus amounts to finding a tuple of policies,
  called a joint policy that maximizes the expected cumulative reward.

  At each stage, each agent takes an action and receives:
    • A local observation for local decision making
    • A joint immediate reward

  DECPOMDP's can be defined with the tuple: { I, S, {A_i}, T, R, {Omega_i}, O, h }
    • I, a finite set of agents
    • S, a finite set of states with designated initial distribution b^0
    • A_i, each agents finite set of actions
    • T, state transition model P(s'|s,a->). Computes pdf of the updated states,
      depends on all agents
    • R, the reward model, depends on all agents
    • Omega_i, each agents finite set of observations
    • O, the observation model: P(o|s',a->), depends on all agents
    • h, horizon or discount factor

  DECPOMDP
    • considers outcome, sensory, and communication uncertainty in a single
  framework
    • Can model any multi-agent coordination problem
    • Macro-actions provide an abstraction to improve scalability
    • Learning methods can remove the need to generate a detailed multi-agent model
    • Methods also apply when less uncertainty
    • Begun demonstrating scalability and quality in a number of domains, but a lot
    of great open questions to solve
  """

  # alias Automaton.Types.DECPOMDP.Config.Parser

  defmacro __using__(_opts) do
  end
end
