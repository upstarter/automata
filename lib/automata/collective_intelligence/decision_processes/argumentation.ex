defmodule Automata.CollectiveIntelligence.DecisionProcesses.Argumentation do
  @moduledoc """
  Implements argumentation frameworks for structured debate and reasoning.
  
  This module provides mechanisms for formal argumentation including argument
  representation, attack and support relations, argument evaluation, and
  framework analysis. It supports various semantics for determining acceptable
  arguments within a debate.
  """
  
  alias Automata.CollectiveIntelligence.DecisionProcesses.DecisionProcess
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @behaviour DecisionProcess
  
  @argumentation_semantics [
    :grounded,
    :preferred,
    :stable,
    :complete,
    :semi_stable
  ]
  
  @type argument_id :: String.t()
  @type argument :: %{
    id: argument_id(),
    claim: String.t(),
    premises: [String.t()],
    supporter: String.t(),
    timestamp: DateTime.t()
  }
  
  @type attack :: %{
    source: argument_id(),
    target: argument_id(),
    type: :rebut | :undercut | :undermine,
    explanation: String.t(),
    timestamp: DateTime.t()
  }
  
  @type support :: %{
    source: argument_id(),
    target: argument_id(),
    explanation: String.t(),
    timestamp: DateTime.t()
  }
  
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
          arguments: %{},
          attacks: [],
          supports: [],
          argument_counter: 0,
          semantics: Map.get(config.custom_parameters, :semantics, :grounded),
          rounds: [],
          current_round: 1,
          max_rounds: Map.get(config.custom_parameters, :max_rounds, 3)
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
          # For argumentation, we might assign roles to participants
          role = Map.get(params, :role, :standard)
          
          updated_participants = Map.put(process_data.participants, participant_id, %{
            registered_at: DateTime.utc_now(),
            params: params,
            role: role,
            arguments_submitted: 0,
            attacks_submitted: 0,
            supports_submitted: 0
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
        # Process the argumentation input
        # This could be a new argument, attack, or support
        process_argumentation_input(process_data, participant_id, input)
    end
  end
  
  @impl DecisionProcess
  def compute_result(process_data) do
    if process_data.state != :deliberating do
      {:error, :not_deliberating}
    else
      # Apply the specific argumentation semantics
      semantics = Map.get(process_data.metadata, :semantics, :grounded)
      
      case evaluate_argumentation_framework(process_data, semantics) do
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
    # 2. It has enough arguments and has gone through all rounds
    
    process_data.state == :decided ||
      (process_data.state == :deliberating && 
       map_size(process_data.metadata.arguments) > 0 &&
       process_data.metadata.current_round > process_data.metadata.max_rounds)
  end
  
  @impl DecisionProcess
  def close(process_data) do
    case process_data.state do
      :decided ->
        # Already decided, just mark as closed
        {:ok, %{process_data | state: :closed, ended_at: DateTime.utc_now()}}
        
      :deliberating when map_size(process_data.metadata.arguments) > 0 ->
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
      # Validate custom parameters for argumentation
      custom_params = config.custom_parameters || %{}
      
      semantics = Map.get(custom_params, :semantics, :grounded)
      
      if semantics not in @argumentation_semantics do
        {:error, {:invalid_semantics, semantics, @argumentation_semantics}}
      else
        :ok
      end
    end
  end
  
  defp process_argumentation_input(process_data, participant_id, input) do
    # Determine the type of input: argument, attack, or support
    cond do
      Map.has_key?(input, :argument) ->
        add_argument(process_data, participant_id, input.argument)
        
      Map.has_key?(input, :attack) ->
        add_attack(process_data, participant_id, input.attack)
        
      Map.has_key?(input, :support) ->
        add_support(process_data, participant_id, input.support)
        
      true ->
        {:error, :invalid_input_format}
    end
  end
  
  defp add_argument(process_data, participant_id, argument_data) do
    # Validate the argument structure
    with :ok <- validate_argument(argument_data) do
      # Generate a unique argument ID
      arg_counter = process_data.metadata.argument_counter
      argument_id = "arg_#{process_data.id}_#{arg_counter + 1}"
      
      # Create the argument
      argument = %{
        id: argument_id,
        claim: argument_data.claim,
        premises: argument_data.premises || [],
        supporter: participant_id,
        timestamp: DateTime.utc_now()
      }
      
      # Update the process data
      updated_metadata = %{
        process_data.metadata |
        arguments: Map.put(process_data.metadata.arguments, argument_id, argument),
        argument_counter: arg_counter + 1
      }
      
      # Update participant stats
      updated_participants = Map.update!(process_data.participants, participant_id, fn p ->
        %{p | arguments_submitted: p.arguments_submitted + 1}
      end)
      
      # Store in inputs for standard interface
      updated_inputs = Map.put(process_data.inputs, "#{participant_id}_arg_#{arg_counter + 1}", %{
        type: :argument,
        data: argument
      })
      
      updated_data = %{
        process_data |
        inputs: updated_inputs,
        participants: updated_participants,
        metadata: updated_metadata,
        updated_at: DateTime.utc_now()
      }
      
      # Check if we have enough arguments to advance to deliberation
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
  
  defp add_attack(process_data, participant_id, attack_data) do
    # Validate the attack
    with :ok <- validate_attack(attack_data, process_data.metadata.arguments) do
      # Create the attack
      attack = %{
        source: attack_data.source,
        target: attack_data.target,
        type: attack_data.type,
        explanation: attack_data.explanation,
        attacker: participant_id,
        timestamp: DateTime.utc_now()
      }
      
      # Update the process data
      updated_metadata = %{
        process_data.metadata |
        attacks: [attack | process_data.metadata.attacks]
      }
      
      # Update participant stats
      updated_participants = Map.update!(process_data.participants, participant_id, fn p ->
        %{p | attacks_submitted: p.attacks_submitted + 1}
      end)
      
      # Store in inputs for standard interface
      input_key = "#{participant_id}_attack_#{length(process_data.metadata.attacks) + 1}"
      updated_inputs = Map.put(process_data.inputs, input_key, %{
        type: :attack,
        data: attack
      })
      
      updated_data = %{
        process_data |
        inputs: updated_inputs,
        participants: updated_participants,
        metadata: updated_metadata,
        updated_at: DateTime.utc_now()
      }
      
      # Check if we have enough arguments/attacks to advance to deliberation
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
  
  defp add_support(process_data, participant_id, support_data) do
    # Validate the support
    with :ok <- validate_support(support_data, process_data.metadata.arguments) do
      # Create the support
      support = %{
        source: support_data.source,
        target: support_data.target,
        explanation: support_data.explanation,
        supporter: participant_id,
        timestamp: DateTime.utc_now()
      }
      
      # Update the process data
      updated_metadata = %{
        process_data.metadata |
        supports: [support | process_data.metadata.supports]
      }
      
      # Update participant stats
      updated_participants = Map.update!(process_data.participants, participant_id, fn p ->
        %{p | supports_submitted: p.supports_submitted + 1}
      end)
      
      # Store in inputs for standard interface
      input_key = "#{participant_id}_support_#{length(process_data.metadata.supports) + 1}"
      updated_inputs = Map.put(process_data.inputs, input_key, %{
        type: :support,
        data: support
      })
      
      updated_data = %{
        process_data |
        inputs: updated_inputs,
        participants: updated_participants,
        metadata: updated_metadata,
        updated_at: DateTime.utc_now()
      }
      
      # Check if we have enough arguments/supports to advance to deliberation
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
  
  defp validate_argument(argument) do
    # Basic validation for arguments
    cond do
      not Map.has_key?(argument, :claim) ->
        {:error, :missing_claim}
        
      String.length(argument.claim) < 3 ->
        {:error, :claim_too_short}
        
      true ->
        :ok
    end
  end
  
  defp validate_attack(attack, arguments) do
    # Basic validation for attacks
    cond do
      not Map.has_key?(attack, :source) ->
        {:error, :missing_source}
        
      not Map.has_key?(attack, :target) ->
        {:error, :missing_target}
        
      not Map.has_key?(attack, :type) ->
        {:error, :missing_attack_type}
        
      attack.type not in [:rebut, :undercut, :undermine] ->
        {:error, {:invalid_attack_type, attack.type}}
        
      not Map.has_key?(arguments, attack.source) ->
        {:error, {:unknown_source_argument, attack.source}}
        
      not Map.has_key?(arguments, attack.target) ->
        {:error, {:unknown_target_argument, attack.target}}
        
      attack.source == attack.target ->
        {:error, :self_attack_not_allowed}
        
      true ->
        :ok
    end
  end
  
  defp validate_support(support, arguments) do
    # Basic validation for supports
    cond do
      not Map.has_key?(support, :source) ->
        {:error, :missing_source}
        
      not Map.has_key?(support, :target) ->
        {:error, :missing_target}
        
      not Map.has_key?(arguments, support.source) ->
        {:error, {:unknown_source_argument, support.source}}
        
      not Map.has_key?(arguments, support.target) ->
        {:error, {:unknown_target_argument, support.target}}
        
      support.source == support.target ->
        {:error, :self_support_not_allowed}
        
      true ->
        :ok
    end
  end
  
  defp should_advance_to_deliberation?(process_data) do
    # Check if we have enough participants
    has_min_participants =
      map_size(process_data.participants) >= process_data.config.min_participants
    
    # Check if we have enough arguments
    has_min_arguments = map_size(process_data.metadata.arguments) >= 2
    
    # Check if we have enough attacks/supports
    has_min_relations = 
      length(process_data.metadata.attacks) + length(process_data.metadata.supports) >= 1
    
    has_min_participants && has_min_arguments && has_min_relations
  end
  
  defp evaluate_argumentation_framework(process_data, semantics) do
    current_round = process_data.metadata.current_round
    max_rounds = process_data.metadata.max_rounds
    
    if current_round > max_rounds do
      # Final evaluation
      case semantics do
        :grounded ->
          evaluate_grounded_semantics(process_data)
          
        :preferred ->
          evaluate_preferred_semantics(process_data)
          
        :stable ->
          evaluate_stable_semantics(process_data)
          
        :complete ->
          evaluate_complete_semantics(process_data)
          
        :semi_stable ->
          evaluate_semi_stable_semantics(process_data)
      end
    else
      # Update round counter for next iteration
      updated_metadata = %{
        process_data.metadata |
        current_round: current_round + 1
      }
      
      # Continue to next round
      {:continue, updated_metadata}
    end
  end
  
  defp evaluate_grounded_semantics(process_data) do
    # Implement grounded semantics
    # - Computes the minimal complete extension
    # - Unique and well-defined
    # - Corresponds to the most skeptical position
    arguments = process_data.metadata.arguments
    attacks = process_data.metadata.attacks
    
    # Build the attack graph
    attack_graph = build_attack_graph(arguments, attacks)
    
    # Compute the grounded extension
    grounded_extension = compute_grounded_extension(attack_graph, Map.keys(arguments))
    
    # Create result
    result = %{
      semantics: :grounded,
      grounded_extension: grounded_extension,
      accepted_arguments: Enum.map(grounded_extension, &arguments[&1]),
      attack_graph: attack_graph
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :evaluation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  defp evaluate_preferred_semantics(process_data) do
    # Implement preferred semantics
    # - Maximal admissible sets of arguments
    # - Multiple preferred extensions possible
    # - More credulous than grounded
    arguments = process_data.metadata.arguments
    attacks = process_data.metadata.attacks
    
    # Build the attack graph
    attack_graph = build_attack_graph(arguments, attacks)
    
    # Compute all preferred extensions
    preferred_extensions = compute_preferred_extensions(attack_graph, Map.keys(arguments))
    
    # Create result
    result = %{
      semantics: :preferred,
      preferred_extensions: preferred_extensions,
      accepted_arguments: Enum.map(preferred_extensions, fn ext ->
        Enum.map(ext, &arguments[&1])
      end),
      attack_graph: attack_graph
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :evaluation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  defp evaluate_stable_semantics(process_data) do
    # Implement stable semantics
    # - Complete extensions that attack all arguments not in the extension
    arguments = process_data.metadata.arguments
    attacks = process_data.metadata.attacks
    
    # Build the attack graph
    attack_graph = build_attack_graph(arguments, attacks)
    
    # Compute stable extensions
    stable_extensions = compute_stable_extensions(attack_graph, Map.keys(arguments))
    
    # Create result
    result = %{
      semantics: :stable,
      stable_extensions: stable_extensions,
      has_stable_extension: length(stable_extensions) > 0,
      accepted_arguments: Enum.map(stable_extensions, fn ext ->
        Enum.map(ext, &arguments[&1])
      end),
      attack_graph: attack_graph
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :evaluation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  defp evaluate_complete_semantics(process_data) do
    # Implement complete semantics
    # - Sets of arguments that defend themselves
    arguments = process_data.metadata.arguments
    attacks = process_data.metadata.attacks
    
    # Build the attack graph
    attack_graph = build_attack_graph(arguments, attacks)
    
    # Compute complete extensions
    complete_extensions = compute_complete_extensions(attack_graph, Map.keys(arguments))
    
    # Create result
    result = %{
      semantics: :complete,
      complete_extensions: complete_extensions,
      accepted_arguments: Enum.map(complete_extensions, fn ext ->
        Enum.map(ext, &arguments[&1])
      end),
      attack_graph: attack_graph
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :evaluation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  defp evaluate_semi_stable_semantics(process_data) do
    # Implement semi-stable semantics
    # - Complete extensions where the union of the extension and
    #   its range is maximal
    arguments = process_data.metadata.arguments
    attacks = process_data.metadata.attacks
    
    # Build the attack graph
    attack_graph = build_attack_graph(arguments, attacks)
    
    # Compute semi-stable extensions
    semi_stable_extensions = compute_semi_stable_extensions(attack_graph, Map.keys(arguments))
    
    # Create result
    result = %{
      semantics: :semi_stable,
      semi_stable_extensions: semi_stable_extensions,
      accepted_arguments: Enum.map(semi_stable_extensions, fn ext ->
        Enum.map(ext, &arguments[&1])
      end),
      attack_graph: attack_graph
    }
    
    # Update metadata
    updated_metadata = Map.put(process_data.metadata, :evaluation_result, result)
    
    {:ok, result, updated_metadata}
  end
  
  # Helper functions for argumentation framework evaluation
  
  defp build_attack_graph(arguments, attacks) do
    # Initialize graph with all arguments
    initial_graph = Map.new(Map.keys(arguments), fn arg_id -> {arg_id, []} end)
    
    # Add attack relations
    Enum.reduce(attacks, initial_graph, fn attack, graph ->
      Map.update!(graph, attack.target, fn targets -> [attack.source | targets] end)
    end)
  end
  
  defp compute_grounded_extension(attack_graph, all_args) do
    # Grounded semantics computes the least fixed point
    # Start with unattacked arguments
    unattacked = 
      Enum.filter(all_args, fn arg ->
        Enum.empty?(Map.get(attack_graph, arg, []))
      end)
    
    # Iteratively add arguments defended by current extension
    compute_grounded_extension_iter(attack_graph, unattacked, all_args, [])
  end
  
  defp compute_grounded_extension_iter(attack_graph, extension, all_args, prev_extension) do
    if extension == prev_extension do
      # Fixed point reached
      extension
    else
      # Find arguments defended by current extension
      defended = 
        Enum.filter(all_args -- extension, fn arg ->
          attackers = Map.get(attack_graph, arg, [])
          # All attackers are attacked by extension
          Enum.all?(attackers, fn attacker ->
            Enum.any?(extension, fn ext_arg ->
              Enum.member?(Map.get(attack_graph, attacker, []), ext_arg)
            end)
          end)
        end)
      
      # Add defended arguments to extension
      new_extension = extension ++ defended
      
      # Continue iteration
      compute_grounded_extension_iter(attack_graph, new_extension, all_args, extension)
    end
  end
  
  defp compute_preferred_extensions(attack_graph, all_args) do
    # Find all maximal admissible sets
    # Start with the empty set
    initial_candidates = [MapSet.new()]
    
    # For each argument, try adding it to existing admissible sets
    # then check if resulting sets are still admissible
    # Finally, keep only maximal sets
    candidates = 
      Enum.reduce(all_args, initial_candidates, fn arg, acc_candidates ->
        new_candidates = 
          Enum.flat_map(acc_candidates, fn candidate ->
            # Try adding this argument
            new_candidate = MapSet.put(candidate, arg)
            
            if is_admissible?(new_candidate, attack_graph) do
              [new_candidate]
            else
              [candidate]
            end
          end)
          |> Enum.uniq()
        
        # Add any new candidates
        (acc_candidates ++ new_candidates)
        |> Enum.uniq()
      end)
    
    # Keep only maximal sets
    maximal_sets(candidates)
    |> Enum.map(&MapSet.to_list/1)
  end
  
  defp is_admissible?(extension, attack_graph) do
    # Check if extension is conflict-free
    if not is_conflict_free?(extension, attack_graph) do
      false
    else
      # Check if extension defends all its arguments
      Enum.all?(extension, fn arg ->
        attackers = Map.get(attack_graph, arg, [])
        
        # All attackers must be counter-attacked by the extension
        Enum.all?(attackers, fn attacker ->
          Enum.any?(extension, fn defender ->
            Enum.member?(Map.get(attack_graph, attacker, []), defender)
          end)
        end)
      end)
    end
  end
  
  defp is_conflict_free?(extension, attack_graph) do
    # No argument in the extension attacks another argument in the extension
    Enum.all?(extension, fn arg ->
      attackers = Map.get(attack_graph, arg, [])
      Enum.all?(extension, fn other_arg -> other_arg not in attackers end)
    end)
  end
  
  defp compute_stable_extensions(attack_graph, all_args) do
    # Stable extensions are conflict-free sets that attack all arguments outside the set
    # Start by computing all preferred extensions
    preferred = compute_preferred_extensions(attack_graph, all_args)
    
    # Filter for those that are stable
    Enum.filter(preferred, fn ext ->
      # Check if all arguments outside the extension are attacked by the extension
      outside_args = all_args -- ext
      
      Enum.all?(outside_args, fn arg ->
        # Is this outside argument attacked by any argument in the extension?
        Enum.any?(ext, fn ext_arg ->
          Enum.member?(Map.get(attack_graph, arg, []), ext_arg)
        end)
      end)
    end)
  end
  
  defp compute_complete_extensions(attack_graph, all_args) do
    # Complete extensions are admissible sets that contain all arguments they defend
    # Compute all admissible sets first
    admissible_sets = compute_all_admissible_sets(attack_graph, all_args)
    
    # Filter for those that are complete
    Enum.filter(admissible_sets, fn ext ->
      # Get all arguments defended by this extension
      defended = 
        Enum.filter(all_args, fn arg ->
          attackers = Map.get(attack_graph, arg, [])
          
          # All attackers are attacked by extension
          Enum.all?(attackers, fn attacker ->
            Enum.any?(ext, fn ext_arg ->
              Enum.member?(Map.get(attack_graph, attacker, []), ext_arg)
            end)
          end)
        end)
      
      # Check if extension contains all arguments it defends
      Enum.all?(defended, fn arg -> arg in ext end)
    end)
  end
  
  defp compute_all_admissible_sets(attack_graph, all_args) do
    # Generate all possible subsets of arguments
    # This is inefficient but simple for demonstration
    1..length(all_args)
    |> Enum.flat_map(fn i -> Combination.combine(all_args, i) end)
    
    # Filter for admissible sets
    |> Enum.filter(fn set -> is_admissible?(MapSet.new(set), attack_graph) end)
    |> Enum.map(&Enum.to_list/1)
  end
  
  defp compute_semi_stable_extensions(attack_graph, all_args) do
    # Semi-stable extensions are complete extensions with maximal range
    # First compute all complete extensions
    complete_extensions = compute_complete_extensions(attack_graph, all_args)
    
    # Calculate the range for each complete extension
    extensions_with_range = 
      Enum.map(complete_extensions, fn ext ->
        range = compute_range(ext, attack_graph, all_args)
        {ext, range}
      end)
    
    # Find extensions with maximal range
    {_, max_range_size} = 
      Enum.max_by(extensions_with_range, fn {_, range} -> 
        length(range)
      end, fn -> {[], 0} end)
    
    # Return all extensions with maximal range
    Enum.filter(extensions_with_range, fn {_, range} -> 
      length(range) == max_range_size
    end)
    |> Enum.map(fn {ext, _} -> ext end)
  end
  
  defp compute_range(extension, attack_graph, all_args) do
    # Range = extension + all arguments attacked by extension
    attacked_args = 
      Enum.filter(all_args -- extension, fn arg ->
        Enum.any?(extension, fn ext_arg ->
          Enum.member?(Map.get(attack_graph, arg, []), ext_arg)
        end)
      end)
    
    extension ++ attacked_args
  end
  
  defp maximal_sets(sets) do
    # Remove any set that is a subset of another
    Enum.filter(sets, fn set1 ->
      not Enum.any?(sets, fn set2 ->
        set1 != set2 and MapSet.subset?(set1, set2)
      end)
    end)
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

# Utility module for generating combinations
defmodule Combination do
  @moduledoc false
  
  def combine(_, 0), do: [[]]
  def combine([], _), do: []
  def combine([h|t], n) when n > 0 do
    (for l <- combine(t, n-1), do: [h|l]) ++ combine(t, n)
  end
end