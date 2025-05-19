defmodule Automata.AutonomousGovernance.DistributedGovernance do
  @moduledoc """
  Distributed Governance for multi-agent systems.
  
  This module provides functionality for:
  - Creating and managing governance zones
  - Supporting agent participation in governance
  - Implementing consensus mechanisms
  - Facilitating collective decision-making
  
  Distributed Governance enables agents to collectively make decisions and
  establish rules for governing their interactions in a decentralized manner.
  """
  
  use GenServer
  require Logger
  
  alias Automata.AutonomousGovernance.DistributedGovernance.ZoneManager
  alias Automata.AutonomousGovernance.DistributedGovernance.ConsensusEngine
  alias Automata.AutonomousGovernance.DistributedGovernance.DecisionMaker
  alias Automata.AutonomousGovernance.SelfRegulation
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @type zone_id :: binary()
  @type agent_id :: binary()
  @type decision_id :: binary()
  @type vote_type :: :for | :against | :abstain
  
  # Client API
  
  @doc """
  Starts the Distributed Governance system.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Creates a new governance zone with the specified configuration.
  
  ## Parameters
  - name: Name of the governance zone
  - config: Configuration for the zone
    - description: Description of the zone
    - decision_mechanism: Mechanism for making decisions (:majority, :consensus, :weighted, etc.)
    - agent_requirements: Requirements for agents to join
    - scope: Scope of decisions that can be made
    - norms: List of initial norms to apply
  
  ## Returns
  - `{:ok, zone_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_governance_zone(binary(), map()) :: {:ok, zone_id()} | {:error, term()}
  def create_governance_zone(name, config) do
    GenServer.call(__MODULE__, {:create_governance_zone, name, config})
  end
  
  @doc """
  Registers an agent in a governance zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - agent_id: ID of the agent to register
  - roles: Map of roles the agent will have in the zone
  
  ## Returns
  - `{:ok, registration_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec register_in_zone(zone_id(), agent_id(), map()) :: {:ok, binary()} | {:error, term()}
  def register_in_zone(zone_id, agent_id, roles \\ %{}) do
    GenServer.call(__MODULE__, {:register_in_zone, zone_id, agent_id, roles})
  end
  
  @doc """
  Proposes a decision to be made within a governance zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - agent_id: ID of the agent proposing the decision
  - proposal: Map containing proposal details
    - type: Type of decision (:rule_change, :resource_allocation, :norm_creation, etc.)
    - description: Description of the proposal
    - details: Details specific to the proposal type
    - justification: Justification for the proposal
  
  ## Returns
  - `{:ok, decision_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec propose_decision(zone_id(), agent_id(), map()) :: {:ok, decision_id()} | {:error, term()}
  def propose_decision(zone_id, agent_id, proposal) do
    GenServer.call(__MODULE__, {:propose_decision, zone_id, agent_id, proposal})
  end
  
  @doc """
  Records a vote on a decision in a governance zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - decision_id: ID of the decision
  - agent_id: ID of the agent voting
  - vote: Type of vote (:for, :against, or :abstain)
  - justification: Justification for the vote
  
  ## Returns
  - `{:ok, :recorded}` if successful
  - `{:error, reason}` if failed
  """
  @spec vote_on_decision(zone_id(), decision_id(), agent_id(), vote_type(), map()) :: 
    {:ok, :recorded} | {:error, term()}
  def vote_on_decision(zone_id, decision_id, agent_id, vote, justification \\ %{}) do
    GenServer.call(__MODULE__, {:vote_on_decision, zone_id, decision_id, agent_id, vote, justification})
  end
  
  @doc """
  Gets details about a governance zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  
  ## Returns
  - `{:ok, zone}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_zone(zone_id()) :: {:ok, map()} | {:error, term()}
  def get_zone(zone_id) do
    GenServer.call(__MODULE__, {:get_zone, zone_id})
  end
  
  @doc """
  Lists all governance zones, optionally filtered by criteria.
  
  ## Parameters
  - filters: Map of filters to apply
  
  ## Returns
  - `{:ok, zones}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_zones(map()) :: {:ok, list(map())} | {:error, term()}
  def list_zones(filters \\ %{}) do
    GenServer.call(__MODULE__, {:list_zones, filters})
  end
  
  @doc """
  Gets details about a decision.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - decision_id: ID of the decision
  
  ## Returns
  - `{:ok, decision}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_decision(zone_id(), decision_id()) :: {:ok, map()} | {:error, term()}
  def get_decision(zone_id, decision_id) do
    GenServer.call(__MODULE__, {:get_decision, zone_id, decision_id})
  end
  
  @doc """
  Lists all decisions in a governance zone, optionally filtered by status.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - status: Optional status to filter by (:pending, :approved, :rejected, etc.)
  
  ## Returns
  - `{:ok, decisions}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_decisions(zone_id(), atom() | nil) :: {:ok, list(map())} | {:error, term()}
  def list_decisions(zone_id, status \\ nil) do
    GenServer.call(__MODULE__, {:list_decisions, zone_id, status})
  end
  
  @doc """
  Gets governance metrics for a zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  
  ## Returns
  - `{:ok, metrics}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_zone_metrics(zone_id()) :: {:ok, map()} | {:error, term()}
  def get_zone_metrics(zone_id) do
    GenServer.call(__MODULE__, {:get_zone_metrics, zone_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Distributed Governance system")
    
    # Register with knowledge system
    KnowledgeSystem.register_knowledge_domain("governance", %{
      description: "Distributed governance information for multi-agent systems",
      schema: %{
        zone: [:id, :name, :description, :decision_mechanism, :agent_requirements, :scope, :created_at],
        agent_registration: [:id, :zone_id, :agent_id, :roles, :joined_at, :status],
        decision: [:id, :zone_id, :type, :proposer_id, :description, :details, :status, :proposed_at, :decided_at],
        vote: [:id, :decision_id, :agent_id, :vote, :justification, :timestamp]
      }
    })
    
    {:ok, %{initialized: true}}
  end
  
  @impl true
  def handle_call({:create_governance_zone, name, config}, _from, state) do
    case ZoneManager.create_zone(name, config) do
      {:ok, zone_id} = result ->
        # Add zone to knowledge system
        KnowledgeSystem.add_knowledge_item("governance", "zone", %{
          id: zone_id,
          name: name,
          description: config[:description],
          decision_mechanism: config[:decision_mechanism],
          agent_requirements: config[:agent_requirements],
          scope: config[:scope],
          created_at: DateTime.utc_now()
        })
        
        # If norms are specified, add them to the zone
        if config[:norms] do
          Enum.each(config[:norms], fn norm ->
            if is_binary(norm) do
              # Reference to existing norm
              SelfRegulation.add_context(norm, "zone:#{zone_id}")
            end
          end)
        end
        
        Logger.info("Created governance zone: #{name} (#{zone_id})")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:register_in_zone, zone_id, agent_id, roles}, _from, state) do
    case ZoneManager.register_agent(zone_id, agent_id, roles) do
      {:ok, registration_id} = result ->
        # Add registration to knowledge system
        KnowledgeSystem.add_knowledge_item("governance", "agent_registration", %{
          id: registration_id,
          zone_id: zone_id,
          agent_id: agent_id,
          roles: roles,
          joined_at: DateTime.utc_now(),
          status: :active
        })
        
        Logger.info("Registered agent #{agent_id} in zone #{zone_id}")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:propose_decision, zone_id, agent_id, proposal}, _from, state) do
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id),
         {:ok, registration} <- ZoneManager.check_agent_registration(zone_id, agent_id),
         {:ok, decision_id} <- DecisionMaker.propose_decision(zone_id, agent_id, proposal) do
      
      # Add decision to knowledge system
      KnowledgeSystem.add_knowledge_item("governance", "decision", %{
        id: decision_id,
        zone_id: zone_id,
        type: proposal[:type],
        proposer_id: agent_id,
        description: proposal[:description],
        details: proposal[:details],
        status: :pending,
        proposed_at: DateTime.utc_now(),
        decided_at: nil
      })
      
      # Check if agent has special role that auto-approves proposals
      if has_auto_approve_role?(registration.roles) do
        handle_auto_approval(zone_id, decision_id, agent_id)
      end
      
      Logger.info("Agent #{agent_id} proposed decision in zone #{zone_id}")
      {:reply, {:ok, decision_id}, state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to propose decision: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:vote_on_decision, zone_id, decision_id, agent_id, vote, justification}, _from, state) do
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id),
         {:ok, _registration} <- ZoneManager.check_agent_registration(zone_id, agent_id),
         {:ok, decision} <- DecisionMaker.get_decision(zone_id, decision_id),
         :ok <- validate_decision_status(decision),
         {:ok, vote_id} <- DecisionMaker.record_vote(zone_id, decision_id, agent_id, vote, justification) do
      
      # Add vote to knowledge system
      KnowledgeSystem.add_knowledge_item("governance", "vote", %{
        id: vote_id,
        decision_id: decision_id,
        agent_id: agent_id,
        vote: vote,
        justification: justification,
        timestamp: DateTime.utc_now()
      })
      
      # Check if decision can be finalized
      check_decision_finalization(zone_id, decision_id)
      
      Logger.info("Agent #{agent_id} voted #{vote} on decision #{decision_id} in zone #{zone_id}")
      {:reply, {:ok, :recorded}, state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to record vote: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_zone, zone_id}, _from, state) do
    {:reply, ZoneManager.get_zone(zone_id), state}
  end
  
  @impl true
  def handle_call({:list_zones, filters}, _from, state) do
    {:reply, ZoneManager.list_zones(filters), state}
  end
  
  @impl true
  def handle_call({:get_decision, zone_id, decision_id}, _from, state) do
    {:reply, DecisionMaker.get_decision(zone_id, decision_id), state}
  end
  
  @impl true
  def handle_call({:list_decisions, zone_id, status}, _from, state) do
    {:reply, DecisionMaker.list_decisions(zone_id, status), state}
  end
  
  @impl true
  def handle_call({:get_zone_metrics, zone_id}, _from, state) do
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id) do
      # Collect metrics about the zone
      {:ok, decisions} = DecisionMaker.list_decisions(zone_id, nil)
      {:ok, agents} = ZoneManager.list_agents_in_zone(zone_id)
      
      # Calculate decision statistics
      decision_stats = calculate_decision_stats(decisions)
      
      # Calculate participation rate
      participation_rate = calculate_participation_rate(zone_id, decisions, agents)
      
      # Calculate consensus metrics
      consensus_metrics = calculate_consensus_metrics(zone_id, decisions)
      
      # Combine metrics
      metrics = %{
        zone_id: zone_id,
        agent_count: length(agents),
        decision_stats: decision_stats,
        participation_rate: participation_rate,
        consensus_metrics: consensus_metrics,
        timestamp: DateTime.utc_now()
      }
      
      {:reply, {:ok, metrics}, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  # Helper functions
  
  defp validate_decision_status(decision) do
    if decision.status == :pending do
      :ok
    else
      {:error, :decision_not_pending}
    end
  end
  
  defp has_auto_approve_role?(roles) do
    Map.get(roles, :admin, false) || Map.get(roles, :auto_approve, false)
  end
  
  defp handle_auto_approval(zone_id, decision_id, agent_id) do
    # Auto-approve the decision if agent has appropriate role
    DecisionMaker.record_vote(zone_id, decision_id, agent_id, :for, %{auto: true})
    DecisionMaker.finalize_decision(zone_id, decision_id, :approved, %{auto: true})
    
    # Update decision in knowledge system
    KnowledgeSystem.update_knowledge_item("governance", "decision", decision_id, %{
      status: :approved,
      decided_at: DateTime.utc_now(),
      auto_approved: true
    })
    
    # Execute the decision
    execute_decision(zone_id, decision_id)
  end
  
  defp check_decision_finalization(zone_id, decision_id) do
    with {:ok, decision} <- DecisionMaker.get_decision(zone_id, decision_id),
         {:ok, zone} <- ZoneManager.get_zone(zone_id) do
      
      # Check if decision can be finalized based on zone's decision mechanism
      case zone.decision_mechanism do
        :majority ->
          check_majority_decision(zone_id, decision)
        
        :consensus ->
          check_consensus_decision(zone_id, decision)
        
        :weighted ->
          check_weighted_decision(zone_id, decision)
        
        :threshold ->
          check_threshold_decision(zone_id, decision, zone.threshold || 0.67)
        
        _ ->
          # Unknown mechanism, don't auto-finalize
          :ok
      end
    else
      {:error, _reason} ->
        # If there's an error, just ignore and don't finalize
        :ok
    end
  end
  
  defp check_majority_decision(zone_id, decision) do
    # Get vote counts
    for_votes = length(decision.votes[:for] || [])
    against_votes = length(decision.votes[:against] || [])
    abstain_votes = length(decision.votes[:abstain] || [])
    
    # Get total registered agents
    {:ok, agents} = ZoneManager.list_agents_in_zone(zone_id)
    total_agents = length(agents)
    
    # Calculate participation
    total_votes = for_votes + against_votes + abstain_votes
    participation = total_votes / total_agents
    
    # Check if we have enough participation
    min_participation = get_min_participation(decision.type)
    
    if participation >= min_participation do
      # Check for majority
      if for_votes > against_votes do
        finalize_decision(zone_id, decision.id, :approved)
      else
        finalize_decision(zone_id, decision.id, :rejected)
      end
    end
  end
  
  defp check_consensus_decision(zone_id, decision) do
    # Get vote counts
    for_votes = length(decision.votes[:for] || [])
    against_votes = length(decision.votes[:against] || [])
    abstain_votes = length(decision.votes[:abstain] || [])
    
    # Get total registered agents
    {:ok, agents} = ZoneManager.list_agents_in_zone(zone_id)
    total_agents = length(agents)
    
    # Calculate participation and consensus
    total_votes = for_votes + against_votes + abstain_votes
    participation = total_votes / total_agents
    
    # Consensus requires high agreement
    consensus_threshold = get_consensus_threshold(decision.type)
    
    if participation >= 0.75 && total_votes > 0 do
      if for_votes / total_votes >= consensus_threshold do
        finalize_decision(zone_id, decision.id, :approved)
      else
        # For consensus, we only reject if there's clear disagreement
        if against_votes / total_votes > 0.25 do
          finalize_decision(zone_id, decision.id, :rejected)
        end
      end
    end
  end
  
  defp check_weighted_decision(zone_id, decision) do
    # For weighted decisions, we consider agent reputation or role weights
    {:ok, weighted_result} = calculate_weighted_votes(zone_id, decision)
    
    if weighted_result.total_weight > 0 do
      if weighted_result.for_weight / weighted_result.total_weight > 0.5 do
        finalize_decision(zone_id, decision.id, :approved)
      else
        finalize_decision(zone_id, decision.id, :rejected)
      end
    end
  end
  
  defp check_threshold_decision(zone_id, decision, threshold) do
    # Get vote counts
    for_votes = length(decision.votes[:for] || [])
    against_votes = length(decision.votes[:against] || [])
    abstain_votes = length(decision.votes[:abstain] || [])
    
    # Get total registered agents
    {:ok, agents} = ZoneManager.list_agents_in_zone(zone_id)
    total_agents = length(agents)
    
    # Calculate participation
    total_votes = for_votes + against_votes + abstain_votes
    
    # Check if we have enough participation
    min_participation = get_min_participation(decision.type)
    
    if total_votes / total_agents >= min_participation && total_votes > 0 do
      # Check if for votes meet the threshold
      if for_votes / total_votes >= threshold do
        finalize_decision(zone_id, decision.id, :approved)
      else
        finalize_decision(zone_id, decision.id, :rejected)
      end
    end
  end
  
  defp finalize_decision(zone_id, decision_id, status) do
    DecisionMaker.finalize_decision(zone_id, decision_id, status)
    
    # Update decision in knowledge system
    KnowledgeSystem.update_knowledge_item("governance", "decision", decision_id, %{
      status: status,
      decided_at: DateTime.utc_now()
    })
    
    # Execute the decision if approved
    if status == :approved do
      execute_decision(zone_id, decision_id)
    end
  end
  
  defp execute_decision(zone_id, decision_id) do
    {:ok, decision} = DecisionMaker.get_decision(zone_id, decision_id)
    
    # Execute based on decision type
    case decision.type do
      :norm_creation ->
        execute_norm_creation(zone_id, decision)
      
      :rule_change ->
        execute_rule_change(zone_id, decision)
      
      :resource_allocation ->
        execute_resource_allocation(zone_id, decision)
      
      :agent_status ->
        execute_agent_status_change(zone_id, decision)
      
      :zone_configuration ->
        execute_zone_configuration_change(zone_id, decision)
      
      _ ->
        Logger.warning("No execution handler for decision type: #{decision.type}")
    end
  end
  
  defp execute_norm_creation(zone_id, decision) do
    details = decision.details
    
    if Map.has_key?(details, :norm_specification) do
      # Define a new norm with the zone context
      SelfRegulation.define_norm(
        details[:name],
        details[:norm_specification],
        ["zone:#{zone_id}" | (details[:additional_contexts] || [])]
      )
    end
  end
  
  defp execute_rule_change(zone_id, decision) do
    details = decision.details
    
    if Map.has_key?(details, :rule_id) && Map.has_key?(details, :changes) do
      # This would update zone rules - in a real implementation, this would
      # interface with the ZoneManager to update rule settings
      :ok
    end
  end
  
  defp execute_resource_allocation(_zone_id, _decision) do
    # Would interface with resource management system
    :ok
  end
  
  defp execute_agent_status_change(zone_id, decision) do
    details = decision.details
    
    if Map.has_key?(details, :target_agent_id) && Map.has_key?(details, :status_change) do
      case details.status_change do
        :remove ->
          ZoneManager.remove_agent(zone_id, details.target_agent_id, %{
            reason: details[:reason],
            decision_id: decision.id
          })
        
        :change_role ->
          if Map.has_key?(details, :new_roles) do
            ZoneManager.update_agent_roles(zone_id, details.target_agent_id, details.new_roles)
          end
        
        _ ->
          :ok
      end
    end
  end
  
  defp execute_zone_configuration_change(zone_id, decision) do
    details = decision.details
    
    if Map.has_key?(details, :configuration_changes) do
      # This would update zone configuration
      ZoneManager.update_zone_config(zone_id, details.configuration_changes)
    end
  end
  
  defp get_min_participation(decision_type) do
    case decision_type do
      :norm_creation -> 0.6
      :rule_change -> 0.5
      :resource_allocation -> 0.4
      :agent_status -> 0.5
      :zone_configuration -> 0.7
      _ -> 0.5
    end
  end
  
  defp get_consensus_threshold(decision_type) do
    case decision_type do
      :norm_creation -> 0.8
      :rule_change -> 0.75
      :resource_allocation -> 0.7
      :agent_status -> 0.8
      :zone_configuration -> 0.9
      _ -> 0.75
    end
  end
  
  defp calculate_weighted_votes(zone_id, decision) do
    # Accumulate weighted votes based on agent reputation or roles
    Enum.reduce([:for, :against, :abstain], %{for_weight: 0, against_weight: 0, abstain_weight: 0, total_weight: 0}, 
      fn vote_type, acc ->
        agent_ids = decision.votes[vote_type] || []
        
        Enum.reduce(agent_ids, acc, fn agent_id, vote_acc ->
          # Get agent's weight based on reputation and roles
          {:ok, weight} = get_agent_vote_weight(zone_id, agent_id)
          
          case vote_type do
            :for -> 
              %{vote_acc | 
                for_weight: vote_acc.for_weight + weight,
                total_weight: vote_acc.total_weight + weight}
            
            :against -> 
              %{vote_acc | 
                against_weight: vote_acc.against_weight + weight,
                total_weight: vote_acc.total_weight + weight}
            
            :abstain -> 
              %{vote_acc | 
                abstain_weight: vote_acc.abstain_weight + weight,
                total_weight: vote_acc.total_weight + weight}
          end
        end)
      end)
    |> (fn result -> {:ok, result} end).()
  end
  
  defp get_agent_vote_weight(zone_id, agent_id) do
    # Combine reputation and role-based weights
    with {:ok, reputation} <- SelfRegulation.get_reputation(agent_id, "zone:#{zone_id}"),
         {:ok, registration} <- ZoneManager.check_agent_registration(zone_id, agent_id) do
      
      # Base weight from reputation (0.5 to 1.5 scale)
      rep_weight = 0.5 + reputation
      
      # Role-based weight adjustments
      role_weight = calculate_role_weight(registration.roles)
      
      # Combine weights (with reasonable limits)
      total_weight = min(3.0, rep_weight * role_weight)
      
      {:ok, total_weight}
    else
      {:error, _reason} ->
        # Default weight if agent not found
        {:ok, 1.0}
    end
  end
  
  defp calculate_role_weight(roles) do
    # Calculate weight modifier based on roles
    Enum.reduce(roles, 1.0, fn {role, value}, acc ->
      case role do
        :admin when value -> acc * 1.5
        :moderator when value -> acc * 1.3
        :veteran when value -> acc * 1.2
        _ -> acc
      end
    end)
  end
  
  defp calculate_decision_stats(decisions) do
    # Count decisions by type and status
    by_type = Enum.reduce(decisions, %{}, fn decision, acc ->
      Map.update(acc, decision.type, 1, &(&1 + 1))
    end)
    
    by_status = Enum.reduce(decisions, %{}, fn decision, acc ->
      Map.update(acc, decision.status, 1, &(&1 + 1))
    end)
    
    # Calculate time statistics
    time_stats = Enum.reduce(decisions, %{total_time: 0, decided_count: 0}, fn decision, acc ->
      case {decision.proposed_at, decision.decided_at} do
        {proposed, decided} when not is_nil(proposed) and not is_nil(decided) ->
          time_diff = DateTime.diff(decided, proposed, :second)
          %{
            total_time: acc.total_time + time_diff,
            decided_count: acc.decided_count + 1
          }
        
        _ ->
          acc
      end
    end)
    
    avg_decision_time = if time_stats.decided_count > 0 do
      time_stats.total_time / time_stats.decided_count
    else
      0
    end
    
    %{
      total: length(decisions),
      by_type: by_type,
      by_status: by_status,
      avg_decision_time: avg_decision_time
    }
  end
  
  defp calculate_participation_rate(zone_id, decisions, agents) do
    total_agents = length(agents)
    
    if total_agents == 0 || length(decisions) == 0 do
      0.0
    else
      # Calculate average participation across all decisions
      total_participation = Enum.reduce(decisions, 0, fn decision, acc ->
        decision_participants = MapSet.new()
        
        decision_participants = Enum.reduce([:for, :against, :abstain], decision_participants, fn vote_type, part_acc ->
          Enum.reduce(decision.votes[vote_type] || [], part_acc, fn agent_id, p_acc ->
            MapSet.put(p_acc, agent_id)
          end)
        end)
        
        participation_rate = MapSet.size(decision_participants) / total_agents
        acc + participation_rate
      end)
      
      total_participation / length(decisions)
    end
  end
  
  defp calculate_consensus_metrics(zone_id, decisions) do
    # Calculate various consensus metrics
    consensus_data = Enum.reduce(decisions, %{
      unanimous_count: 0,
      contested_count: 0,
      total_consensus_score: 0
    }, fn decision, acc ->
      # Skip pending decisions
      if decision.status in [:approved, :rejected] do
        for_votes = length(decision.votes[:for] || [])
        against_votes = length(decision.votes[:against] || [])
        total_votes = for_votes + against_votes
        
        if total_votes > 0 do
          # Calculate consensus score (1.0 = perfect consensus, 0.0 = perfect split)
          max_vote_count = max(for_votes, against_votes)
          consensus_score = (max_vote_count / total_votes) * 2 - 1
          
          updated_acc = %{acc | total_consensus_score: acc.total_consensus_score + consensus_score}
          
          cond do
            consensus_score > 0.9 ->
              %{updated_acc | unanimous_count: acc.unanimous_count + 1}
            
            consensus_score < 0.3 ->
              %{updated_acc | contested_count: acc.contested_count + 1}
            
            true ->
              updated_acc
          end
        else
          acc
        end
      else
        acc
      end
    end)
    
    # Calculate averages
    decided_count = Enum.count(decisions, & &1.status in [:approved, :rejected])
    
    avg_consensus_score = if decided_count > 0 do
      consensus_data.total_consensus_score / decided_count
    else
      0.0
    end
    
    %{
      avg_consensus_score: avg_consensus_score,
      unanimous_percentage: if decided_count > 0, do: consensus_data.unanimous_count / decided_count, else: 0.0,
      contested_percentage: if decided_count > 0, do: consensus_data.contested_count / decided_count, else: 0.0
    }
  end
end