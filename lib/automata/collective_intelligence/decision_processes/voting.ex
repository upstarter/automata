defmodule Automata.CollectiveIntelligence.DecisionProcesses.Voting do
  @moduledoc """
  Implements various voting systems for collective decision-making.
  
  This module provides implementations of different voting methods including
  plurality voting, ranked choice voting, approval voting, and other electoral
  systems. It handles ballot collection, vote counting, and result determination
  using configurable voting rules.
  """
  
  alias Automata.CollectiveIntelligence.DecisionProcesses.DecisionProcess
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @behaviour DecisionProcess
  
  @voting_systems [
    :plurality,
    :ranked_choice,
    :approval,
    :borda_count,
    :condorcet,
    :cumulative
  ]
  
  # DecisionProcess callbacks
  
  @impl DecisionProcess
  def initialize(config) do
    # Validate config
    with :ok <- validate_config(config) do
      # Extract options from config
      options = Map.get(config.custom_parameters, :options, [])
      
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
          options: options,
          votes: [],
          tallies: %{},
          voting_system: Map.get(config.custom_parameters, :voting_system, :plurality)
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
          # For voting, we can assign weights to voters if specified
          weight = Map.get(params, :weight, 1.0)
          
          updated_participants = Map.put(process_data.participants, participant_id, %{
            registered_at: DateTime.utc_now(),
            params: params,
            weight: weight
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
        # Validate input for the specific voting system
        voting_system = Map.get(process_data.metadata, :voting_system, :plurality)
        
        with :ok <- validate_ballot(input, voting_system, process_data.metadata.options) do
          # Record the vote with the participant's weight
          vote = %{
            participant_id: participant_id,
            ballot: input,
            weight: process_data.participants[participant_id].weight,
            timestamp: DateTime.utc_now()
          }
          
          updated_votes = Map.update!(process_data.metadata, :votes, &(&1 ++ [vote]))
          
          # Also store in inputs for standard interface
          updated_inputs = Map.put(process_data.inputs, participant_id, input)
          
          updated_data = %{
            process_data |
            inputs: updated_inputs,
            metadata: updated_votes,
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
      # Apply the specific voting system
      voting_system = Map.get(process_data.metadata, :voting_system, :plurality)
      
      case apply_voting_system(voting_system, process_data) do
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
    # 2. It has enough participants and inputs to compute a result
    
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
      # Validate custom parameters for voting
      custom_params = config.custom_parameters || %{}
      
      voting_system = Map.get(custom_params, :voting_system, :plurality)
      
      if voting_system not in @voting_systems do
        {:error, {:invalid_voting_system, voting_system, @voting_systems}}
      else
        # Validate options for voting
        options = Map.get(custom_params, :options, [])
        
        if length(options) < 2 do
          {:error, {:insufficient_options, length(options)}}
        else
          # Validate voting system specific parameters
          case voting_system do
            :ranked_choice ->
              if not Map.has_key?(custom_params, :num_winners) do
                # Default to 1 winner
                :ok
              else
                num_winners = Map.get(custom_params, :num_winners, 1)
                
                if num_winners < 1 do
                  {:error, {:invalid_num_winners, num_winners}}
                else
                  :ok
                end
              end
              
            :cumulative ->
              if not Map.has_key?(custom_params, :points_per_voter) do
                # Default to options length
                :ok
              else
                points = Map.get(custom_params, :points_per_voter, length(options))
                
                if points < 1 do
                  {:error, {:invalid_points_per_voter, points}}
                else
                  :ok
                end
              end
              
            _ ->
              :ok
          end
        end
      end
    end
  end
  
  defp validate_ballot(ballot, voting_system, options) do
    case voting_system do
      :plurality ->
        if not Map.has_key?(ballot, :selection) do
          {:error, :missing_selection}
        else
          selection = ballot.selection
          
          if selection not in options do
            {:error, {:invalid_selection, selection, options}}
          else
            :ok
          end
        end
        
      :ranked_choice ->
        if not Map.has_key?(ballot, :rankings) do
          {:error, :missing_rankings}
        else
          rankings = ballot.rankings
          
          # Check if all entries are valid options
          invalid_options = Enum.filter(rankings, &(&1 not in options))
          
          if length(invalid_options) > 0 do
            {:error, {:invalid_options_in_rankings, invalid_options}}
          else
            # Check for duplicates
            unique_rankings = Enum.uniq(rankings)
            
            if length(unique_rankings) != length(rankings) do
              {:error, :duplicate_rankings}
            else
              :ok
            end
          end
        end
        
      :approval ->
        if not Map.has_key?(ballot, :approvals) do
          {:error, :missing_approvals}
        else
          approvals = ballot.approvals
          
          # Check if all entries are valid options
          invalid_options = Enum.filter(approvals, &(&1 not in options))
          
          if length(invalid_options) > 0 do
            {:error, {:invalid_options_in_approvals, invalid_options}}
          else
            :ok
          end
        end
        
      :borda_count ->
        if not Map.has_key?(ballot, :rankings) do
          {:error, :missing_rankings}
        else
          rankings = ballot.rankings
          
          # Check if all entries are valid options
          invalid_options = Enum.filter(rankings, &(&1 not in options))
          
          if length(invalid_options) > 0 do
            {:error, {:invalid_options_in_rankings, invalid_options}}
          else
            # Check for duplicates
            unique_rankings = Enum.uniq(rankings)
            
            if length(unique_rankings) != length(rankings) do
              {:error, :duplicate_rankings}
            else
              :ok
            end
          end
        end
        
      :condorcet ->
        if not Map.has_key?(ballot, :rankings) do
          {:error, :missing_rankings}
        else
          rankings = ballot.rankings
          
          # Check if all entries are valid options
          invalid_options = Enum.filter(rankings, &(&1 not in options))
          
          if length(invalid_options) > 0 do
            {:error, {:invalid_options_in_rankings, invalid_options}}
          else
            # Check for duplicates
            unique_rankings = Enum.uniq(rankings)
            
            if length(unique_rankings) != length(rankings) do
              {:error, :duplicate_rankings}
            else
              :ok
            end
          end
        end
        
      :cumulative ->
        if not Map.has_key?(ballot, :allocations) do
          {:error, :missing_allocations}
        else
          allocations = ballot.allocations
          
          # Check if all keys are valid options
          invalid_options = Enum.filter(Map.keys(allocations), &(&1 not in options))
          
          if length(invalid_options) > 0 do
            {:error, {:invalid_options_in_allocations, invalid_options}}
          else
            # Check if total points don't exceed limit
            points_per_voter = Map.get(
              ballot.config.custom_parameters, 
              :points_per_voter, 
              length(options)
            )
            
            total_points = Enum.sum(Map.values(allocations))
            
            if total_points > points_per_voter do
              {:error, {:points_exceed_limit, total_points, points_per_voter}}
            else
              # Check for negative allocations
              negative_allocations = Enum.filter(allocations, fn {_, points} -> points < 0 end)
              
              if length(negative_allocations) > 0 do
                {:error, {:negative_allocations, negative_allocations}}
              else
                :ok
              end
            end
          end
        end
    end
  end
  
  defp should_advance_to_deliberation?(process_data) do
    # Check if we have enough participants
    has_min_participants = 
      map_size(process_data.participants) >= process_data.config.min_participants
      
    # Check if we have enough votes
    has_quorum?(process_data) && has_min_participants
  end
  
  defp has_quorum?(process_data) do
    participant_count = map_size(process_data.participants)
    vote_count = length(process_data.metadata.votes)
    
    if participant_count == 0 do
      false
    else
      # Calculate the actual quorum requirement
      required_quorum = process_data.config.quorum || 0.5
      
      vote_ratio = vote_count / participant_count
      vote_ratio >= required_quorum
    end
  end
  
  defp apply_voting_system(voting_system, process_data) do
    case voting_system do
      :plurality ->
        apply_plurality_voting(process_data)
        
      :ranked_choice ->
        apply_ranked_choice_voting(process_data)
        
      :approval ->
        apply_approval_voting(process_data)
        
      :borda_count ->
        apply_borda_count_voting(process_data)
        
      :condorcet ->
        apply_condorcet_voting(process_data)
        
      :cumulative ->
        apply_cumulative_voting(process_data)
    end
  end
  
  defp apply_plurality_voting(process_data) do
    # Count votes for each option
    votes = process_data.metadata.votes
    options = process_data.metadata.options
    
    # Initialize tallies
    initial_tallies = Enum.map(options, fn option -> {option, 0} end) |> Map.new()
    
    # Count votes
    tallies = 
      Enum.reduce(votes, initial_tallies, fn vote, acc ->
        selection = vote.ballot.selection
        weight = vote.weight
        
        Map.update!(acc, selection, &(&1 + weight))
      end)
    
    # Find winner
    {winner, max_votes} = 
      Enum.max_by(tallies, fn {_option, count} -> count end, fn -> {nil, 0} end)
    
    # Check for ties
    tied_options =
      Enum.filter(tallies, fn {_option, count} -> count == max_votes end)
      |> Enum.map(fn {option, _} -> option end)
    
    has_tie = length(tied_options) > 1
    
    # Create result
    result = %{
      voting_system: :plurality,
      winner: if(has_tie, do: :tie, else: winner),
      tied_options: if(has_tie, do: tied_options, else: []),
      tallies: tallies,
      total_votes: Enum.sum(Map.values(tallies)),
      participation_rate: length(votes) / map_size(process_data.participants)
    }
    
    # Update metadata
    updated_metadata = %{
      process_data.metadata |
      tallies: tallies
    }
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_ranked_choice_voting(process_data) do
    # Implement Instant Runoff Voting (IRV)
    votes = process_data.metadata.votes
    options = process_data.metadata.options
    num_winners = 
      Map.get(process_data.config.custom_parameters, :num_winners, 1)
    
    # Convert votes to IRV format
    irv_ballots = 
      Enum.map(votes, fn vote -> 
        %{
          rankings: vote.ballot.rankings,
          weight: vote.weight
        }
      end)
    
    # Run IRV algorithm
    {winners, rounds} = run_irv(irv_ballots, options, num_winners)
    
    # Create result
    result = %{
      voting_system: :ranked_choice,
      winners: winners,
      rounds: rounds,
      total_votes: length(votes),
      participation_rate: length(votes) / map_size(process_data.participants)
    }
    
    # Update metadata
    updated_metadata = %{
      process_data.metadata |
      tallies: %{rounds: rounds, winners: winners}
    }
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_approval_voting(process_data) do
    # Count approvals for each option
    votes = process_data.metadata.votes
    options = process_data.metadata.options
    
    # Initialize tallies
    initial_tallies = Enum.map(options, fn option -> {option, 0} end) |> Map.new()
    
    # Count votes
    tallies = 
      Enum.reduce(votes, initial_tallies, fn vote, acc ->
        approvals = vote.ballot.approvals
        weight = vote.weight
        
        Enum.reduce(approvals, acc, fn option, inner_acc ->
          Map.update!(inner_acc, option, &(&1 + weight))
        end)
      end)
    
    # Find winner(s)
    {max_option, max_approvals} = 
      Enum.max_by(tallies, fn {_option, count} -> count end, fn -> {nil, 0} end)
    
    # Check for ties
    tied_options =
      Enum.filter(tallies, fn {_option, count} -> count == max_approvals end)
      |> Enum.map(fn {option, _} -> option end)
    
    has_tie = length(tied_options) > 1
    
    # Create result
    result = %{
      voting_system: :approval,
      winner: if(has_tie, do: :tie, else: max_option),
      tied_options: if(has_tie, do: tied_options, else: []),
      tallies: tallies,
      total_votes: length(votes),
      participation_rate: length(votes) / map_size(process_data.participants)
    }
    
    # Update metadata
    updated_metadata = %{
      process_data.metadata |
      tallies: tallies
    }
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_borda_count_voting(process_data) do
    # Implement Borda count
    votes = process_data.metadata.votes
    options = process_data.metadata.options
    
    # Initialize tallies
    initial_tallies = Enum.map(options, fn option -> {option, 0} end) |> Map.new()
    
    # Count votes
    tallies = 
      Enum.reduce(votes, initial_tallies, fn vote, acc ->
        rankings = vote.ballot.rankings
        weight = vote.weight
        
        # Calculate points - Borda count gives points based on ranking
        # e.g., for 5 options, 1st gets 4 points, 2nd gets 3, etc.
        max_points = length(options) - 1
        
        Enum.reduce(Enum.with_index(rankings), acc, fn {option, index}, inner_acc ->
          points = (max_points - index) * weight
          Map.update!(inner_acc, option, &(&1 + points))
        end)
      end)
    
    # Find winner
    {winner, max_points} = 
      Enum.max_by(tallies, fn {_option, count} -> count end, fn -> {nil, 0} end)
    
    # Check for ties
    tied_options =
      Enum.filter(tallies, fn {_option, count} -> count == max_points end)
      |> Enum.map(fn {option, _} -> option end)
    
    has_tie = length(tied_options) > 1
    
    # Create result
    result = %{
      voting_system: :borda_count,
      winner: if(has_tie, do: :tie, else: winner),
      tied_options: if(has_tie, do: tied_options, else: []),
      tallies: tallies,
      total_votes: length(votes),
      participation_rate: length(votes) / map_size(process_data.participants)
    }
    
    # Update metadata
    updated_metadata = %{
      process_data.metadata |
      tallies: tallies
    }
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_condorcet_voting(process_data) do
    # Implement Condorcet method
    votes = process_data.metadata.votes
    options = process_data.metadata.options
    
    # Build pairwise preference matrix
    preference_matrix = build_preference_matrix(votes, options)
    
    # Find Condorcet winner, if any
    {winner, is_condorcet_winner} = find_condorcet_winner(preference_matrix, options)
    
    # Create result
    result = %{
      voting_system: :condorcet,
      has_condorcet_winner: is_condorcet_winner,
      winner: if(is_condorcet_winner, do: winner, else: :no_condorcet_winner),
      preference_matrix: preference_matrix,
      total_votes: length(votes),
      participation_rate: length(votes) / map_size(process_data.participants)
    }
    
    # If no Condorcet winner, we could add Smith set or other fallback
    result = 
      if not is_condorcet_winner do
        smith_set = find_smith_set(preference_matrix, options)
        Map.put(result, :smith_set, smith_set)
      else
        result
      end
    
    # Update metadata
    updated_metadata = %{
      process_data.metadata |
      tallies: %{
        preference_matrix: preference_matrix,
        condorcet_winner: if(is_condorcet_winner, do: winner, else: nil)
      }
    }
    
    {:ok, result, updated_metadata}
  end
  
  defp apply_cumulative_voting(process_data) do
    # Implement cumulative voting
    votes = process_data.metadata.votes
    options = process_data.metadata.options
    
    # Initialize tallies
    initial_tallies = Enum.map(options, fn option -> {option, 0} end) |> Map.new()
    
    # Count votes
    tallies = 
      Enum.reduce(votes, initial_tallies, fn vote, acc ->
        allocations = vote.ballot.allocations
        weight = vote.weight
        
        Enum.reduce(allocations, acc, fn {option, points}, inner_acc ->
          Map.update!(inner_acc, option, &(&1 + points * weight))
        end)
      end)
    
    # Find winner
    {winner, max_points} = 
      Enum.max_by(tallies, fn {_option, count} -> count end, fn -> {nil, 0} end)
    
    # Check for ties
    tied_options =
      Enum.filter(tallies, fn {_option, count} -> count == max_points end)
      |> Enum.map(fn {option, _} -> option end)
    
    has_tie = length(tied_options) > 1
    
    # Create result
    result = %{
      voting_system: :cumulative,
      winner: if(has_tie, do: :tie, else: winner),
      tied_options: if(has_tie, do: tied_options, else: []),
      tallies: tallies,
      total_votes: length(votes),
      participation_rate: length(votes) / map_size(process_data.participants)
    }
    
    # Update metadata
    updated_metadata = %{
      process_data.metadata |
      tallies: tallies
    }
    
    {:ok, result, updated_metadata}
  end
  
  # Helper functions for voting algorithms
  
  defp run_irv(ballots, options, num_winners) do
    run_irv_rounds(ballots, options, [], [], 1, num_winners)
  end
  
  defp run_irv_rounds(ballots, remaining_options, winners, rounds, round_num, num_winners) 
       when length(winners) >= num_winners or length(remaining_options) <= 1 do
    # End condition: either we have enough winners or only one option remains
    final_winners = 
      if length(winners) < num_winners and length(remaining_options) == 1 do
        winners ++ remaining_options
      else
        winners
      end
      
    {final_winners, rounds}
  end
  
  defp run_irv_rounds(ballots, remaining_options, winners, rounds, round_num, num_winners) do
    # Count first choices in current ballots
    first_choices = 
      Enum.reduce(ballots, %{}, fn ballot, acc ->
        # Find first remaining choice in this ballot
        first_choice = 
          Enum.find(ballot.rankings, fn option -> 
            option in remaining_options
          end)
        
        if first_choice do
          weight = ballot.weight
          Map.update(acc, first_choice, weight, &(&1 + weight))
        else
          # No remaining choices on this ballot
          acc
        end
      end)
    
    # Add zero counts for options not selected
    tallies = 
      Enum.reduce(remaining_options, first_choices, fn option, acc ->
        if Map.has_key?(acc, option) do
          acc
        else
          Map.put(acc, option, 0)
        end
      end)
    
    total_votes = Enum.sum(Map.values(tallies))
    
    # Check for majority winner
    majority_threshold = total_votes / 2
    
    {max_option, max_votes} = 
      Enum.max_by(tallies, fn {_option, count} -> count end, fn -> {nil, 0} end)
    
    current_round = %{
      round: round_num,
      tallies: tallies,
      total_votes: total_votes
    }
    
    if max_votes > majority_threshold do
      # We have a winner for this round
      new_winners = winners ++ [max_option]
      new_remaining = Enum.filter(remaining_options, &(&1 != max_option))
      
      # Add winner info to round
      updated_round = Map.put(current_round, :winner, max_option)
      new_rounds = rounds ++ [updated_round]
      
      # Continue with next rounds if needed
      run_irv_rounds(ballots, new_remaining, new_winners, new_rounds, round_num + 1, num_winners)
    else
      # No majority winner, eliminate lowest option
      {min_option, _min_votes} = 
        Enum.min_by(tallies, fn {_option, count} -> count end, fn -> {nil, 0} end)
      
      # In case of tie for elimination, we'd need a tiebreaker, but for simplicity just take first
      eliminated_options = 
        tallies
        |> Enum.filter(fn {_option, count} -> count == tallies[min_option] end)
        |> Enum.map(fn {option, _} -> option end)
        |> Enum.take(1)  # Just take one for elimination
      
      eliminated_option = hd(eliminated_options)
      
      # Add elimination info to round
      updated_round = Map.put(current_round, :eliminated, eliminated_option)
      new_rounds = rounds ++ [updated_round]
      
      # Remove eliminated option and continue
      new_remaining = Enum.filter(remaining_options, &(&1 != eliminated_option))
      
      run_irv_rounds(ballots, new_remaining, winners, new_rounds, round_num + 1, num_winners)
    end
  end
  
  defp build_preference_matrix(votes, options) do
    # Initialize empty matrix
    empty_matrix = 
      for a <- options, b <- options, a != b, into: %{} do
        {{a, b}, 0}
      end
    
    # Fill matrix with pairwise preferences
    Enum.reduce(votes, empty_matrix, fn vote, matrix ->
      rankings = vote.ballot.rankings
      weight = vote.weight
      
      # Update matrix for each pair of options
      Enum.reduce(options, matrix, fn a, outer_acc ->
        Enum.reduce(options, outer_acc, fn b, inner_acc ->
          if a != b do
            # Check if a is preferred to b in this ballot
            a_index = Enum.find_index(rankings, &(&1 == a))
            b_index = Enum.find_index(rankings, &(&1 == b))
            
            # a is preferred to b if it appears earlier in the ranking
            # (lower index) or if b isn't ranked at all
            a_preferred = 
              (a_index != nil and b_index == nil) or
              (a_index != nil and b_index != nil and a_index < b_index)
            
            if a_preferred do
              Map.update!(inner_acc, {a, b}, &(&1 + weight))
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
  
  defp find_condorcet_winner(preference_matrix, options) do
    # A Condorcet winner beats all other options in pairwise comparisons
    Enum.find_value(options, {nil, false}, fn option ->
      others = Enum.filter(options, &(&1 != option))
      
      beats_all = Enum.all?(others, fn other ->
        preference_matrix[{option, other}] > preference_matrix[{other, option}]
      end)
      
      if beats_all, do: {option, true}, else: nil
    end)
  end
  
  defp find_smith_set(preference_matrix, options) do
    # Build a directed graph where an edge from a to b means a beats b
    beats_graph = 
      for a <- options, b <- options, a != b do
        a_beats_b = preference_matrix[{a, b}] > preference_matrix[{b, a}]
        {a, b, a_beats_b}
      end
      |> Enum.filter(fn {_, _, beats} -> beats end)
      |> Enum.map(fn {a, b, _} -> {a, b} end)
      |> Enum.group_by(fn {a, _} -> a end, fn {_, b} -> b end)
    
    # Identify minimal unbeaten set
    unbeaten_set = 
      Enum.filter(options, fn option ->
        # An option is in the Smith set if there's no option outside the set
        # that beats it
        not Enum.any?(options, fn other ->
          other != option and
          Enum.member?(Map.get(beats_graph, other, []), option) and
          not Enum.member?(Map.get(beats_graph, option, []), other)
        end)
      end)
    
    unbeaten_set
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