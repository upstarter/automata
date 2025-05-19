defmodule Automata.DistributedCognition.AdvancedDistributedCognition do
  @moduledoc """
  Main entry point for the Advanced Distributed Cognition architecture.
  
  This module integrates the components of the Advanced Distributed Cognition architecture:
  - Decentralized Belief Architecture
  - Coalition Formation Framework
  - Emergent Specialization Framework
  
  The Advanced Distributed Cognition architecture enables agents to form dynamic coalitions,
  share and propagate beliefs, and develop specialized roles within the system.
  """
  
  alias Automata.DistributedCognition.BeliefArchitecture.DecentralizedBeliefSystem
  alias Automata.DistributedCognition.CoalitionFormation.CoalitionFormationSystem
  alias Automata.DistributedCognition.EmergentSpecialization.EmergentSpecializationSystem
  
  @doc """
  Starts the Advanced Distributed Cognition system.
  """
  def start_link(opts \\ []) do
    # Start the components
    {:ok, _belief_system} = DecentralizedBeliefSystem.start_link(
      name: Keyword.get(opts, :belief_system_name, DecentralizedBeliefSystem)
    )
    
    {:ok, coalition_system} = CoalitionFormationSystem.start_link(
      name: Keyword.get(opts, :coalition_system_name, CoalitionFormationSystem)
    )
    
    {:ok, specialization_system} = EmergentSpecializationSystem.start_link(
      name: Keyword.get(opts, :specialization_system_name, EmergentSpecializationSystem)
    )
    
    # Create a supervisor-like structure to manage all systems
    systems = %{
      belief_system: DecentralizedBeliefSystem,
      coalition_system: coalition_system,
      specialization_system: specialization_system
    }
    
    {:ok, systems}
  end
  
  @doc """
  Creates a new agent within the Advanced Distributed Cognition system.
  """
  def create_agent(agent_id, agent_type, options \\ []) do
    # Create a belief set for the agent
    {:ok, _belief_set} = DecentralizedBeliefSystem.create_belief_set(agent_id)
    
    # Add initial beliefs if provided
    initial_beliefs = Keyword.get(options, :initial_beliefs, [])
    
    Enum.each(initial_beliefs, fn {content, confidence, opts} ->
      DecentralizedBeliefSystem.add_belief(agent_id, content, confidence, opts)
    end)
    
    # Create a capability profile for the agent
    initial_capabilities = Keyword.get(options, :initial_capabilities, %{})
    {:ok, _profile} = EmergentSpecializationSystem.create_capability_profile(
      agent_id, 
      initial_capabilities
    )
    
    # Return the agent ID
    {:ok, agent_id}
  end
  
  @doc """
  Forms a coalition among agents with a specified contract.
  """
  def form_coalition(initiator, members, contract_params) do
    CoalitionFormationSystem.form_coalition(initiator, members, contract_params)
  end
  
  @doc """
  Adds a belief to an agent's belief set.
  """
  def add_belief(agent_id, content, confidence, options \\ []) do
    DecentralizedBeliefSystem.add_belief(agent_id, content, confidence, options)
  end
  
  @doc """
  Propagates a belief from an agent to its neighbors.
  """
  def propagate_belief(agent_id, belief_id, targets, options \\ []) do
    DecentralizedBeliefSystem.propagate_belief(agent_id, belief_id, targets, options)
  end
  
  @doc """
  Synchronizes beliefs between agents.
  """
  def synchronize_beliefs(agent_ids, options \\ []) do
    DecentralizedBeliefSystem.synchronize_beliefs(agent_ids, options)
  end
  
  @doc """
  Allocates resources within a coalition.
  """
  def allocate_resources(coalition_id, allocation_strategy) do
    CoalitionFormationSystem.allocate_resources(coalition_id, allocation_strategy)
  end
  
  @doc """
  Analyzes the stability of a coalition.
  """
  def analyze_coalition_stability(coalition_id) do
    CoalitionFormationSystem.analyze_stability(coalition_id)
  end
  
  @doc """
  Reinforces the stability of a coalition.
  """
  def reinforce_coalition_stability(coalition_id, strategy) do
    CoalitionFormationSystem.reinforce_stability(coalition_id, strategy)
  end
  
  @doc """
  Dissolves a coalition.
  """
  def dissolve_coalition(coalition_id, reason) do
    CoalitionFormationSystem.dissolve_coalition(coalition_id, reason)
  end
  
  @doc """
  Gets the global belief state across a set of agents.
  """
  def global_belief_state(agent_ids, options \\ []) do
    DecentralizedBeliefSystem.global_belief_state(agent_ids, options)
  end
  
  @doc """
  Ensures consistency of beliefs across a set of agents.
  """
  def ensure_belief_consistency(agent_ids, options \\ []) do
    DecentralizedBeliefSystem.ensure_consistency(agent_ids, options)
  end
  
  @doc """
  Merges two or more coalitions.
  """
  def merge_coalitions(coalition_ids, merge_strategy) do
    CoalitionFormationSystem.merge_coalitions(coalition_ids, merge_strategy)
  end
  
  @doc """
  Splits a coalition into multiple coalitions.
  """
  def split_coalition(coalition_id, partition_strategy) do
    CoalitionFormationSystem.split_coalition(coalition_id, partition_strategy)
  end
  
  # Emergent Specialization Framework functions
  
  @doc """
  Creates a role in the system that agents can be assigned to.
  """
  def create_role(id, name, description, opts \\ []) do
    EmergentSpecializationSystem.create_role(id, name, description, opts)
  end
  
  @doc """
  Assigns a role to an agent based on capability matching.
  """
  def assign_role(agent_id, role_id, opts \\ []) do
    EmergentSpecializationSystem.assign_role(agent_id, role_id, opts)
  end
  
  @doc """
  Finds the most suitable role for an agent based on capabilities.
  """
  def find_best_role_for_agent(agent_id) do
    EmergentSpecializationSystem.find_best_role(agent_id)
  end
  
  @doc """
  Records performance data for an agent's capability.
  """
  def record_agent_performance(agent_id, capability_id, performance_data) do
    EmergentSpecializationSystem.record_performance_event(agent_id, capability_id, performance_data)
  end
  
  @doc """
  Records feedback on an agent's performance in a role.
  """
  def record_role_feedback(agent_id, role_id, source, feedback_data) do
    EmergentSpecializationSystem.record_feedback(agent_id, role_id, source, feedback_data)
  end
  
  @doc """
  Detects emerging specialization patterns in agent populations.
  """
  def detect_specialization_patterns(agent_ids, opts \\ []) do
    EmergentSpecializationSystem.detect_specialization_patterns(agent_ids, opts)
  end
  
  @doc """
  Reinforces a specialization pattern among a group of agents.
  """
  def reinforce_specialization(pattern_id, agent_ids, pressure_level \\ 0.5) do
    EmergentSpecializationSystem.reinforce_specialization(pattern_id, agent_ids, pressure_level)
  end
  
  @doc """
  Identifies complementary specialization patterns.
  """
  def identify_complementary_specializations do
    EmergentSpecializationSystem.identify_complementary_patterns()
  end
  
  @doc """
  Ensures diversity of specializations across the agent population.
  """
  def ensure_specialization_diversity(min_coverage \\ 0.8) do
    EmergentSpecializationSystem.ensure_specialization_diversity(min_coverage)
  end
  
  @doc """
  Runs a complete specialization cycle (detection, reinforcement, adaptation).
  """
  def run_specialization_cycle(opts \\ []) do
    EmergentSpecializationSystem.run_specialization_cycle(opts)
  end
end