defmodule Automata.AutonomousGovernance do
  @moduledoc """
  Main entry point for the Autonomous Governance systems.
  
  This module provides a unified API for the three main components:
  - Self-Regulation Mechanisms
  - Distributed Governance
  - Adaptive Institutions
  
  These components enable multi-agent systems to self-organize, establish
  rules, monitor behavior, adapt governance structures, and evolve institutional
  arrangements based on environmental changes and system needs.
  """
  
  alias Automata.AutonomousGovernance.SelfRegulation
  alias Automata.AutonomousGovernance.DistributedGovernance
  alias Automata.AutonomousGovernance.AdaptiveInstitutions
  alias Automata.AutonomousGovernance.Supervisor
  
  # Self-Regulation API
  
  @doc """
  Defines a norm within the system.
  """
  @spec define_norm(binary(), map(), list()) :: {:ok, binary()} | {:error, term()}
  def define_norm(name, specification, contexts \\ []) do
    SelfRegulation.define_norm(name, specification, contexts)
  end
  
  @doc """
  Records an observation related to norm compliance or violation.
  """
  @spec record_observation(binary(), binary(), :comply | :violate, map()) :: 
    {:ok, binary()} | {:error, term()}
  def record_observation(norm_id, agent_id, type, details) do
    SelfRegulation.record_observation(norm_id, agent_id, type, details)
  end
  
  @doc """
  Applies a sanction to an agent based on norm violations.
  """
  @spec apply_sanction(binary(), binary(), atom(), map()) :: 
    {:ok, binary()} | {:error, term()}
  def apply_sanction(agent_id, norm_id, sanction_type, parameters) do
    SelfRegulation.apply_sanction(agent_id, norm_id, sanction_type, parameters)
  end
  
  @doc """
  Gets the current reputation score for an agent.
  """
  @spec get_reputation(binary(), binary()) :: {:ok, float()} | {:error, term()}
  def get_reputation(agent_id, context \\ "global") do
    SelfRegulation.get_reputation(agent_id, context)
  end
  
  # Distributed Governance API
  
  @doc """
  Creates a new governance zone with the specified configuration.
  """
  @spec create_governance_zone(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_governance_zone(name, config) do
    DistributedGovernance.create_governance_zone(name, config)
  end
  
  @doc """
  Registers an agent in a governance zone.
  """
  @spec register_in_zone(binary(), binary(), map()) :: {:ok, binary()} | {:error, term()}
  def register_in_zone(zone_id, agent_id, roles \\ %{}) do
    DistributedGovernance.register_in_zone(zone_id, agent_id, roles)
  end
  
  @doc """
  Proposes a decision to be made within a governance zone.
  """
  @spec propose_decision(binary(), binary(), map()) :: {:ok, binary()} | {:error, term()}
  def propose_decision(zone_id, agent_id, proposal) do
    DistributedGovernance.propose_decision(zone_id, agent_id, proposal)
  end
  
  @doc """
  Records a vote on a decision in a governance zone.
  """
  @spec vote_on_decision(binary(), binary(), binary(), :for | :against | :abstain, map()) :: 
    {:ok, :recorded} | {:error, term()}
  def vote_on_decision(zone_id, decision_id, agent_id, vote, justification \\ %{}) do
    DistributedGovernance.vote_on_decision(zone_id, decision_id, agent_id, vote, justification)
  end
  
  # Adaptive Institutions API
  
  @doc """
  Defines an institution with specified rules and adaptation mechanisms.
  """
  @spec define_institution(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def define_institution(name, config) do
    AdaptiveInstitutions.define_institution(name, config)
  end
  
  @doc """
  Registers an agent to participate in an institution.
  """
  @spec join_institution(binary(), binary(), map()) :: {:ok, binary()} | {:error, term()}
  def join_institution(institution_id, agent_id, parameters \\ %{}) do
    AdaptiveInstitutions.join_institution(institution_id, agent_id, parameters)
  end
  
  @doc """
  Evaluates the performance of an institution based on various metrics.
  """
  @spec evaluate_institution(binary(), list()) :: {:ok, map()} | {:error, term()}
  def evaluate_institution(institution_id, metrics \\ []) do
    AdaptiveInstitutions.evaluate_institution(institution_id, metrics)
  end
  
  @doc """
  Proposes an adaptation to an institution's rules or structure.
  """
  @spec propose_adaptation(binary(), binary(), map()) :: {:ok, binary()} | {:error, term()}
  def propose_adaptation(institution_id, agent_id, adaptation) do
    AdaptiveInstitutions.propose_adaptation(institution_id, agent_id, adaptation)
  end
  
  # Integrated operations
  
  @doc """
  Sets up a complete governance system with integrated components.
  """
  @spec setup_governance_system(binary(), map()) :: {:ok, map()} | {:error, term()}
  def setup_governance_system(name, config) do
    with {:ok, norms} <- setup_norms(config[:norms] || []),
         {:ok, zone_id} <- create_governance_zone(name, Map.put(config, :norms, norms)),
         {:ok, institution_id} <- define_institution(name, 
                                   Map.put(config, :governance_zone, zone_id)) do
      
      {:ok, %{
        name: name,
        zone_id: zone_id, 
        institution_id: institution_id,
        norms: norms
      }}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp setup_norms(norm_configs) do
    results = Enum.map(norm_configs, fn %{name: name, specification: spec, contexts: contexts} ->
      case define_norm(name, spec, contexts) do
        {:ok, norm_id} -> {:ok, %{id: norm_id, name: name}}
        {:error, reason} -> {:error, reason}
      end
    end)
    
    if Enum.any?(results, fn result -> match?({:error, _}, result) end) do
      # If any norm failed, return the first error
      Enum.find(results, fn result -> match?({:error, _}, result) end)
    else
      # All succeeded, return the list of norm IDs
      {:ok, Enum.map(results, fn {:ok, norm_data} -> norm_data end)}
    end
  end
end