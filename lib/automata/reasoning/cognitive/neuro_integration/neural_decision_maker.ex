defmodule Automata.Reasoning.Cognitive.NeuroIntegration.NeuralDecisionMaker do
  @moduledoc """
  Integrates evolved neural networks with the behavior tree decision making system.
  
  This module provides a bridge between the neural networks and behavior trees,
  allowing neural networks to:
  1. Influence behavior tree decisions
  2. Guide action selection
  3. Provide dynamic utility scores
  4. Learn from behavior tree execution results
  
  The decision maker can operate in several modes:
  - Advisory: Networks provide suggestions but BT makes final decisions
  - Hybrid: Some decisions made by networks, others by BT
  - Executive: Networks make primary decisions, BT provides structure
  """
  
  alias Automaton.Types.BT.Composite.Selector
  alias Automaton.Types.BT.ActionSelect
  alias Automata.Reasoning.Cognitive.NeuroIntegration.PerceptionAdapter
  alias Automata.Reasoning.Cognitive.NeuroIntegration.NeuroevolutionManager
  
  require Logger
  
  defstruct [
    :mode,                 # :advisory, :hybrid, or :executive
    :perception_adapter,    # Connection to perception system
    :neuroevolution_manager, # Manager for network evolution
    :network_mappings,      # How neural outputs map to BT decisions
    :decision_history,      # Recent decisions and their outcomes
    :learning_rate,         # Rate for learning from feedback
    :active_network_file    # Currently active neural network
  ]
  
  @doc """
  Creates a new neural decision maker.
  
  ## Parameters
  - mode: Operation mode (:advisory, :hybrid, or :executive)
  - perception_adapter: Adapter to the perception system
  - neuroevolution_manager: Manager for neural network evolution
  - network_mappings: How neural outputs map to BT decisions
  
  ## Returns
  A new NeuralDecisionMaker struct
  """
  def new(mode, perception_adapter, neuroevolution_manager, network_mappings) do
    %__MODULE__{
      mode: mode,
      perception_adapter: perception_adapter,
      neuroevolution_manager: neuroevolution_manager,
      network_mappings: network_mappings,
      decision_history: [],
      learning_rate: 0.1,
      active_network_file: nil
    }
  end
  
  @doc """
  Activates the best available neural network.
  
  ## Parameters
  - decision_maker: The neural decision maker
  
  ## Returns
  Updated decision maker with active network
  """
  def activate_best_network(decision_maker) do
    {best_file, _fitness} = NeuroevolutionManager.get_best_network(
      decision_maker.neuroevolution_manager
    )
    
    if best_file do
      # Load the network into the adapter
      updated_manager = NeuroevolutionManager.load_network_to_adapter(
        decision_maker.neuroevolution_manager,
        best_file
      )
      
      %{decision_maker | 
        neuroevolution_manager: updated_manager,
        active_network_file: best_file
      }
    else
      decision_maker
    end
  end
  
  @doc """
  Makes a decision using the neural network.
  
  ## Parameters
  - decision_maker: The neural decision maker
  - perception_state: Current perception state
  - available_actions: List of available actions or BT nodes
  - context: Additional decision context
  
  ## Returns
  Tuple of {selected_action, updated_decision_maker}
  """
  def make_decision(decision_maker, perception_state, available_actions, context) do
    if decision_maker.active_network_file do
      # Process perceptions through neural network
      {updated_adapter, neural_actions} = PerceptionAdapter.process(
        decision_maker.perception_adapter,
        perception_state
      )
      
      # Update the manager with updated adapter
      updated_manager = %{decision_maker.neuroevolution_manager | 
        perception_adapter: updated_adapter
      }
      
      # Determine decision based on mode
      {selected_action, confidence} = select_action_based_on_mode(
        decision_maker.mode,
        neural_actions,
        available_actions,
        decision_maker.network_mappings,
        context
      )
      
      # Record decision for learning
      decision_record = %{
        action: selected_action,
        confidence: confidence,
        context: context,
        timestamp: DateTime.utc_now()
      }
      
      updated_history = [decision_record | decision_maker.decision_history]
      |> Enum.take(100)  # Keep only recent history
      
      # Return the decision and updated state
      {selected_action, %{decision_maker | 
        perception_adapter: updated_adapter,
        neuroevolution_manager: updated_manager,
        decision_history: updated_history
      }}
    else
      # No active network, use default selection
      default_action = List.first(available_actions)
      {default_action, decision_maker}
    end
  end
  
  @doc """
  Provides feedback about a decision outcome.
  
  ## Parameters
  - decision_maker: The neural decision maker
  - action: The action that was taken
  - outcome: Success/failure or reward value
  - perception_state: Perception state when feedback occurred
  
  ## Returns
  Updated decision maker
  """
  def provide_feedback(decision_maker, action, outcome, perception_state) do
    # Convert outcome to reward value
    reward = case outcome do
      :success -> 1.0
      :failure -> -0.5
      :running -> 0.0
      value when is_number(value) -> value
    end
    
    # Add to training data in neuroevolution manager
    updated_manager = NeuroevolutionManager.add_training_data(
      decision_maker.neuroevolution_manager,
      perception_state,
      reward
    )
    
    # Update decision maker
    %{decision_maker | neuroevolution_manager: updated_manager}
  end
  
  @doc """
  Changes the operation mode of the decision maker.
  
  ## Parameters
  - decision_maker: The neural decision maker
  - new_mode: New operation mode (:advisory, :hybrid, or :executive)
  
  ## Returns
  Updated decision maker with new mode
  """
  def change_mode(decision_maker, new_mode) when new_mode in [:advisory, :hybrid, :executive] do
    %{decision_maker | mode: new_mode}
  end
  
  # Private helper functions
  
  defp select_action_based_on_mode(mode, neural_actions, available_actions, network_mappings, _context) do
    case mode do
      :advisory ->
        # Neural network advises but doesn't decide
        # Find neural suggestions
        suggested_actions = map_neural_actions_to_bt_actions(
          neural_actions, 
          network_mappings, 
          available_actions
        )
        
        if Enum.empty?(suggested_actions) do
          # No suggestions, use first available
          {List.first(available_actions), 0.5}
        else
          # Use highest confidence suggestion
          Enum.max_by(suggested_actions, fn {_, confidence} -> confidence end)
        end
        
      :hybrid ->
        # Neural network decides if confidence is high enough
        suggested_actions = map_neural_actions_to_bt_actions(
          neural_actions, 
          network_mappings, 
          available_actions
        )
        
        # Find highest confidence suggestion
        highest = Enum.max_by(suggested_actions, fn {_, confidence} -> confidence end, fn -> {nil, 0.0} end)
        
        case highest do
          {action, confidence} when confidence >= 0.7 and action != nil ->
            # High confidence neural decision
            {action, confidence}
            
          _ ->
            # Lower confidence, fall back to first available
            {List.first(available_actions), 0.5}
        end
        
      :executive ->
        # Neural network makes the decision
        suggested_actions = map_neural_actions_to_bt_actions(
          neural_actions, 
          network_mappings, 
          available_actions
        )
        
        if Enum.empty?(suggested_actions) do
          # No suggestions, use first available
          {List.first(available_actions), 0.5}
        else
          # Use highest confidence suggestion
          Enum.max_by(suggested_actions, fn {_, confidence} -> confidence end)
        end
    end
  end
  
  defp map_neural_actions_to_bt_actions(neural_actions, network_mappings, available_actions) do
    # Map neural actions to behavior tree actions
    mapped_actions = Enum.flat_map(neural_actions, fn neural_action ->
      case Map.get(network_mappings, neural_action.type) do
        nil ->
          # No mapping for this neural action
          []
          
        bt_action_type ->
          # Find matching available actions
          Enum.filter_map(available_actions, 
            fn action -> action_matches_type?(action, bt_action_type) end,
            fn action -> {action, neural_action.value} end
          )
      end
    end)
    
    # Ensure all suggested actions are actually available
    Enum.filter(mapped_actions, fn {action, _} -> 
      action in available_actions
    end)
  end
  
  defp action_matches_type?(action, type) do
    cond do
      is_atom(action) and action == type ->
        true
        
      is_map(action) and Map.get(action, :type) == type ->
        true
        
      is_tuple(action) and elem(action, 0) == type ->
        true
        
      true ->
        false
    end
  end
end