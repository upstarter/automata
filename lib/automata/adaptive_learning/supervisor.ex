defmodule Automata.AdaptiveLearning.Supervisor do
  @moduledoc """
  Supervisor for the Adaptive Learning components.
  
  This supervisor manages the lifecycle of all adaptive learning components including
  Multi-Agent Reinforcement Learning, Collective Knowledge Evolution, and
  Adaptive Strategy Formulation.
  """
  use Supervisor
  
  @doc """
  Starts the adaptive learning supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    # Extract configuration options
    marl_opts = Keyword.get(opts, :multi_agent_rl, [])
    cke_opts = Keyword.get(opts, :collective_knowledge_evolution, [])
    asf_opts = Keyword.get(opts, :adaptive_strategy_formulation, [])
    
    children = [
      {Automata.AdaptiveLearning.MultiAgentRL, marl_opts},
      {Automata.AdaptiveLearning.CollectiveKnowledgeEvolution, cke_opts},
      {Automata.AdaptiveLearning.AdaptiveStrategyFormulation, asf_opts}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end