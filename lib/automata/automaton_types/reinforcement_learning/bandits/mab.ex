defmodule Automaton.Types.MAB do
  @moduledoc """
  Implements the Multi-Armed Bandit (MAB) state space representation (One State, many possible actions)
  Each bandit is goal-oriented, i.e. associated with a distinct, high-level goal
  which it attempts to achieve.

  At each stage, each agent takes an action and receives:
    • A local observation for decision making

  """

  # alias Automaton.Types.MAB.Config.Parser

  defmacro __using__(_opts) do
    # automaton_config = opts[:automaton_config]
  end
end
