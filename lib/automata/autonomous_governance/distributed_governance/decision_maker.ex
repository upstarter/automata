defmodule Automata.AutonomousGovernance.DistributedGovernance.DecisionMaker do
  @moduledoc """
  System for managing decision processes in distributed governance.
  
  This module provides functionality for:
  - Creating and tracking decision proposals
  - Recording and counting votes
  - Finalizing decisions based on voting results
  - Tracking decision history and outcomes
  
  The decision maker enables transparent and auditable governance processes.
  """
  
  use GenServer
  require Logger
  
  alias Automata.AutonomousGovernance.DistributedGovernance.ZoneManager
  alias Automata.AutonomousGovernance.DistributedGovernance.ConsensusEngine
  
  @type zone_id :: binary()
  @type agent_id :: binary()
  @type decision_id :: binary()
  @type vote_id :: binary()
  @type vote_type :: :for | :against | :abstain
  
  # Client API
  
  @doc """
  Starts the Decision Maker.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
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
  Records a vote on a decision.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - decision_id: ID of the decision
  - agent_id: ID of the agent voting
  - vote: Type of vote (:for, :against, or :abstain)
  - justification: Justification for the vote
  
  ## Returns
  - `{:ok, vote_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec record_vote(zone_id(), decision_id(), agent_id(), vote_type(), map()) :: 
    {:ok, vote_id()} | {:error, term()}
  def record_vote(zone_id, decision_id, agent_id, vote, justification \\ %{}) do
    GenServer.call(__MODULE__, {:record_vote, zone_id, decision_id, agent_id, vote, justification})
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
  Finalizes a decision based on voting results.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - decision_id: ID of the decision
  - status: Final status of the decision (:approved or :rejected)
  - metadata: Optional metadata about the finalization
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec finalize_decision(zone_id(), decision_id(), atom(), map()) :: :ok | {:error, term()}
  def finalize_decision(zone_id, decision_id, status, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:finalize_decision, zone_id, decision_id, status, metadata})
  end
  
  @doc """
  Gets the voting history for a specific agent.
  
  ## Parameters
  - agent_id: ID of the agent
  - zone_id: Optional zone ID to filter by
  
  ## Returns
  - `{:ok, history}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_agent_voting_history(agent_id(), zone_id() | nil) :: 
    {:ok, list(map())} | {:error, term()}
  def get_agent_voting_history(agent_id, zone_id \\ nil) do
    GenServer.call(__MODULE__, {:get_agent_voting_history, agent_id, zone_id})
  end
  
  @doc """
  Gets vote analytics for a decision.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - decision_id: ID of the decision
  
  ## Returns
  - `{:ok, analytics}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_vote_analytics(zone_id(), decision_id()) :: {:ok, map()} | {:error, term()}
  def get_vote_analytics(zone_id, decision_id) do
    GenServer.call(__MODULE__, {:get_vote_analytics, zone_id, decision_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Decision Maker")
    
    # Initialize with empty state
    initial_state = %{
      decisions: %{},
      votes: %{},
      zone_decisions: %{},
      agent_votes: %{},
      decision_votes: %{},
      next_decision_id: 1,
      next_vote_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:propose_decision, zone_id, agent_id, proposal}, _from, state) do
    # Validate zone and agent
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id),
         {:ok, _registration} <- ZoneManager.check_agent_registration(zone_id, agent_id),
         :ok <- validate_proposal(proposal) do
      
      # Generate decision ID
      decision_id = "decision_#{state.next_decision_id}"
      
      # Create decision record
      timestamp = DateTime.utc_now()
      decision = %{
        id: decision_id,
        zone_id: zone_id,
        proposer_id: agent_id,
        type: Map.get(proposal, :type),
        description: Map.get(proposal, :description, ""),
        details: Map.get(proposal, :details, %{}),
        justification: Map.get(proposal, :justification, %{}),
        status: :pending,
        votes: %{
          for: [],
          against: [],
          abstain: []
        },
        vote_log: [],
        proposed_at: timestamp,
        updated_at: timestamp,
        decided_at: nil,
        outcome: nil
      }
      
      # Update state
      updated_state = %{
        state |
        decisions: Map.put(state.decisions, decision_id, decision),
        zone_decisions: update_zone_decisions(state.zone_decisions, zone_id, decision_id),
        next_decision_id: state.next_decision_id + 1
      }
      
      Logger.info("Proposed decision #{decision_id} in zone #{zone_id} by agent #{agent_id}")
      {:reply, {:ok, decision_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to propose decision: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:record_vote, zone_id, decision_id, agent_id, vote, justification}, _from, state) do
    # Validate zone, decision, and agent
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id),
         {:ok, decision} <- get_decision_from_state(state, zone_id, decision_id),
         {:ok, _registration} <- ZoneManager.check_agent_registration(zone_id, agent_id),
         :ok <- validate_vote_status(decision),
         :ok <- validate_vote_type(vote) do
      
      # Check if agent has already voted
      previous_vote = get_agent_previous_vote(decision, agent_id)
      
      # Generate vote ID
      vote_id = "vote_#{state.next_vote_id}"
      
      # Create vote record
      timestamp = DateTime.utc_now()
      vote_record = %{
        id: vote_id,
        decision_id: decision_id,
        agent_id: agent_id,
        vote: vote,
        justification: justification,
        timestamp: timestamp,
        previous_vote: previous_vote
      }
      
      # Update decision votes
      updated_decision = update_decision_votes(decision, agent_id, vote, previous_vote)
      |> Map.put(:updated_at, timestamp)
      |> update_decision_vote_log(vote_record)
      
      # Check if decision can be finalized based on consensus
      updated_decision = check_decision_consensus(zone_id, updated_decision)
      
      # Update state
      updated_state = %{
        state |
        decisions: Map.put(state.decisions, decision_id, updated_decision),
        votes: Map.put(state.votes, vote_id, vote_record),
        agent_votes: update_agent_votes(state.agent_votes, agent_id, vote_id),
        decision_votes: update_decision_votes_index(state.decision_votes, decision_id, vote_id),
        next_vote_id: state.next_vote_id + 1
      }
      
      Logger.info("Recorded vote #{vote} on decision #{decision_id} by agent #{agent_id}")
      {:reply, {:ok, vote_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to record vote: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_decision, zone_id, decision_id}, _from, state) do
    result = get_decision_from_state(state, zone_id, decision_id)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:list_decisions, zone_id, status}, _from, state) do
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id) do
      # Get all decisions for this zone
      decision_ids = Map.get(state.zone_decisions, zone_id, MapSet.new())
      decisions = Enum.map(decision_ids, &Map.get(state.decisions, &1))
                  |> Enum.reject(&is_nil/1)
      
      # Apply status filter if provided
      filtered_decisions = if is_nil(status) do
        decisions
      else
        Enum.filter(decisions, & &1.status == status)
      end
      
      # Sort by proposed time
      sorted_decisions = Enum.sort_by(filtered_decisions, & &1.proposed_at, DateTime)
      
      {:reply, {:ok, sorted_decisions}, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:finalize_decision, zone_id, decision_id, status, metadata}, _from, state) do
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id),
         {:ok, decision} <- get_decision_from_state(state, zone_id, decision_id),
         :ok <- validate_finalization_status(status) do
      
      if decision.status != :pending do
        # Decision already finalized
        {:reply, {:error, :decision_already_finalized}, state}
      else
        # Update decision status
        timestamp = DateTime.utc_now()
        updated_decision = %{
          decision |
          status: status,
          outcome: %{
            status: status,
            metadata: metadata,
            finalized_at: timestamp
          },
          decided_at: timestamp,
          updated_at: timestamp
        }
        
        # Update state
        updated_state = %{
          state |
          decisions: Map.put(state.decisions, decision_id, updated_decision)
        }
        
        Logger.info("Finalized decision #{decision_id} as #{status}")
        {:reply, :ok, updated_state}
      end
    else
      {:error, reason} = error ->
        Logger.error("Failed to finalize decision: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_agent_voting_history, agent_id, zone_id}, _from, state) do
    # Get all votes by this agent
    vote_ids = Map.get(state.agent_votes, agent_id, MapSet.new())
    votes = Enum.map(vote_ids, &Map.get(state.votes, &1))
            |> Enum.reject(&is_nil/1)
    
    # Enrich votes with decision information
    enriched_votes = Enum.map(votes, fn vote ->
      decision = Map.get(state.decisions, vote.decision_id)
      
      if is_nil(decision) do
        vote
      else
        Map.merge(vote, %{
          zone_id: decision.zone_id,
          decision_type: decision.type,
          decision_status: decision.status,
          decision_description: decision.description
        })
      end
    end)
    
    # Filter by zone if provided
    filtered_votes = if is_nil(zone_id) do
      enriched_votes
    else
      Enum.filter(enriched_votes, & &1.zone_id == zone_id)
    end
    
    # Sort by timestamp
    sorted_votes = Enum.sort_by(filtered_votes, & &1.timestamp, DateTime)
    
    {:reply, {:ok, sorted_votes}, state}
  end
  
  @impl true
  def handle_call({:get_vote_analytics, zone_id, decision_id}, _from, state) do
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id),
         {:ok, decision} <- get_decision_from_state(state, zone_id, decision_id) do
      
      # Get analytics from consensus engine
      result = ConsensusEngine.get_vote_analytics(zone_id, decision_id, decision.votes)
      
      # Add decision status
      case result do
        {:ok, analytics} ->
          updated_analytics = Map.put(analytics, :decision_status, decision.status)
          {:reply, {:ok, updated_analytics}, state}
        
        {:error, _reason} = error ->
          {:reply, error, state}
      end
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  # Helper functions
  
  defp validate_proposal(proposal) do
    # Validate required fields
    required_fields = [:type, :description]
    
    missing_fields = Enum.filter(required_fields, fn field -> 
      !Map.has_key?(proposal, field) || is_nil(Map.get(proposal, field))
    end)
    
    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
  
  defp validate_vote_status(decision) do
    if decision.status == :pending do
      :ok
    else
      {:error, :decision_not_pending}
    end
  end
  
  defp validate_vote_type(vote) do
    if vote in [:for, :against, :abstain] do
      :ok
    else
      {:error, :invalid_vote_type}
    end
  end
  
  defp validate_finalization_status(status) do
    if status in [:approved, :rejected] do
      :ok
    else
      {:error, :invalid_finalization_status}
    end
  end
  
  defp update_zone_decisions(zone_decisions, zone_id, decision_id) do
    Map.update(zone_decisions, zone_id, MapSet.new([decision_id]), fn ids ->
      MapSet.put(ids, decision_id)
    end)
  end
  
  defp update_agent_votes(agent_votes, agent_id, vote_id) do
    Map.update(agent_votes, agent_id, MapSet.new([vote_id]), fn ids ->
      MapSet.put(ids, vote_id)
    end)
  end
  
  defp update_decision_votes_index(decision_votes, decision_id, vote_id) do
    Map.update(decision_votes, decision_id, MapSet.new([vote_id]), fn ids ->
      MapSet.put(ids, vote_id)
    end)
  end
  
  defp get_decision_from_state(state, zone_id, decision_id) do
    case Map.fetch(state.decisions, decision_id) do
      {:ok, decision} ->
        if decision.zone_id == zone_id do
          {:ok, decision}
        else
          {:error, :decision_not_in_zone}
        end
      
      :error ->
        {:error, :decision_not_found}
    end
  end
  
  defp get_agent_previous_vote(decision, agent_id) do
    # Check each vote list for the agent
    cond do
      agent_id in (decision.votes[:for] || []) -> :for
      agent_id in (decision.votes[:against] || []) -> :against
      agent_id in (decision.votes[:abstain] || []) -> :abstain
      true -> nil
    end
  end
  
  defp update_decision_votes(decision, agent_id, vote, previous_vote) do
    # Remove from previous vote list if they previously voted
    decision_after_removal = if previous_vote do
      update_in(decision, [:votes, previous_vote], fn votes ->
        Enum.reject(votes, &(&1 == agent_id))
      end)
    else
      decision
    end
    
    # Add to new vote list
    update_in(decision_after_removal, [:votes, vote], fn votes ->
      votes = votes || []
      [agent_id | Enum.reject(votes, &(&1 == agent_id))]
    end)
  end
  
  defp update_decision_vote_log(decision, vote_record) do
    # Add vote to the log
    %{decision | vote_log: [vote_record | decision.vote_log]}
  end
  
  defp check_decision_consensus(zone_id, decision) do
    # Call consensus engine to check if decision can be finalized
    case ConsensusEngine.has_consensus(zone_id, decision.id, decision.votes) do
      {:ok, result} ->
        if result.has_consensus do
          # Update decision with consensus outcome
          %{
            decision |
            status: result.outcome.status,
            outcome: result.outcome,
            decided_at: DateTime.utc_now()
          }
        else
          decision
        end
      
      {:error, _reason} ->
        # Keep decision as is on error
        decision
    end
  end
end