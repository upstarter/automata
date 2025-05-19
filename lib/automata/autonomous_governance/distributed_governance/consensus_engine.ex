defmodule Automata.AutonomousGovernance.DistributedGovernance.ConsensusEngine do
  @moduledoc """
  Engine for managing consensus processes in distributed governance.
  
  This module provides functionality for:
  - Implementing different consensus algorithms
  - Calculating voting results
  - Determining consensus thresholds
  - Providing consensus analytics
  
  The consensus engine is a core component for enabling collective decision-making.
  """
  
  use GenServer
  require Logger
  
  alias Automata.AutonomousGovernance.DistributedGovernance.ZoneManager
  alias Automata.AutonomousGovernance.SelfRegulation
  
  @type zone_id :: binary()
  @type agent_id :: binary()
  @type decision_id :: binary()
  @type vote_type :: :for | :against | :abstain
  
  # Client API
  
  @doc """
  Starts the Consensus Engine.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Calculates the outcome of a vote based on a zone's consensus mechanism.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - decision_id: ID of the decision
  - votes: Map of votes (for/against/abstain)
  
  ## Returns
  - `{:ok, outcome}` if successful
  - `{:error, reason}` if failed
  """
  @spec calculate_outcome(zone_id(), decision_id(), map()) :: 
    {:ok, map()} | {:error, term()}
  def calculate_outcome(zone_id, decision_id, votes) do
    GenServer.call(__MODULE__, {:calculate_outcome, zone_id, decision_id, votes})
  end
  
  @doc """
  Checks if a decision has reached consensus.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - decision_id: ID of the decision
  - votes: Map of votes (for/against/abstain)
  
  ## Returns
  - `{:ok, result}` if successful
  - `{:error, reason}` if failed
  """
  @spec has_consensus(zone_id(), decision_id(), map()) :: 
    {:ok, map()} | {:error, term()}
  def has_consensus(zone_id, decision_id, votes) do
    GenServer.call(__MODULE__, {:has_consensus, zone_id, decision_id, votes})
  end
  
  @doc """
  Gets the weight of an agent's vote in a specific zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - agent_id: ID of the agent
  
  ## Returns
  - `{:ok, weight}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_agent_vote_weight(zone_id(), agent_id()) :: 
    {:ok, float()} | {:error, term()}
  def get_agent_vote_weight(zone_id, agent_id) do
    GenServer.call(__MODULE__, {:get_agent_vote_weight, zone_id, agent_id})
  end
  
  @doc """
  Registers a consensus algorithm.
  
  ## Parameters
  - algorithm_name: Name of the algorithm
  - algorithm_module: Module implementing the algorithm
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec register_algorithm(atom(), module()) :: :ok | {:error, term()}
  def register_algorithm(algorithm_name, algorithm_module) do
    GenServer.call(__MODULE__, {:register_algorithm, algorithm_name, algorithm_module})
  end
  
  @doc """
  Gets analytics for a voting process.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - decision_id: ID of the decision
  - votes: Map of votes (for/against/abstain)
  
  ## Returns
  - `{:ok, analytics}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_vote_analytics(zone_id(), decision_id(), map()) :: 
    {:ok, map()} | {:error, term()}
  def get_vote_analytics(zone_id, decision_id, votes) do
    GenServer.call(__MODULE__, {:get_vote_analytics, zone_id, decision_id, votes})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Consensus Engine")
    
    # Initialize with basic consensus algorithms
    initial_state = %{
      algorithms: %{
        majority: &calculate_majority/3,
        consensus: &calculate_consensus/3,
        weighted: &calculate_weighted/3,
        threshold: &calculate_threshold/3
      }
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:calculate_outcome, zone_id, decision_id, votes}, _from, state) do
    with {:ok, zone} <- ZoneManager.get_zone(zone_id) do
      # Get the appropriate algorithm
      algorithm = Map.get(state.algorithms, zone.decision_mechanism, &calculate_majority/3)
      
      # Calculate the outcome
      case algorithm.(zone_id, decision_id, votes) do
        {:ok, outcome} = result ->
          Logger.info("Calculated outcome for decision #{decision_id} in zone #{zone_id}: #{outcome.status}")
          {:reply, result, state}
        
        {:error, reason} = error ->
          Logger.error("Failed to calculate outcome: #{reason}")
          {:reply, error, state}
      end
    else
      {:error, reason} = error ->
        Logger.error("Failed to calculate outcome: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:has_consensus, zone_id, decision_id, votes}, _from, state) do
    with {:ok, zone} <- ZoneManager.get_zone(zone_id),
         {:ok, outcome} <- calculate_outcome(zone_id, decision_id, votes) do
      
      # Check if outcome has definitive result
      result = %{
        has_consensus: outcome.status in [:approved, :rejected],
        outcome: outcome,
        confidence: outcome.confidence
      }
      
      {:reply, {:ok, result}, state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to check consensus: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_agent_vote_weight, zone_id, agent_id}, _from, state) do
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id),
         {:ok, registration} <- ZoneManager.check_agent_registration(zone_id, agent_id) do
      
      # Get agent's reputation in this zone
      {:ok, reputation} = SelfRegulation.get_reputation(agent_id, "zone:#{zone_id}")
      
      # Calculate weight based on reputation and roles
      weight = calculate_agent_weight(reputation, registration.roles)
      
      {:reply, {:ok, weight}, state}
    else
      {:error, :not_registered} ->
        # Default weight for non-registered agents
        {:reply, {:ok, 0.0}, state}
      
      {:error, reason} = error ->
        Logger.error("Failed to get agent weight: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:register_algorithm, algorithm_name, algorithm_module}, _from, state) do
    if Map.has_key?(state.algorithms, algorithm_name) do
      {:reply, {:error, :algorithm_already_exists}, state}
    else
      # Register the algorithm
      updated_state = %{
        state |
        algorithms: Map.put(state.algorithms, algorithm_name, algorithm_module)
      }
      
      Logger.info("Registered consensus algorithm: #{algorithm_name}")
      {:reply, :ok, updated_state}
    end
  end
  
  @impl true
  def handle_call({:get_vote_analytics, zone_id, decision_id, votes}, _from, state) do
    with {:ok, _zone} <- ZoneManager.get_zone(zone_id),
         {:ok, agent_count} <- get_agent_count(zone_id) do
      
      # Calculate basic vote statistics
      for_count = length(votes[:for] || [])
      against_count = length(votes[:against] || [])
      abstain_count = length(votes[:abstain] || [])
      total_votes = for_count + against_count + abstain_count
      
      # Calculate weighted votes
      {:ok, weighted_votes} = calculate_weighted_votes(zone_id, votes)
      
      # Calculate participation rate
      participation_rate = total_votes / agent_count
      
      # Calculate consensus metrics
      consensus_score = if total_votes > 0 do
        # Higher when votes are more aligned
        max_vote = max(for_count, against_count)
        (max_vote / total_votes) * 2 - 1
      else
        0.0
      end
      
      analytics = %{
        vote_counts: %{
          for: for_count,
          against: against_count,
          abstain: abstain_count,
          total: total_votes
        },
        weighted_votes: weighted_votes,
        participation: %{
          eligible_agents: agent_count,
          participation_rate: participation_rate
        },
        consensus: %{
          consensus_score: consensus_score,
          polarization: 1.0 - consensus_score
        }
      }
      
      {:reply, {:ok, analytics}, state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to get vote analytics: #{reason}")
        {:reply, error, state}
    end
  end
  
  # Algorithm implementations
  
  defp calculate_majority(zone_id, _decision_id, votes) do
    # Simple majority vote calculation
    for_count = length(votes[:for] || [])
    against_count = length(votes[:against] || [])
    abstain_count = length(votes[:abstain] || [])
    total_votes = for_count + against_count + abstain_count
    
    if total_votes > 0 do
      # Determine outcome
      {status, confidence} = cond do
        for_count > against_count ->
          # Approved by majority
          {:approved, (for_count - against_count) / total_votes}
        
        against_count > for_count ->
          # Rejected by majority
          {:rejected, (against_count - for_count) / total_votes}
        
        true ->
          # Tie - need more votes
          {:pending, 0.0}
      end
      
      outcome = %{
        status: status,
        confidence: confidence,
        vote_counts: %{
          for: for_count,
          against: against_count,
          abstain: abstain_count,
          total: total_votes
        },
        algorithm: :majority
      }
      
      {:ok, outcome}
    else
      # No votes yet
      {:ok, %{
        status: :pending,
        confidence: 0.0,
        vote_counts: %{
          for: 0,
          against: 0,
          abstain: 0,
          total: 0
        },
        algorithm: :majority
      }}
    end
  end
  
  defp calculate_consensus(zone_id, _decision_id, votes) do
    # Consensus requires high agreement
    for_count = length(votes[:for] || [])
    against_count = length(votes[:against] || [])
    abstain_count = length(votes[:abstain] || [])
    total_votes = for_count + against_count + abstain_count
    
    # Get agent count in zone
    {:ok, agent_count} = get_agent_count(zone_id)
    
    # Consensus algorithm requires:
    # 1. Minimum participation threshold
    # 2. Strong agreement threshold
    min_participation = 0.6 # At least 60% must participate
    consensus_threshold = 0.8 # At least 80% agreement
    
    participation_rate = total_votes / agent_count
    
    if participation_rate >= min_participation && total_votes > 0 do
      # Calculate agreement percentages
      for_percentage = for_count / total_votes
      against_percentage = against_count / total_votes
      
      {status, confidence} = cond do
        for_percentage >= consensus_threshold ->
          # Strong consensus for approval
          {:approved, for_percentage}
        
        against_percentage >= consensus_threshold ->
          # Strong consensus for rejection
          {:rejected, against_percentage}
        
        true ->
          # No consensus yet
          {:pending, max(for_percentage, against_percentage)}
      end
      
      outcome = %{
        status: status,
        confidence: confidence,
        vote_counts: %{
          for: for_count,
          against: against_count,
          abstain: abstain_count,
          total: total_votes
        },
        participation_rate: participation_rate,
        algorithm: :consensus
      }
      
      {:ok, outcome}
    else
      # Not enough participation or votes yet
      {:ok, %{
        status: :pending,
        confidence: 0.0,
        vote_counts: %{
          for: for_count,
          against: against_count,
          abstain: abstain_count,
          total: total_votes
        },
        participation_rate: participation_rate,
        algorithm: :consensus
      }}
    end
  end
  
  defp calculate_weighted(zone_id, _decision_id, votes) do
    # Weighted voting based on agent reputation and roles
    {:ok, weighted_votes} = calculate_weighted_votes(zone_id, votes)
    
    if weighted_votes.total_weight > 0 do
      # Calculate weighted percentages
      for_percentage = weighted_votes.for_weight / weighted_votes.total_weight
      against_percentage = weighted_votes.against_weight / weighted_votes.total_weight
      
      {status, confidence} = cond do
        for_percentage > 0.5 ->
          # Weighted majority for approval
          {:approved, for_percentage * 2 - 1} # Scale to 0-1
        
        against_percentage > 0.5 ->
          # Weighted majority for rejection
          {:rejected, against_percentage * 2 - 1} # Scale to 0-1
        
        true ->
          # No clear majority
          {:pending, abs(for_percentage - against_percentage)}
      end
      
      outcome = %{
        status: status,
        confidence: confidence,
        vote_counts: %{
          for: length(votes[:for] || []),
          against: length(votes[:against] || []),
          abstain: length(votes[:abstain] || []),
          total: length((votes[:for] || []) ++ (votes[:against] || []) ++ (votes[:abstain] || []))
        },
        weighted_votes: weighted_votes,
        algorithm: :weighted
      }
      
      {:ok, outcome}
    else
      # No votes yet
      {:ok, %{
        status: :pending,
        confidence: 0.0,
        vote_counts: %{
          for: 0,
          against: 0,
          abstain: 0,
          total: 0
        },
        weighted_votes: weighted_votes,
        algorithm: :weighted
      }}
    end
  end
  
  defp calculate_threshold(zone_id, _decision_id, votes) do
    # Threshold-based voting (requires specific percentage)
    for_count = length(votes[:for] || [])
    against_count = length(votes[:against] || [])
    abstain_count = length(votes[:abstain] || [])
    total_votes = for_count + against_count + abstain_count
    
    # Get zone to determine threshold
    {:ok, zone} = ZoneManager.get_zone(zone_id)
    threshold = Map.get(zone, :threshold, 0.67) # Default: 2/3 majority
    
    # Get agent count in zone
    {:ok, agent_count} = get_agent_count(zone_id)
    
    # Calculate participation rate
    participation_rate = total_votes / agent_count
    min_participation = 0.5 # At least 50% must participate
    
    if participation_rate >= min_participation && total_votes > 0 do
      # Calculate percentages
      for_percentage = for_count / total_votes
      against_percentage = against_count / total_votes
      
      {status, confidence} = cond do
        for_percentage >= threshold ->
          # Meets threshold for approval
          {:approved, for_percentage / threshold}
        
        against_percentage >= threshold ->
          # Meets threshold for rejection
          {:rejected, against_percentage / threshold}
        
        against_percentage > (1 - threshold) ->
          # Cannot reach approval threshold
          {:rejected, against_percentage / threshold}
        
        for_percentage > (1 - threshold) ->
          # Cannot reach rejection threshold
          {:approved, for_percentage / threshold}
        
        true ->
          # No decision yet
          {:pending, max(for_percentage, against_percentage) / threshold}
      end
      
      outcome = %{
        status: status,
        confidence: confidence,
        vote_counts: %{
          for: for_count,
          against: against_count,
          abstain: abstain_count,
          total: total_votes
        },
        percentages: %{
          for: for_percentage,
          against: against_percentage,
          abstain: abstain_count / total_votes
        },
        threshold: threshold,
        participation_rate: participation_rate,
        algorithm: :threshold
      }
      
      {:ok, outcome}
    else
      # Not enough participation or votes yet
      {:ok, %{
        status: :pending,
        confidence: 0.0,
        vote_counts: %{
          for: for_count,
          against: against_count,
          abstain: abstain_count,
          total: total_votes
        },
        percentages: %{
          for: if(total_votes > 0, do: for_count / total_votes, else: 0.0),
          against: if(total_votes > 0, do: against_count / total_votes, else: 0.0),
          abstain: if(total_votes > 0, do: abstain_count / total_votes, else: 0.0)
        },
        threshold: threshold,
        participation_rate: participation_rate,
        algorithm: :threshold
      }}
    end
  end
  
  # Helper functions
  
  defp calculate_agent_weight(reputation, roles) do
    # Base weight from reputation (0.5 to 1.5 scale)
    rep_weight = 0.5 + reputation
    
    # Role-based weight adjustments
    role_weight = calculate_role_weight(roles)
    
    # Combine weights (with reasonable limits)
    total_weight = min(3.0, rep_weight * role_weight)
    
    total_weight
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
  
  defp calculate_weighted_votes(zone_id, votes) do
    # Calculate the weighted votes for each vote type
    weighted_votes = Enum.reduce([:for, :against, :abstain], %{for_weight: 0.0, against_weight: 0.0, abstain_weight: 0.0, total_weight: 0.0}, 
      fn vote_type, acc ->
        agent_ids = votes[vote_type] || []
        
        # Calculate total weight for this vote type
        {weight, agent_weights} = Enum.reduce(agent_ids, {0.0, %{}}, fn agent_id, {total, weights} ->
          {:ok, agent_weight} = get_agent_vote_weight(zone_id, agent_id)
          {total + agent_weight, Map.put(weights, agent_id, agent_weight)}
        end)
        
        # Update accumulator
        acc = case vote_type do
          :for -> Map.put(acc, :for_weight, weight)
          :against -> Map.put(acc, :against_weight, weight)
          :abstain -> Map.put(acc, :abstain_weight, weight)
        end
        
        # Store individual agent weights
        acc = Map.put(acc, :"#{vote_type}_agent_weights", agent_weights)
        
        # Update total weight
        Map.put(acc, :total_weight, acc.total_weight + weight)
      end)
    
    {:ok, weighted_votes}
  end
  
  defp get_agent_count(zone_id) do
    case ZoneManager.get_zone(zone_id) do
      {:ok, zone} -> {:ok, zone.agent_count}
      {:error, reason} -> {:error, reason}
    end
  end
end