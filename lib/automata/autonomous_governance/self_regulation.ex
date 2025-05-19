defmodule Automata.AutonomousGovernance.SelfRegulation do
  @moduledoc """
  Self-Regulation Mechanisms for multi-agent systems.
  
  This module provides functionality for:
  - Norm emergence and definition
  - Compliance monitoring
  - Sanction mechanisms
  - Reputation systems
  
  These mechanisms enable agents to establish social norms, monitor compliance,
  apply sanctions for violations, and maintain reputation scores based on behavior.
  """
  
  use GenServer
  require Logger
  
  alias Automata.AutonomousGovernance.SelfRegulation.NormManager
  alias Automata.AutonomousGovernance.SelfRegulation.ComplianceMonitor
  alias Automata.AutonomousGovernance.SelfRegulation.SanctionSystem
  alias Automata.AutonomousGovernance.SelfRegulation.ReputationSystem
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  # Type definitions
  @type norm_id :: binary()
  @type agent_id :: binary()
  @type observation_id :: binary()
  @type sanction_id :: binary()
  @type norm_spec :: map()
  @type context :: binary()
  
  # Client API
  
  @doc """
  Starts the Self-Regulation system.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Defines a norm within the system.
  
  ## Parameters
  - name: The name of the norm
  - specification: Map containing the norm's specification
    - description: Description of the norm
    - condition: Condition that triggers norm evaluation
    - compliance: Criteria for compliance
    - violation: Criteria for violation
    - sanctions: List of sanction types applicable for violations
  - contexts: List of contexts where this norm applies
  
  ## Returns
  - `{:ok, norm_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec define_norm(binary(), norm_spec(), list(context())) :: 
    {:ok, norm_id()} | {:error, term()}
  def define_norm(name, specification, contexts \\ []) do
    GenServer.call(__MODULE__, {:define_norm, name, specification, contexts})
  end
  
  @doc """
  Records an observation related to norm compliance or violation.
  
  ## Parameters
  - norm_id: ID of the norm being observed
  - agent_id: ID of the agent being observed
  - type: Type of observation (:comply or :violate)
  - details: Map containing details about the observation
  
  ## Returns
  - `{:ok, observation_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec record_observation(norm_id(), agent_id(), :comply | :violate, map()) :: 
    {:ok, observation_id()} | {:error, term()}
  def record_observation(norm_id, agent_id, type, details) do
    GenServer.call(__MODULE__, {:record_observation, norm_id, agent_id, type, details})
  end
  
  @doc """
  Applies a sanction to an agent based on norm violations.
  
  ## Parameters
  - agent_id: ID of the agent to sanction
  - norm_id: ID of the violated norm
  - sanction_type: Type of sanction to apply
  - parameters: Parameters specific to the sanction type
  
  ## Returns
  - `{:ok, sanction_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec apply_sanction(agent_id(), norm_id(), atom(), map()) :: 
    {:ok, sanction_id()} | {:error, term()}
  def apply_sanction(agent_id, norm_id, sanction_type, parameters) do
    GenServer.call(__MODULE__, {:apply_sanction, agent_id, norm_id, sanction_type, parameters})
  end
  
  @doc """
  Gets the current reputation score for an agent.
  
  ## Parameters
  - agent_id: ID of the agent
  - context: Context for the reputation (defaults to "global")
  
  ## Returns
  - `{:ok, score}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_reputation(agent_id(), context()) :: {:ok, float()} | {:error, term()}
  def get_reputation(agent_id, context \\ "global") do
    GenServer.call(__MODULE__, {:get_reputation, agent_id, context})
  end
  
  @doc """
  Lists all norms in the system, optionally filtered by context.
  
  ## Parameters
  - context: Optional context to filter norms
  
  ## Returns
  - `{:ok, norms}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_norms(context() | nil) :: {:ok, list(map())} | {:error, term()}
  def list_norms(context \\ nil) do
    GenServer.call(__MODULE__, {:list_norms, context})
  end
  
  @doc """
  Gets details about a specific norm.
  
  ## Parameters
  - norm_id: ID of the norm
  
  ## Returns
  - `{:ok, norm}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_norm(norm_id()) :: {:ok, map()} | {:error, term()}
  def get_norm(norm_id) do
    GenServer.call(__MODULE__, {:get_norm, norm_id})
  end
  
  @doc """
  Lists all observations for a specific agent or norm.
  
  ## Parameters
  - filters: Map of filters to apply
    - agent_id: Optional agent ID to filter
    - norm_id: Optional norm ID to filter
    - type: Optional observation type to filter
  
  ## Returns
  - `{:ok, observations}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_observations(map()) :: {:ok, list(map())} | {:error, term()}
  def list_observations(filters \\ %{}) do
    GenServer.call(__MODULE__, {:list_observations, filters})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Self-Regulation system")
    
    # Register with knowledge system to integrate norm knowledge
    KnowledgeSystem.register_knowledge_domain("norms", %{
      description: "Social norms and compliance information",
      schema: %{
        norm: [:id, :name, :description, :condition, :compliance, :violation, :sanctions, :contexts],
        observation: [:id, :norm_id, :agent_id, :type, :details, :timestamp],
        sanction: [:id, :agent_id, :norm_id, :type, :parameters, :timestamp],
        reputation: [:agent_id, :context, :score, :history]
      }
    })
    
    {:ok, %{initialized: true}}
  end
  
  @impl true
  def handle_call({:define_norm, name, specification, contexts}, _from, state) do
    case NormManager.define_norm(name, specification, contexts) do
      {:ok, norm_id} = result ->
        # Add norm to knowledge system
        KnowledgeSystem.add_knowledge_item("norms", "norm", %{
          id: norm_id,
          name: name,
          description: specification[:description],
          condition: specification[:condition],
          compliance: specification[:compliance],
          violation: specification[:violation],
          sanctions: specification[:sanctions],
          contexts: contexts
        })
        
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:record_observation, norm_id, agent_id, type, details}, _from, state) do
    with {:ok, norm} <- NormManager.get_norm(norm_id),
         {:ok, observation_id} <- ComplianceMonitor.record_observation(norm_id, agent_id, type, details) do
      
      # Update reputation based on observation
      update_reputation(agent_id, norm, type)
      
      # Add observation to knowledge system
      KnowledgeSystem.add_knowledge_item("norms", "observation", %{
        id: observation_id,
        norm_id: norm_id,
        agent_id: agent_id,
        type: type,
        details: details,
        timestamp: DateTime.utc_now()
      })
      
      # If violation, possibly apply sanctions
      if type == :violate do
        handle_violation(agent_id, norm)
      end
      
      {:reply, {:ok, observation_id}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:apply_sanction, agent_id, norm_id, sanction_type, parameters}, _from, state) do
    case SanctionSystem.apply_sanction(agent_id, norm_id, sanction_type, parameters) do
      {:ok, sanction_id} = result ->
        # Add sanction to knowledge system
        KnowledgeSystem.add_knowledge_item("norms", "sanction", %{
          id: sanction_id,
          agent_id: agent_id,
          norm_id: norm_id,
          type: sanction_type,
          parameters: parameters,
          timestamp: DateTime.utc_now()
        })
        
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_reputation, agent_id, context}, _from, state) do
    {:reply, ReputationSystem.get_reputation(agent_id, context), state}
  end
  
  @impl true
  def handle_call({:list_norms, context}, _from, state) do
    {:reply, NormManager.list_norms(context), state}
  end
  
  @impl true
  def handle_call({:get_norm, norm_id}, _from, state) do
    {:reply, NormManager.get_norm(norm_id), state}
  end
  
  @impl true
  def handle_call({:list_observations, filters}, _from, state) do
    {:reply, ComplianceMonitor.list_observations(filters), state}
  end
  
  # Helper functions
  
  defp update_reputation(agent_id, norm, observation_type) do
    # Update agent's reputation in each context where the norm applies
    Enum.each(norm.contexts, fn context ->
      case observation_type do
        :comply ->
          ReputationSystem.update_reputation(agent_id, context, :positive, 
            %{norm_id: norm.id, weight: norm[:compliance_weight] || 1.0})
        
        :violate ->
          ReputationSystem.update_reputation(agent_id, context, :negative, 
            %{norm_id: norm.id, weight: norm[:violation_weight] || 1.0})
      end
    end)
    
    # Also update global reputation
    global_weight = case observation_type do
      :comply -> norm[:compliance_weight] || 1.0
      :violate -> norm[:violation_weight] || 1.0
    end
    
    global_update_type = case observation_type do
      :comply -> :positive
      :violate -> :negative
    end
    
    ReputationSystem.update_reputation(agent_id, "global", global_update_type, 
      %{norm_id: norm.id, weight: global_weight})
  end
  
  defp handle_violation(agent_id, norm) do
    # Check if automatic sanctions should be applied
    if norm[:auto_sanctions] do
      Enum.each(norm[:auto_sanctions], fn {sanction_type, parameters} ->
        apply_sanction(agent_id, norm.id, sanction_type, parameters)
      end)
    end
  end
end