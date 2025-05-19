defmodule Automata.CollectiveIntelligence.DecisionProcesses.Preference do
  @moduledoc """
  Implements preference aggregation mechanisms for collective decision-making.
  
  This module provides various methods for combining individual preferences into
  collective decisions while addressing fairness, strategy-proofness, and other
  social choice properties. It handles preference elicitation, aggregation, and
  result determination with configurable preference models.
  """
  
  alias Automata.CollectiveIntelligence.DecisionProcesses.DecisionProcess
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @behaviour DecisionProcess
  
  @aggregation_methods [
    :kemeny_young,
    :social_welfare,
    :rank_aggregation,
    :approval_voting,
    :range_voting,
    :fuzzy_preferences
  ]
  
  @preference_models [
    :total_order,
    :partial_order,
    :utility_function,
    :fuzzy_relation
  ]
  
  # DecisionProcess callbacks
  
  @impl DecisionProcess
  def initialize(config) do
    # Validate config
    with :ok <- validate_config(config) do
      # Extract options from config
      alternatives = Map.get(config.custom_parameters, :alternatives, [])
      
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
          alternatives: alternatives,
          preferences: %{},
          aggregation_method: Map.get(config.custom_parameters, :aggregation_method, :kemeny_young),
          preference_model: Map.get(config.custom_parameters, :preference_model, :total_order),
          criteria: Map.get(config.custom_parameters, :criteria, [])
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
          # For preference aggregation, we might assign weight to participants
          weight = Map.get(params, :weight, 1.0)
          
          # Stakeholder group for group preference analysis
          group = Map.get(params, :group, :default)
          
          updated_participants = Map.put(process_data.participants, participant_id, %{
            registered_at: DateTime.utc_now(),
            params: params,
            weight: weight,
            group: group
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
        # Validate input based on preference model
        preference_model = process_data.metadata.preference_model
        
        with :ok <- validate_preferences(
          input, 
          preference_model, 
          process_data.metadata.alternatives,
          process_data.metadata.criteria
        ) do
          # Store the preference
          updated_preferences = Map.put(
            process_data.metadata.preferences, 
            participant_id, 
            %{
              preference_data: input,
              weight: process_data.participants[participant_id].weight,
              group: process_data.participants[participant_id].group,
              timestamp: DateTime.utc_now()
            }
          )
          
          updated_metadata = %{
            process_data.metadata |
            preferences: updated_preferences
          }
          
          # Also store in inputs for standard interface
          updated_inputs = Map.put(process_data.inputs, participant_id, input)
          
          updated_data = %{
            process_data |
            inputs: updated_inputs,
            metadata: updated_metadata,
            updated_at: DateTime.utc_now()
          }
          
          # Check if we have enough preferences to advance to deliberation
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
      # Apply the specific preference aggregation method
      aggregation_method = process_data.metadata.aggregation_method
      
      case aggregate_preferences(process_data, aggregation_method) do
        {:ok, result, updated_metadata} ->
          updated_data = %{
            process_data |
            state: :decided,
            result: result,
            updated_at: DateTime.utc_now(),
            metadata: updated_metadata
          }
          
          {:ok, updated_data, result}
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
  
  @impl DecisionProcess
  def can_close?(process_data) do
    # A process can be closed if:
    # 1. It has reached a decision, or
    # 2. It has enough participants and preferences to compute a result
    
    process_data.state == :decided ||
      (process_data.state == :deliberating && has_quorum?(process_data))
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
      # Validate custom parameters for preference aggregation
      custom_params = config.custom_parameters || %{}
      
      # Validate aggregation method
      aggregation_method = Map.get(custom_params, :aggregation_method, :kemeny_young)
      
      if aggregation_method not in @aggregation_methods do
        {:error, {:invalid_aggregation_method, aggregation_method, @aggregation_methods}}
      else
        # Validate preference model
        preference_model = Map.get(custom_params, :preference_model, :total_order)
        
        if preference_model not in @preference_models do
          {:error, {:invalid_preference_model, preference_model, @preference_models}}
        else
          # Validate alternatives
          alternatives = Map.get(custom_params, :alternatives, [])
          
          if length(alternatives) < 2 do
            {:error, {:insufficient_alternatives, length(alternatives)}}
          else
            # Custom validation for specific methods
            case aggregation_method do
              :social_welfare when not Map.has_key?(custom_params, :welfare_function) ->
                {:error, :missing_welfare_function}
                
              _ ->
                :ok
            end
          end
        end
      end
    end
  end
  
  defp validate_preferences(input, preference_model, alternatives, criteria) do
    case preference_model do
      :total_order ->
        validate_total_order(input, alternatives)
        
      :partial_order ->
        validate_partial_order(input, alternatives)
        
      :utility_function ->
        validate_utility_function(input, alternatives, criteria)
        
      :fuzzy_relation ->
        validate_fuzzy_relation(input, alternatives)
    end
  end
  
  defp validate_total_order(input, alternatives) do
    # Total order should provide a complete ranking of alternatives
    if not Map.has_key?(input, :ranking) do
      {:error, :missing_ranking}
    else
      ranking = input.ranking
      
      # Check if all alternatives are included
      all_included = Enum.all?(alternatives, &(&1 in ranking))
      
      # Check if only valid alternatives are included
      only_valid = Enum.all?(ranking, &(&1 in alternatives))
      
      # Check for duplicates
      no_duplicates = length(Enum.uniq(ranking)) == length(ranking)
      
      cond do
        not all_included ->
          missing = alternatives -- ranking
          {:error, {:missing_alternatives, missing}}
          
        not only_valid ->
          invalid = ranking -- alternatives
          {:error, {:invalid_alternatives, invalid}}
          
        not no_duplicates ->
          duplicates = ranking -- Enum.uniq(ranking)
          {:error, {:duplicate_alternatives, duplicates}}
          
        true ->
          :ok
      end
    end
  end
  
  defp validate_partial_order(input, alternatives) do
    # Partial order should provide preference relations
    if not Map.has_key?(input, :preferences) do
      {:error, :missing_preferences}
    else
      preferences = input.preferences
      
      # Check if all relations involve valid alternatives
      valid_relations = Enum.all?(preferences, fn {a, b} -> 
        a in alternatives and b in alternatives
      end)
      
      # Check for cycles (transitivity violations)
      has_cycle = has_preference_cycle?(preferences)
      
      cond do
        not valid_relations ->
          invalid = Enum.filter(preferences, fn {a, b} -> 
            a not in alternatives or b not in alternatives
          end)
          {:error, {:invalid_relations, invalid}}
          
        has_cycle ->
          {:error, :preference_cycle_detected}
          
        true ->
          :ok
      end
    end
  end
  
  defp validate_utility_function(input, alternatives, criteria) do
    # Utility function should provide utility values for each alternative
    if not Map.has_key?(input, :utilities) do
      {:error, :missing_utilities}
    else
      utilities = input.utilities
      
      # Check if all alternatives have utilities
      all_included = Enum.all?(alternatives, &Map.has_key?(utilities, &1))
      
      # Check if only valid alternatives are included
      only_valid = Enum.all?(Map.keys(utilities), &(&1 in alternatives))
      
      # Check if utilities are in valid range (0-1 or 0-100)
      valid_range = Enum.all?(Map.values(utilities), fn u -> 
        is_number(u) and u >= 0 and u <= 100
      end)
      
      # Check if multi-criteria utilities are provided when criteria are defined
      valid_criteria = 
        if length(criteria) > 0 do
          # Should have nested criteria structure
          Enum.all?(Map.values(utilities), fn u ->
            is_map(u) and Enum.all?(criteria, &Map.has_key?(u, &1))
          end)
        else
          true
        end
      
      cond do
        not all_included ->
          missing = alternatives -- Map.keys(utilities)
          {:error, {:missing_utility_values, missing}}
          
        not only_valid ->
          invalid = Map.keys(utilities) -- alternatives
          {:error, {:invalid_alternatives_in_utilities, invalid}}
          
        not valid_range ->
          invalid = Enum.filter(utilities, fn {_, u} -> 
            not (is_number(u) and u >= 0 and u <= 100)
          end)
          {:error, {:invalid_utility_values, invalid}}
          
        not valid_criteria ->
          {:error, :missing_criteria_in_utilities}
          
        true ->
          :ok
      end
    end
  end
  
  defp validate_fuzzy_relation(input, alternatives) do
    # Fuzzy relation should provide membership degrees for each pair
    if not Map.has_key?(input, :fuzzy_preferences) do
      {:error, :missing_fuzzy_preferences}
    else
      fuzzy_preferences = input.fuzzy_preferences
      
      # Check if relations involve valid alternatives
      valid_relations = Enum.all?(fuzzy_preferences, fn {{a, b}, _degree} -> 
        a in alternatives and b in alternatives
      end)
      
      # Check if degrees are in [0,1] range
      valid_degrees = Enum.all?(fuzzy_preferences, fn {_pair, degree} -> 
        is_float(degree) and degree >= 0 and degree <= 1
      end)
      
      cond do
        not valid_relations ->
          invalid = Enum.filter(fuzzy_preferences, fn {{a, b}, _} -> 
            a not in alternatives or b not in alternatives
          end)
          {:error, {:invalid_relations, invalid}}
          
        not valid_degrees ->
          invalid = Enum.filter(fuzzy_preferences, fn {_, degree} -> 
            not (is_float(degree) and degree >= 0 and degree <= 1)
          end)
          {:error, {:invalid_degrees, invalid}}
          
        true ->
          :ok
      end
    end
  end
  
  defp has_preference_cycle?(preferences) do
    # Build directed graph
    graph = Enum.reduce(preferences, %{}, fn {a, b}, acc ->
      Map.update(acc, a, [b], fn nodes -> [b | nodes] end)
    end)
    
    # Check for cycles using DFS
    nodes = 
      (Enum.map(preferences, fn {a, _} -> a end) ++ Enum.map(preferences, fn {_, b} -> b end))
      |> Enum.uniq()
      
    Enum.any?(nodes, fn node ->
      has_cycle_from_node?(graph, node, [node], MapSet.new())
    end)
  end
  
  defp has_cycle_from_node?(graph, node, path, visited) do
    neighbors = Map.get(graph, node, [])
    
    Enum.any?(neighbors, fn neighbor ->
      if neighbor in path do
        # Cycle detected
        true
      else
        if MapSet.member?(visited, neighbor) do
          # Already visited this path, no cycle
          false
        else
          # Continue DFS
          has_cycle_from_node?(
            graph,
            neighbor,
            [neighbor | path],
            MapSet.put(visited, neighbor)
          )
        end
      end
    end)
  end
  
  defp should_advance_to_deliberation?(process_data) do
    # Check if we have enough participants
    has_min_participants =
      map_size(process_data.participants) >= process_data.config.min_participants
    
    # Check if we have enough preferences
    has_quorum?(process_data) && has_min_participants
  end
  
  defp has_quorum?(process_data) do
    participant_count = map_size(process_data.participants)
    preference_count = map_size(process_data.metadata.preferences)
    
    if participant_count == 0 do
      false
    else
      # Calculate the actual quorum requirement
      required_quorum = process_data.config.quorum || 0.5
      
      preference_ratio = preference_count / participant_count
      preference_ratio >= required_quorum
    end
  end
  
  defp aggregate_preferences(process_data, aggregation_method) do
    case aggregation_method do
      :kemeny_young ->
        apply_kemeny_young(process_data)
        
      :social_welfare ->
        apply_social_welfare(process_data)
        
      :rank_aggregation ->
        apply_rank_aggregation(process_data)
        
      :approval_voting ->
        apply_approval_voting(process_data)
        
      :range_voting ->
        apply_range_voting(process_data)
        
      :fuzzy_preferences ->
        apply_fuzzy_preferences(process_data)
    end
  end
  
  defp apply_kemeny_young(process_data) do
    # Implement Kemeny-Young method
    # Finds the ranking that minimizes the sum of Kendall tau distances
    # to all input rankings
    preferences = process_data.metadata.preferences
    alternatives = process_data.metadata.alternatives
    
    # Extract rankings from preferences
    rankings = 
      Enum.map(preferences, fn {_participant_id, preference} ->
        {preference.preference_data.ranking, preference.weight}
      end)
    
    # Compute pairwise contest matrix
    contest_matrix = compute_contest_matrix(rankings, alternatives)
    
    # Approximate optimal ranking using a greedy algorithm
    # For a small number of alternatives, we could compute the exact solution
    # by evaluating all permutations
    if length(alternatives) <= 8 do
      # Exact solution for small sets
      optimal_ranking = find_exact_kemeny_ranking(contest_matrix, alternatives)
      
      # Compute the score of the optimal ranking
      optimal_score = compute_kemeny_score(optimal_ranking, contest_matrix)
      
      # Create result
      result = %{
        aggregation_method: :kemeny_young,
        optimal_ranking: optimal_ranking,
        optimal_score: optimal_score,
        contest_matrix: contest_matrix,
        exact_solution: true
      }
      
      # Update metadata
      updated_metadata = Map.put(process_data.metadata, :aggregation_result, result)
      
      {:ok, result, updated_metadata}
    else
      # Approximate solution for larger sets
      approximate_ranking = find_approximate_kemeny_ranking(contest_matrix, alternatives)
      
      # Compute the score of the approximate ranking
      approximate_score = compute_kemeny_score(approximate_ranking, contest_matrix)
      
      # Create result
      result = %{
        aggregation_method: :kemeny_young,
        optimal_ranking: approximate_ranking,
        optimal_score: approximate_score,
        contest_matrix: contest_matrix,
        exact_solution: false
      }
      
      # Update metadata
      updated_metadata = Map.put(process_data.metadata, :aggregation_result, result)
      
      {:ok, result, updated_metadata}
    end
  end
  
  defp apply_social_welfare(process_data) do
    # Implement social welfare function
    # Aggregates utilities using a welfare function
    preferences = process_data.metadata.preferences
    alternatives = process_data.metadata.alternatives
    welfare_function = 
      Map.get(process_data.config.custom_parameters, :welfare_function, :utilitarian)
    
    # Extract utilities from preferences
    utilities = 
      Enum.map(preferences, fn {participant_id, preference} ->
        {participant_id, preference.preference_data.utilities, preference.weight}
      end)
    
    # Apply welfare function
    {welfare_values, welfare_type} = compute_social_welfare(utilities, alternatives, welfare_function)
    
    # Find alternative with highest welfare
    {best_alternative, best_value} = 
      Enum.max_by(welfare_values, fn {_alt, value} -> value end, fn -> {nil, 0} end)
    
    # Create result
    result = %{
      aggregation_method: :social_welfare,
      welfare_function: welfare_function,
      welfare_type: welfare_type,
      welfare_values: welfare_values,
      best_alternative: best_alternative,
      best_value: best_value,
      individual_utilities: Map.new(utilities, fn {id, utils, _weight} -> {id, utils} end)
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :aggregation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_rank_aggregation(process_data) do
    # Implement rank aggregation
    # Combines multiple ranking methods
    preferences = process_data.metadata.preferences
    alternatives = process_data.metadata.alternatives
    
    # Extract rankings from preferences
    rankings = 
      Enum.map(preferences, fn {_participant_id, preference} ->
        {preference.preference_data.ranking, preference.weight}
      end)
    
    # Apply multiple methods
    borda_ranking = compute_borda_ranking(rankings, alternatives)
    copeland_ranking = compute_copeland_ranking(rankings, alternatives)
    
    # Also try Kemeny-Young for a more robust aggregation
    contest_matrix = compute_contest_matrix(rankings, alternatives)
    kemeny_ranking = 
      if length(alternatives) <= 8 do
        find_exact_kemeny_ranking(contest_matrix, alternatives)
      else
        find_approximate_kemeny_ranking(contest_matrix, alternatives)
      end
    
    # Combine all rankings into a meta-ranking
    # Here we use a simple Borda count on the method results
    method_rankings = [borda_ranking, copeland_ranking, kemeny_ranking]
    
    # Assign points based on position in each ranking
    meta_scores = 
      Enum.reduce(method_rankings, Map.new(alternatives, fn alt -> {alt, 0} end), fn ranking, scores ->
        Enum.with_index(ranking, fn alt, idx ->
          points = length(alternatives) - idx - 1
          Map.update!(scores, alt, &(&1 + points))
        end)
        
        scores
      end)
    
    # Sort alternatives by meta-scores
    meta_ranking = 
      Enum.sort_by(alternatives, fn alt -> Map.get(meta_scores, alt, 0) end, :desc)
    
    # Create result
    result = %{
      aggregation_method: :rank_aggregation,
      borda_ranking: borda_ranking,
      copeland_ranking: copeland_ranking,
      kemeny_ranking: kemeny_ranking,
      meta_ranking: meta_ranking,
      meta_scores: meta_scores
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :aggregation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_approval_voting(process_data) do
    # Implement approval voting
    # Each participant approves or disapproves each alternative
    preferences = process_data.metadata.preferences
    alternatives = process_data.metadata.alternatives
    
    # Extract approvals from preferences
    approvals = 
      Enum.map(preferences, fn {_participant_id, preference} ->
        {preference.preference_data.approvals, preference.weight}
      end)
    
    # Count approvals for each alternative
    approval_scores = 
      Enum.reduce(approvals, Map.new(alternatives, fn alt -> {alt, 0} end), fn {participant_approvals, weight}, scores ->
        Enum.reduce(participant_approvals, scores, fn alt, inner_scores ->
          Map.update!(inner_scores, alt, &(&1 + weight))
        end)
      end)
    
    # Rank alternatives by approval scores
    ranking = 
      Enum.sort_by(alternatives, fn alt -> Map.get(approval_scores, alt, 0) end, :desc)
    
    # Calculate approval ratios
    total_weight = Enum.sum(Enum.map(preferences, fn {_, p} -> p.weight end))
    
    approval_ratios = 
      Map.new(approval_scores, fn {alt, score} -> {alt, score / total_weight} end)
    
    # Create result
    result = %{
      aggregation_method: :approval_voting,
      approval_scores: approval_scores,
      approval_ratios: approval_ratios,
      ranking: ranking,
      winner: hd(ranking),
      total_participants: length(preferences),
      total_weight: total_weight
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :aggregation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_range_voting(process_data) do
    # Implement range voting
    # Each participant assigns scores to alternatives
    preferences = process_data.metadata.preferences
    alternatives = process_data.metadata.alternatives
    criteria = process_data.metadata.criteria
    
    # Extract scores from preferences
    if length(criteria) > 0 do
      # Multi-criteria range voting
      apply_multicriteria_range_voting(process_data)
    else
      # Standard range voting
      scores = 
        Enum.map(preferences, fn {_participant_id, preference} ->
          {preference.preference_data.scores, preference.weight}
        end)
      
      # Compute weighted average for each alternative
      range_scores = 
        Enum.reduce(scores, Map.new(alternatives, fn alt -> {alt, 0} end), fn {participant_scores, weight}, acc_scores ->
          Enum.reduce(participant_scores, acc_scores, fn {alt, score}, inner_scores ->
            Map.update!(inner_scores, alt, &(&1 + score * weight))
          end)
        end)
      
      # Normalize by total weight
      total_weight = Enum.sum(Enum.map(preferences, fn {_, p} -> p.weight end))
      normalized_scores = 
        Map.new(range_scores, fn {alt, score} -> {alt, score / total_weight} end)
      
      # Rank alternatives by scores
      ranking = 
        Enum.sort_by(alternatives, fn alt -> Map.get(normalized_scores, alt, 0) end, :desc)
      
      # Create result
      result = %{
        aggregation_method: :range_voting,
        range_scores: range_scores,
        normalized_scores: normalized_scores,
        ranking: ranking,
        winner: hd(ranking),
        total_participants: length(preferences),
        total_weight: total_weight
      }
      
      # Update metadata
      updated_metadata = Map.put(process_data.metadata, :aggregation_result, result)
      
      {:ok, result, updated_metadata}
    end
  end
  
  defp apply_multicriteria_range_voting(process_data) do
    # Implement multi-criteria range voting
    preferences = process_data.metadata.preferences
    alternatives = process_data.metadata.alternatives
    criteria = process_data.metadata.criteria
    criteria_weights = Map.get(process_data.config.custom_parameters, :criteria_weights, %{})
    
    # Set default weights if not provided
    normalized_weights = 
      if map_size(criteria_weights) == 0 do
        # Equal weights
        weight = 1.0 / length(criteria)
        Map.new(criteria, fn c -> {c, weight} end)
      else
        # Normalize provided weights
        total = Enum.sum(Map.values(criteria_weights))
        Map.new(criteria_weights, fn {c, w} -> {c, w / total} end)
      end
    
    # Extract scores from preferences
    multicriteria_scores = 
      Enum.map(preferences, fn {_participant_id, preference} ->
        {preference.preference_data.criteria_scores, preference.weight}
      end)
    
    # Compute weighted average for each alternative and criterion
    criteria_scores = 
      Enum.reduce(criteria, %{}, fn criterion, acc_criteria ->
        # For each criterion, compute scores across alternatives
        criterion_scores = 
          Enum.reduce(multicriteria_scores, Map.new(alternatives, fn alt -> {alt, 0} end), fn {participant_scores, weight}, acc_scores ->
            Enum.reduce(alternatives, acc_scores, fn alt, inner_scores ->
              score = get_in(participant_scores, [alt, criterion]) || 0
              Map.update!(inner_scores, alt, &(&1 + score * weight))
            end)
          end)
        
        Map.put(acc_criteria, criterion, criterion_scores)
      end)
    
    # Compute aggregate scores using criteria weights
    total_weight = Enum.sum(Enum.map(preferences, fn {_, p} -> p.weight end))
    
    aggregate_scores = 
      Enum.reduce(alternatives, %{}, fn alt, acc_alts ->
        # For each alternative, compute weighted sum of criteria scores
        alt_score = 
          Enum.reduce(criteria, 0, fn criterion, acc_score ->
            criterion_weight = Map.get(normalized_weights, criterion, 0)
            criterion_score = get_in(criteria_scores, [criterion, alt]) || 0
            
            # Normalize by total participant weight
            normalized_score = criterion_score / total_weight
            
            # Add weighted criterion score
            acc_score + (normalized_score * criterion_weight)
          end)
        
        Map.put(acc_alts, alt, alt_score)
      end)
    
    # Rank alternatives by aggregate scores
    ranking = 
      Enum.sort_by(alternatives, fn alt -> Map.get(aggregate_scores, alt, 0) end, :desc)
    
    # Create result
    result = %{
      aggregation_method: :range_voting,
      subtype: :multicriteria,
      criteria: criteria,
      criteria_weights: normalized_weights,
      criteria_scores: criteria_scores,
      aggregate_scores: aggregate_scores,
      ranking: ranking,
      winner: hd(ranking),
      total_participants: length(preferences),
      total_weight: total_weight
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :aggregation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_fuzzy_preferences(process_data) do
    # Implement fuzzy preference aggregation
    preferences = process_data.metadata.preferences
    alternatives = process_data.metadata.alternatives
    
    # Extract fuzzy preferences from inputs
    fuzzy_relations = 
      Enum.map(preferences, fn {_participant_id, preference} ->
        {preference.preference_data.fuzzy_preferences, preference.weight}
      end)
    
    # Aggregate fuzzy relations (weighted average)
    total_weight = Enum.sum(Enum.map(preferences, fn {_, p} -> p.weight end))
    
    # Initialize empty relation
    empty_relation = 
      for a <- alternatives, b <- alternatives, a != b, into: %{} do
        {{a, b}, 0.0}
      end
    
    # Compute weighted average of fuzzy relations
    aggregated_relation = 
      Enum.reduce(fuzzy_relations, empty_relation, fn {relation, weight}, acc_relation ->
        Enum.reduce(relation, acc_relation, fn {{a, b}, degree}, inner_acc ->
          Map.update!(inner_acc, {a, b}, &(&1 + degree * weight / total_weight))
        end)
      end)
    
    # Compute fuzzy dominance for each alternative
    dominance_scores = 
      Enum.map(alternatives, fn a ->
        score = 
          Enum.sum(
            Enum.map(alternatives -- [a], fn b ->
              # a dominates b to degree aggregated_relation[{a, b}]
              # b dominates a to degree aggregated_relation[{b, a}]
              # net dominance = max(0, a_dominates_b - b_dominates_a)
              a_dom_b = Map.get(aggregated_relation, {a, b}, 0.0)
              b_dom_a = Map.get(aggregated_relation, {b, a}, 0.0)
              max(0, a_dom_b - b_dom_a)
            end)
          )
        
        {a, score}
      end)
      |> Map.new()
    
    # Rank alternatives by dominance scores
    ranking = 
      Enum.sort_by(alternatives, fn alt -> Map.get(dominance_scores, alt, 0) end, :desc)
    
    # Create result
    result = %{
      aggregation_method: :fuzzy_preferences,
      aggregated_relation: aggregated_relation,
      dominance_scores: dominance_scores,
      ranking: ranking,
      winner: hd(ranking),
      total_participants: length(preferences),
      total_weight: total_weight
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :aggregation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  # Helper functions for preference aggregation
  
  defp compute_contest_matrix(rankings, alternatives) do
    # Initialize contest matrix
    contest_matrix = 
      for a <- alternatives, b <- alternatives, a != b, into: %{} do
        {{a, b}, 0}
      end
    
    # Fill matrix with pairwise contests
    Enum.reduce(rankings, contest_matrix, fn {ranking, weight}, matrix ->
      # For each pair of alternatives, check who is preferred
      Enum.reduce(alternatives, matrix, fn a, outer_acc ->
        Enum.reduce(alternatives, outer_acc, fn b, inner_acc ->
          if a != b do
            # Find positions in ranking
            a_pos = Enum.find_index(ranking, &(&1 == a))
            b_pos = Enum.find_index(ranking, &(&1 == b))
            
            # If both are ranked, compare positions
            if a_pos != nil and b_pos != nil do
              if a_pos < b_pos do
                # a is preferred to b
                Map.update!(inner_acc, {a, b}, &(&1 + weight))
              else
                inner_acc
              end
            else
              inner_acc
            end
          else
            inner_acc
          end
        end)
      end)
    end)
  end
  
  defp find_exact_kemeny_ranking(contest_matrix, alternatives) do
    # Compute all permutations of alternatives
    all_perms = permutations(alternatives)
    
    # Score each permutation
    {best_perm, _best_score} = 
      Enum.map(all_perms, fn perm ->
        score = compute_kemeny_score(perm, contest_matrix)
        {perm, score}
      end)
      |> Enum.max_by(fn {_perm, score} -> score end)
    
    best_perm
  end
  
  defp find_approximate_kemeny_ranking(contest_matrix, alternatives) do
    # Use a greedy algorithm to approximate the Kemeny ranking
    # Start with the empty ranking
    remaining = alternatives
    ranking = []
    
    # While there are alternatives left to rank
    find_approximate_kemeny_ranking_iter(ranking, remaining, contest_matrix)
  end
  
  defp find_approximate_kemeny_ranking_iter(ranking, [], _contest_matrix), do: ranking
  
  defp find_approximate_kemeny_ranking_iter(ranking, remaining, contest_matrix) do
    # For each remaining alternative, compute its score when placed next
    scores = 
      Enum.map(remaining, fn alt ->
        score = 
          Enum.sum(
            Enum.map(ranking, fn ranked_alt ->
              # Score for (alt > ranked_alt)
              Map.get(contest_matrix, {alt, ranked_alt}, 0)
            end)
          )
        
        {alt, score}
      end)
    
    # Choose the alternative with the highest score
    {best_alt, _best_score} = Enum.max_by(scores, fn {_alt, score} -> score end)
    
    # Add to ranking and continue
    find_approximate_kemeny_ranking_iter(
      ranking ++ [best_alt],
      remaining -- [best_alt],
      contest_matrix
    )
  end
  
  defp compute_kemeny_score(ranking, contest_matrix) do
    # Score is sum of contest weights for pairs in the given order
    Enum.sum(
      Enum.flat_map(0..(length(ranking) - 2), fn i ->
        Enum.map((i + 1)..(length(ranking) - 1), fn j ->
          a = Enum.at(ranking, i)
          b = Enum.at(ranking, j)
          Map.get(contest_matrix, {a, b}, 0)
        end)
      end)
    )
  end
  
  defp compute_social_welfare(utilities, alternatives, welfare_function) do
    # Different social welfare functions
    case welfare_function do
      :utilitarian ->
        # Sum of utilities
        welfare = 
          Enum.reduce(alternatives, %{}, fn alt, acc ->
            value = 
              Enum.sum(
                Enum.map(utilities, fn {_id, utils, weight} ->
                  Map.get(utils, alt, 0) * weight
                end)
              )
            
            Map.put(acc, alt, value)
          end)
        
        {welfare, :sum}
        
      :egalitarian ->
        # Minimum utility
        welfare = 
          Enum.reduce(alternatives, %{}, fn alt, acc ->
            values = 
              Enum.map(utilities, fn {_id, utils, _weight} ->
                Map.get(utils, alt, 0)
              end)
            
            value = 
              if length(values) > 0 do
                Enum.min(values)
              else
                0
              end
            
            Map.put(acc, alt, value)
          end)
        
        {welfare, :min}
        
      :nash ->
        # Product of utilities
        welfare = 
          Enum.reduce(alternatives, %{}, fn alt, acc ->
            values = 
              Enum.map(utilities, fn {_id, utils, _weight} ->
                Map.get(utils, alt, 0)
              end)
            
            value = 
              if length(values) > 0 do
                Enum.reduce(values, 1, &(&1 * &2))
              else
                0
              end
            
            Map.put(acc, alt, value)
          end)
        
        {welfare, :product}
        
      :leximin ->
        # Lexicographic maximin
        welfare = 
          Enum.reduce(alternatives, %{}, fn alt, acc ->
            values = 
              Enum.map(utilities, fn {_id, utils, _weight} ->
                Map.get(utils, alt, 0)
              end)
              |> Enum.sort()
            
            Map.put(acc, alt, values)
          end)
        
        # For easy comparison, convert to a score that can be ordered
        ordered_welfare = 
          Enum.map(welfare, fn {alt, ordered_values} ->
            # Compute a score that prioritizes the minimum values
            # This is a simplification - true leximin would compare vectors lexicographically
            score = 
              Enum.with_index(ordered_values)
              |> Enum.map(fn {v, i} -> v * :math.pow(10, -i) end)
              |> Enum.sum()
            
            {alt, score}
          end)
          |> Map.new()
        
        {ordered_welfare, :leximin}
    end
  end
  
  defp compute_borda_ranking(rankings, alternatives) do
    # Initialize Borda scores
    borda_scores = Map.new(alternatives, fn alt -> {alt, 0} end)
    
    # Compute Borda scores
    scores = 
      Enum.reduce(rankings, borda_scores, fn {ranking, weight}, acc ->
        max_points = length(alternatives) - 1
        
        Enum.reduce(Enum.with_index(ranking), acc, fn {alt, index}, inner_acc ->
          points = (max_points - index) * weight
          Map.update!(inner_acc, alt, &(&1 + points))
        end)
      end)
    
    # Sort alternatives by Borda scores
    Enum.sort_by(alternatives, fn alt -> Map.get(scores, alt, 0) end, :desc)
  end
  
  defp compute_copeland_ranking(rankings, alternatives) do
    # Compute contest matrix
    contest_matrix = compute_contest_matrix(rankings, alternatives)
    
    # For each alternative, count how many other alternatives it beats
    copeland_scores = 
      Enum.map(alternatives, fn a ->
        wins = 
          Enum.count(alternatives -- [a], fn b ->
            Map.get(contest_matrix, {a, b}, 0) > Map.get(contest_matrix, {b, a}, 0)
          end)
        
        losses = 
          Enum.count(alternatives -- [a], fn b ->
            Map.get(contest_matrix, {a, b}, 0) < Map.get(contest_matrix, {b, a}, 0)
          end)
        
        score = wins - losses
        
        {a, score}
      end)
      |> Map.new()
    
    # Sort alternatives by Copeland scores
    Enum.sort_by(alternatives, fn alt -> Map.get(copeland_scores, alt, 0) end, :desc)
  end
  
  defp permutations([]), do: [[]]
  defp permutations(list) do
    for x <- list, y <- permutations(list -- [x]), do: [x | y]
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