defmodule Automata.CollectiveIntelligence.DecisionProcesses.Consensus do
  @moduledoc """
  Implements consensus-based decision mechanisms.
  
  This module provides various consensus protocols for distributed decision-making,
  including Byzantine fault tolerance mechanisms, Paxos variants, and simpler
  quorum-based approaches. Consensus mechanisms ensure that a group of agents can
  reach agreement despite potential failures or conflicts.
  """
  
  alias Automata.CollectiveIntelligence.DecisionProcesses.DecisionProcess
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @behaviour DecisionProcess
  
  @consensus_algorithms [
    :simple_majority,
    :super_majority,
    :unanimous,
    :distributed_paxos,
    :practical_byzantine
  ]
  
  # DecisionProcess callbacks
  
  @impl DecisionProcess
  def initialize(config) do
    # Validate config
    with :ok <- validate_config(config) do
      process_data = %{
        id: config.id,
        config: config,
        state: :initializing,
        participants: %{},
        inputs: %{},
        result: nil,
        started_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        ended_at: nil,
        metadata: %{
          rounds: [],
          current_round: 0,
          algorithm_state: initialize_algorithm_state(config)
        }
      }
      
      # If we have knowledge context, fetch relevant information
      process_data = 
        if config.knowledge_context do
          enrich_with_knowledge(process_data, config.knowledge_context)
        else
          process_data
        end
      
      {:ok, %{process_data | state: :collecting}}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @impl DecisionProcess
  def register_participant(process_data, participant_id, params) do
    if Map.has_key?(process_data.participants, participant_id) do
      {:error, :already_registered}
    else
      if process_data.state != :collecting do
        {:error, :registration_closed}
      else
        # Check if we've reached max participants
        if process_data.config.max_participants != :unlimited &&
           map_size(process_data.participants) >= process_data.config.max_participants do
          {:error, :max_participants_reached}
        else
          updated_participants = Map.put(process_data.participants, participant_id, %{
            registered_at: DateTime.utc_now(),
            params: params
          })
          
          updated_data = %{
            process_data |
            participants: updated_participants,
            updated_at: DateTime.utc_now()
          }
          
          {:ok, updated_data}
        end
      end
    end
  end
  
  @impl DecisionProcess
  def submit_input(process_data, participant_id, input) do
    cond do
      process_data.state != :collecting ->
        {:error, :not_collecting}
        
      not Map.has_key?(process_data.participants, participant_id) ->
        {:error, :participant_not_registered}
        
      true ->
        # Validate input for consensus
        with :ok <- validate_input(input, process_data.config) do
          updated_inputs = Map.put(process_data.inputs, participant_id, input)
          
          updated_data = %{
            process_data |
            inputs: updated_inputs,
            updated_at: DateTime.utc_now()
          }
          
          # Check if we have enough inputs to advance to deliberation
          updated_data = 
            if should_advance_to_deliberation?(updated_data) do
              %{updated_data | state: :deliberating}
            else
              updated_data
            end
            
          {:ok, updated_data}
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end
  
  @impl DecisionProcess
  def compute_result(process_data) do
    if process_data.state != :deliberating do
      {:error, :not_deliberating}
    else
      # Apply the specific consensus algorithm
      algorithm = process_data.config.custom_parameters.algorithm || :simple_majority
      
      case apply_consensus_algorithm(algorithm, process_data) do
        {:ok, result, updated_metadata} ->
          updated_data = %{
            process_data |
            state: :decided,
            result: result,
            updated_at: DateTime.utc_now(),
            metadata: updated_metadata
          }
          
          {:ok, updated_data, result}
          
        {:continue, updated_metadata} ->
          # Need more rounds of deliberation
          updated_data = %{
            process_data |
            updated_at: DateTime.utc_now(),
            metadata: updated_metadata
          }
          
          {:ok, updated_data, nil}
          
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
  
  @impl DecisionProcess
  def can_close?(process_data) do
    # A process can be closed if:
    # 1. It has reached a decision, or
    # 2. It has enough participants and inputs to compute a result
    
    process_data.state == :decided ||
      (process_data.state == :deliberating && 
       has_quorum?(process_data) &&
       all_rounds_complete?(process_data))
  end
  
  @impl DecisionProcess
  def close(process_data) do
    case process_data.state do
      :decided ->
        # Already decided, just mark as closed
        {:ok, %{process_data | state: :closed, ended_at: DateTime.utc_now()}}
        
      :deliberating when has_quorum?(process_data) ->
        # Try to compute a final result
        case compute_result(process_data) do
          {:ok, updated_data, _result} ->
            {:ok, %{updated_data | state: :closed, ended_at: DateTime.utc_now()}}
            
          {:error, reason} ->
            {:error, reason}
        end
        
      _ ->
        {:error, :cannot_close}
    end
  end
  
  # Private helpers
  
  defp validate_config(config) do
    # Validate required fields
    required_fields = [:id, :topic, :description, :min_participants]
    
    missing_fields = Enum.filter(required_fields, &(not Map.has_key?(config, &1)))
    
    if length(missing_fields) > 0 do
      {:error, {:missing_required_fields, missing_fields}}
    else
      # Validate custom parameters for consensus
      custom_params = config.custom_parameters || %{}
      
      algorithm = Map.get(custom_params, :algorithm, :simple_majority)
      
      if algorithm not in @consensus_algorithms do
        {:error, {:invalid_algorithm, algorithm, @consensus_algorithms}}
      else
        # Validate other algorithm-specific parameters
        case algorithm do
          :super_majority ->
            threshold = Map.get(custom_params, :threshold, 0.67)
            
            if threshold <= 0.5 or threshold > 1.0 do
              {:error, {:invalid_threshold, threshold}}
            else
              :ok
            end
            
          _ ->
            :ok
        end
      end
    end
  end
  
  defp validate_input(input, config) do
    # Basic validation - check if the input has the required format
    # for the configured consensus algorithm
    
    algorithm = config.custom_parameters.algorithm || :simple_majority
    
    case algorithm do
      algo when algo in [:simple_majority, :super_majority, :unanimous] ->
        if not Map.has_key?(input, :position) do
          {:error, :missing_position}
        else
          position = input.position
          
          if position not in [:agree, :disagree, :abstain] do
            {:error, {:invalid_position, position}}
          else
            :ok
          end
        end
        
      :distributed_paxos ->
        if not Map.has_key?(input, :proposal) do
          {:error, :missing_proposal}
        else
          :ok
        end
        
      :practical_byzantine ->
        if not Map.has_key?(input, :value) do
          {:error, :missing_value}
        else
          :ok
        end
    end
  end
  
  defp should_advance_to_deliberation?(process_data) do
    # Check if we have enough participants
    has_min_participants =
      map_size(process_data.participants) >= process_data.config.min_participants
    
    # Check if we have enough inputs
    has_quorum?(process_data) && has_min_participants
  end
  
  defp has_quorum?(process_data) do
    participant_count = map_size(process_data.participants)
    input_count = map_size(process_data.inputs)
    
    if participant_count == 0 do
      false
    else
      # Calculate the actual quorum requirement
      required_quorum = 
        process_data.config.quorum || 
        case process_data.config.custom_parameters.algorithm do
          :unanimous -> 1.0
          :super_majority -> Map.get(process_data.config.custom_parameters, :threshold, 0.67)
          _ -> 0.5  # Default to simple majority
        end
      
      input_ratio = input_count / participant_count
      input_ratio >= required_quorum
    end
  end
  
  defp all_rounds_complete?(process_data) do
    case process_data.config.custom_parameters.algorithm do
      algo when algo in [:distributed_paxos, :practical_byzantine] ->
        # These algorithms have multiple rounds
        max_rounds = Map.get(process_data.config.custom_parameters, :max_rounds, 3)
        process_data.metadata.current_round >= max_rounds
        
      _ ->
        # Simple algorithms only need one round
        true
    end
  end
  
  defp apply_consensus_algorithm(algorithm, process_data) do
    case algorithm do
      :simple_majority ->
        apply_simple_majority(process_data)
        
      :super_majority ->
        threshold = Map.get(process_data.config.custom_parameters, :threshold, 0.67)
        apply_super_majority(process_data, threshold)
        
      :unanimous ->
        apply_unanimous(process_data)
        
      :distributed_paxos ->
        apply_distributed_paxos(process_data)
        
      :practical_byzantine ->
        apply_practical_byzantine(process_data)
    end
  end
  
  defp apply_simple_majority(process_data) do
    # Count votes
    votes = count_votes(process_data.inputs)
    
    agree_count = Map.get(votes, :agree, 0)
    disagree_count = Map.get(votes, :disagree, 0)
    abstain_count = Map.get(votes, :abstain, 0)
    
    total_votes = agree_count + disagree_count + abstain_count
    
    # Determine outcome
    outcome =
      cond do
        agree_count > disagree_count -> :agreed
        disagree_count > agree_count -> :rejected
        true -> :tied
      end
    
    result = %{
      outcome: outcome,
      agree_count: agree_count,
      agree_percentage: if total_votes > 0, do: agree_count / total_votes, else: 0,
      disagree_count: disagree_count,
      disagree_percentage: if total_votes > 0, do: disagree_count / total_votes, else: 0,
      abstain_count: abstain_count,
      abstain_percentage: if total_votes > 0, do: abstain_count / total_votes, else: 0,
      total_votes: total_votes,
      quorum_reached: has_quorum?(process_data)
    }
    
    # Update metadata
    updated_metadata = Map.update!(
      process_data.metadata,
      :rounds,
      &(&1 ++ [%{type: :simple_majority, votes: votes, result: result}])
    )
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_super_majority(process_data, threshold) do
    # Count votes
    votes = count_votes(process_data.inputs)
    
    agree_count = Map.get(votes, :agree, 0)
    disagree_count = Map.get(votes, :disagree, 0)
    abstain_count = Map.get(votes, :abstain, 0)
    
    total_votes = agree_count + disagree_count + abstain_count
    
    # Determine outcome
    outcome =
      cond do
        total_votes == 0 -> :no_votes
        agree_count / total_votes >= threshold -> :agreed
        disagree_count / total_votes >= threshold -> :rejected
        true -> :no_consensus
      end
    
    result = %{
      outcome: outcome,
      threshold: threshold,
      agree_count: agree_count,
      agree_percentage: if total_votes > 0, do: agree_count / total_votes, else: 0,
      disagree_count: disagree_count,
      disagree_percentage: if total_votes > 0, do: disagree_count / total_votes, else: 0,
      abstain_count: abstain_count,
      abstain_percentage: if total_votes > 0, do: abstain_count / total_votes, else: 0,
      total_votes: total_votes,
      quorum_reached: has_quorum?(process_data)
    }
    
    # Update metadata
    updated_metadata = Map.update!(
      process_data.metadata,
      :rounds,
      &(&1 ++ [%{type: :super_majority, threshold: threshold, votes: votes, result: result}])
    )
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_unanimous(process_data) do
    # Count votes
    votes = count_votes(process_data.inputs)
    
    agree_count = Map.get(votes, :agree, 0)
    disagree_count = Map.get(votes, :disagree, 0)
    abstain_count = Map.get(votes, :abstain, 0)
    
    total_participants = map_size(process_data.participants)
    total_votes = agree_count + disagree_count + abstain_count
    
    # Determine outcome
    outcome =
      cond do
        disagree_count > 0 -> :rejected
        agree_count == total_participants -> :agreed
        agree_count + abstain_count == total_votes -> :agreed_with_abstentions
        true -> :incomplete
      end
    
    result = %{
      outcome: outcome,
      agree_count: agree_count,
      agree_percentage: if total_votes > 0, do: agree_count / total_votes, else: 0,
      disagree_count: disagree_count,
      disagree_percentage: if total_votes > 0, do: disagree_count / total_votes, else: 0,
      abstain_count: abstain_count,
      abstain_percentage: if total_votes > 0, do: abstain_count / total_votes, else: 0,
      total_votes: total_votes,
      total_participants: total_participants,
      quorum_reached: has_quorum?(process_data)
    }
    
    # Update metadata
    updated_metadata = Map.update!(
      process_data.metadata,
      :rounds,
      &(&1 ++ [%{type: :unanimous, votes: votes, result: result}])
    )
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_distributed_paxos(process_data) do
    # Simplified Paxos implementation
    current_round = process_data.metadata.current_round
    max_rounds = Map.get(process_data.config.custom_parameters, :max_rounds, 3)
    
    if current_round >= max_rounds do
      # Final round, determine result based on proposal acceptance
      algorithm_state = process_data.metadata.algorithm_state
      
      if algorithm_state.accepted_value != nil do
        result = %{
          outcome: :consensus_reached,
          value: algorithm_state.accepted_value,
          round: current_round,
          acceptors: algorithm_state.acceptors,
          quorum_reached: true
        }
        
        # Update metadata
        updated_metadata = Map.update!(
          process_data.metadata,
          :rounds,
          &(&1 ++ [%{type: :distributed_paxos, round: current_round, result: result}])
        )
        
        {:ok, result, updated_metadata}
      else
        result = %{
          outcome: :no_consensus,
          round: current_round,
          proposed_values: algorithm_state.proposed_values,
          quorum_reached: false
        }
        
        # Update metadata
        updated_metadata = Map.update!(
          process_data.metadata,
          :rounds,
          &(&1 ++ [%{type: :distributed_paxos, round: current_round, result: result}])
        )
        
        {:ok, result, updated_metadata}
      end
    else
      # Process current round
      {updated_state, is_decided} = process_paxos_round(process_data)
      
      if is_decided do
        result = %{
          outcome: :consensus_reached,
          value: updated_state.algorithm_state.accepted_value,
          round: current_round,
          acceptors: updated_state.algorithm_state.acceptors,
          quorum_reached: true
        }
        
        # Update metadata with round results
        updated_metadata = Map.update!(
          updated_state.metadata,
          :rounds,
          &(&1 ++ [%{type: :distributed_paxos, round: current_round, result: result}])
        )
        
        # Move to next round
        next_round_metadata = %{
          updated_metadata |
          current_round: current_round + 1
        }
        
        {:ok, result, next_round_metadata}
      else
        # Continue to next round
        updated_metadata = Map.update!(
          updated_state.metadata,
          :rounds,
          &(&1 ++ [%{type: :distributed_paxos, round: current_round, status: :continuing}])
        )
        
        next_round_metadata = %{
          updated_metadata |
          current_round: current_round + 1
        }
        
        {:continue, next_round_metadata}
      end
    end
  end
  
  defp apply_practical_byzantine(process_data) do
    # Simplified PBFT implementation
    current_round = process_data.metadata.current_round
    max_rounds = Map.get(process_data.config.custom_parameters, :max_rounds, 3)
    
    if current_round >= max_rounds do
      # Final round, determine result
      algorithm_state = process_data.metadata.algorithm_state
      
      if algorithm_state.committed_value != nil do
        result = %{
          outcome: :consensus_reached,
          value: algorithm_state.committed_value,
          round: current_round,
          validations: algorithm_state.validations,
          quorum_reached: true
        }
        
        # Update metadata
        updated_metadata = Map.update!(
          process_data.metadata,
          :rounds,
          &(&1 ++ [%{type: :practical_byzantine, round: current_round, result: result}])
        )
        
        {:ok, result, updated_metadata}
      else
        result = %{
          outcome: :no_consensus,
          round: current_round,
          proposed_values: algorithm_state.proposed_values,
          quorum_reached: false
        }
        
        # Update metadata
        updated_metadata = Map.update!(
          process_data.metadata,
          :rounds,
          &(&1 ++ [%{type: :distributed_paxos, round: current_round, result: result}])
        )
        
        {:ok, result, updated_metadata}
      end
    else
      # Process current round
      {updated_state, is_decided} = process_pbft_round(process_data)
      
      if is_decided do
        result = %{
          outcome: :consensus_reached,
          value: updated_state.algorithm_state.committed_value,
          round: current_round,
          validations: updated_state.algorithm_state.validations,
          quorum_reached: true
        }
        
        # Update metadata with round results
        updated_metadata = Map.update!(
          updated_state.metadata,
          :rounds,
          &(&1 ++ [%{type: :practical_byzantine, round: current_round, result: result}])
        )
        
        # Move to next round
        next_round_metadata = %{
          updated_metadata |
          current_round: current_round + 1
        }
        
        {:ok, result, next_round_metadata}
      else
        # Continue to next round
        updated_metadata = Map.update!(
          updated_state.metadata,
          :rounds,
          &(&1 ++ [%{type: :practical_byzantine, round: current_round, status: :continuing}])
        )
        
        next_round_metadata = %{
          updated_metadata |
          current_round: current_round + 1
        }
        
        {:continue, next_round_metadata}
      end
    end
  end
  
  defp count_votes(inputs) do
    Enum.reduce(inputs, %{agree: 0, disagree: 0, abstain: 0}, fn {_, input}, acc ->
      position = Map.get(input, :position, :abstain)
      Map.update(acc, position, 1, &(&1 + 1))
    end)
  end
  
  defp initialize_algorithm_state(config) do
    case config.custom_parameters.algorithm do
      :distributed_paxos ->
        %{
          highest_proposal: 0,
          proposed_values: %{},
          promised: %{},
          accepted_value: nil,
          acceptors: %{}
        }
        
      :practical_byzantine ->
        %{
          pre_prepare_phase: %{},
          prepare_phase: %{},
          commit_phase: %{},
          proposed_values: %{},
          prepared_value: nil,
          committed_value: nil,
          validations: %{}
        }
        
      _ ->
        %{}
    end
  end
  
  defp process_paxos_round(process_data) do
    # This is a simplified Paxos implementation
    algorithm_state = process_data.metadata.algorithm_state
    total_participants = map_size(process_data.participants)
    
    # Extract proposals
    proposals = 
      Enum.map(process_data.inputs, fn {participant_id, input} ->
        {participant_id, Map.get(input, :proposal)}
      end)
      |> Enum.filter(fn {_, proposal} -> proposal != nil end)
      |> Map.new()
    
    # Update proposed values
    updated_state = %{algorithm_state | proposed_values: proposals}
    
    # Check for majority value
    value_counts = 
      proposals
      |> Map.values()
      |> Enum.frequencies()
    
    # Find if any value has majority
    {majority_value, is_decided} =
      Enum.find(value_counts, {nil, false}, fn {_, count} -> 
        count > total_participants / 2
      end)
      |> case do
        {value, count} when count > total_participants / 2 -> {value, true}
        _ -> {nil, false}
      end
    
    # Update state with accepted value if decided
    final_state =
      if is_decided do
        # Record acceptors
        acceptors = 
          Enum.filter(proposals, fn {_, value} -> value == majority_value end)
          |> Map.keys()
          |> Enum.map(fn id -> {id, true} end)
          |> Map.new()
        
        %{updated_state | 
          accepted_value: majority_value,
          acceptors: acceptors
        }
      else
        updated_state
      end
    
    updated_process_data = %{
      process_data |
      metadata: %{process_data.metadata | algorithm_state: final_state}
    }
    
    {updated_process_data, is_decided}
  end
  
  defp process_pbft_round(process_data) do
    # This is a simplified PBFT implementation
    algorithm_state = process_data.metadata.algorithm_state
    total_participants = map_size(process_data.participants)
    
    # Extract values
    values = 
      Enum.map(process_data.inputs, fn {participant_id, input} ->
        {participant_id, Map.get(input, :value)}
      end)
      |> Enum.filter(fn {_, value} -> value != nil end)
      |> Map.new()
    
    # Update proposed values
    updated_state = %{algorithm_state | proposed_values: values}
    
    # Check for majority value (2f+1 where f is max faulty nodes)
    # For simplicity, we assume f = (n-1)/3 (Byzantine tolerance)
    max_faulty = Float.floor((total_participants - 1) / 3)
    required_votes = 2 * max_faulty + 1
    
    value_counts = 
      values
      |> Map.values()
      |> Enum.frequencies()
    
    # Find if any value has required votes
    {majority_value, is_decided} =
      Enum.find(value_counts, {nil, false}, fn {_, count} -> 
        count >= required_votes
      end)
      |> case do
        {value, count} when count >= required_votes -> {value, true}
        _ -> {nil, false}
      end
    
    # Update state with committed value if decided
    final_state =
      if is_decided do
        # Record validations
        validations = 
          Enum.filter(values, fn {_, value} -> value == majority_value end)
          |> Map.keys()
          |> Enum.map(fn id -> {id, true} end)
          |> Map.new()
        
        %{updated_state | 
          committed_value: majority_value,
          validations: validations
        }
      else
        updated_state
      end
    
    updated_process_data = %{
      process_data |
      metadata: %{process_data.metadata | algorithm_state: final_state}
    }
    
    {updated_process_data, is_decided}
  end
  
  defp enrich_with_knowledge(process_data, context_id) do
    # Fetch relevant context from the knowledge system
    case KnowledgeSystem.get_context(context_id) do
      {:ok, context} ->
        # Extract relevant information to enrich the process
        metadata = Map.put(process_data.metadata, :knowledge_context, %{
          context_id: context_id,
          relevant_concepts: context.concepts,
          relevant_relations: context.relations
        })
        
        %{process_data | metadata: metadata}
        
      _ ->
        # Context not found or error, continue without enrichment
        process_data
    end
  end
end