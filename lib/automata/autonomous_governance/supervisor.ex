defmodule Automata.AutonomousGovernance.Supervisor do
  @moduledoc """
  Supervisor for the Autonomous Governance components.
  
  This supervisor manages:
  - Self-Regulation Mechanisms
  - Distributed Governance
  - Adaptive Institutions
  
  It provides fault tolerance and proper startup/shutdown sequence for these components.
  """
  
  use Supervisor
  
  alias Automata.AutonomousGovernance.SelfRegulation
  alias Automata.AutonomousGovernance.DistributedGovernance
  alias Automata.AutonomousGovernance.AdaptiveInstitutions
  
  @doc """
  Starts the Autonomous Governance supervisor.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # Self-Regulation components
      {SelfRegulation, []},
      {SelfRegulation.NormManager, []},
      {SelfRegulation.ComplianceMonitor, []},
      {SelfRegulation.SanctionSystem, []},
      {SelfRegulation.ReputationSystem, []},
      
      # Distributed Governance components
      {DistributedGovernance, []},
      {DistributedGovernance.ZoneManager, []},
      {DistributedGovernance.ConsensusEngine, []},
      {DistributedGovernance.DecisionMaker, []},
      
      # Adaptive Institutions components
      {AdaptiveInstitutions, []},
      {AdaptiveInstitutions.InstitutionManager, []},
      {AdaptiveInstitutions.PerformanceEvaluator, []},
      {AdaptiveInstitutions.AdaptationEngine, []},
    ]
    
    # Use :one_for_one strategy so that if one component fails, only it is restarted
    Supervisor.init(children, strategy: :one_for_one)
  end
end