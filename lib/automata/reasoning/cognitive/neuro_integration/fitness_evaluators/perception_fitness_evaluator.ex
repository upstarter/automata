defmodule Automata.Reasoning.Cognitive.NeuroIntegration.FitnessEvaluators.PerceptionFitnessEvaluator do
  @moduledoc """
  Evaluates fitness of neural networks based on perception system criteria.
  
  This module implements fitness evaluation for neural networks based on how well they:
  1. Recognize patterns in perception data
  2. Focus attention on relevant perceptions
  3. Predict future perceptions
  4. Generate appropriate actions
  
  The fitness calculation uses perception data collected during agent operation.
  """
  
  alias Automaton.Types.TWEANN.ExoSelf
  alias Automata.Reasoning.Cognitive.NeuroIntegration.PerceptionAdapter
  alias Automata.Reasoning.Cognitive.Perceptory.EnhancedPerceptory
  alias Automata.Reasoning.Cognitive.Perceptory.PatternRecognition.PatternMatcher
  
  require Logger
  
  @doc """
  Evaluates the fitness of a neural network using perception data.
  
  ## Parameters
  - network_file: Path to neural network file
  - perception_adapter: Adapter for connecting to the perception system
  - training_data: List of {perception_state, reward} tuples
  
  ## Returns
  Fitness score
  """
  def evaluate(network_file, perception_adapter, training_data) do
    # Load the network
    {:ok, cortex_pid} = load_neural_network(network_file)
    
    try do
      # Process each training example and calculate fitness
      fitness_scores = Enum.map(training_data, fn {perception_state, reward} ->
        evaluate_perception_response(cortex_pid, perception_adapter, perception_state, reward)
      end)
      
      # Combine fitness scores (average)
      case fitness_scores do
        [] -> 0.0
        scores -> Enum.sum(scores) / length(scores)
      end
    after
      # Clean up
      unload_neural_network(cortex_pid)
    end
  end
  
  @doc """
  Evaluates a network genotype directly without loading from file.
  
  ## Parameters
  - genotype: The neural network genotype
  - perception_adapter: Adapter for connecting to the perception system
  - training_data: List of {perception_state, reward} tuples
  
  ## Returns
  Fitness score
  """
  def evaluate_genotype(genotype, perception_adapter, training_data) do
    # Convert genotype to network file
    network_file = "temp_network_#{:rand.uniform(1_000_000)}.gen"
    # Save genotype to file (implementation dependent on genotype format)
    
    try do
      # Evaluate using the file
      evaluate(network_file, perception_adapter, training_data)
    after
      # Clean up
      File.rm(network_file)
    end
  end
  
  # Private helper functions
  
  defp load_neural_network(network_file) do
    # Use ExoSelf to load the neural network
    Task.async(fn -> ExoSelf.map(network_file) end)
    |> Task.await(:infinity)
    
    # ExoSelf.map returns the cortex PID
    {:ok, Process.whereis(:cortex)}
  end
  
  defp unload_neural_network(cortex_pid) do
    # Send terminate signal
    if Process.alive?(cortex_pid) do
      send(cortex_pid, :terminate)
    end
  end
  
  defp evaluate_perception_response(cortex_pid, perception_adapter, perception_state, reward) do
    # Convert perceptions to neural inputs
    neural_inputs = map_perceptions_to_neural_inputs(perception_state, perception_adapter.input_mapping)
    
    # Send inputs to neural network
    neural_outputs = send_to_network(cortex_pid, neural_inputs)
    
    # Map neural outputs to actions
    actions = map_neural_outputs_to_actions(neural_outputs, perception_adapter.output_mapping)
    
    # Calculate fitness components
    pattern_recognition_score = evaluate_pattern_recognition(neural_outputs, perception_state)
    attention_focus_score = evaluate_attention_focus(neural_outputs, perception_state)
    prediction_score = evaluate_prediction(neural_outputs, perception_state)
    action_appropriateness_score = evaluate_actions(actions, reward)
    
    # Combine components with weights
    0.3 * pattern_recognition_score +
    0.2 * attention_focus_score + 
    0.2 * prediction_score + 
    0.3 * action_appropriateness_score
  end
  
  defp map_perceptions_to_neural_inputs(perceptory_state, input_mapping) do
    # Extract active perceptions and their activations
    active_perceptions = EnhancedPerceptory.get_active_perceptions(perceptory_state)
    
    # Initialize input array with zeros
    max_input_index = Enum.max(Map.values(input_mapping))
    inputs = List.duplicate(0.0, max_input_index + 1)
    
    # Fill in values from active perceptions
    Enum.reduce(active_perceptions, inputs, fn percept, acc ->
      case Map.get(input_mapping, percept.type) do
        nil -> 
          # No mapping for this perception type
          acc
          
        index when is_integer(index) ->
          # Single index mapping
          List.replace_at(acc, index, percept.activation)
          
        indices when is_list(indices) ->
          # Multiple indices for different attributes
          Enum.reduce(indices, acc, fn {attr, idx}, acc2 ->
            value = Map.get(percept.attributes, attr, 0.0)
            List.replace_at(acc2, idx, value)
          end)
      end
    end)
  end
  
  defp send_to_network(cortex_pid, inputs) do
    # Send inputs to neural network and wait for response
    send(cortex_pid, {:process_inputs, inputs})
    
    receive do
      {:neural_outputs, outputs} ->
        outputs
    after
      5000 ->
        Logger.error("Timeout waiting for neural network response")
        []
    end
  end
  
  defp map_neural_outputs_to_actions(neural_outputs, output_mapping) do
    # Convert neural outputs to action commands
    Enum.with_index(neural_outputs)
    |> Enum.flat_map(fn {output_value, index} ->
      case Map.get(output_mapping, index) do
        nil -> 
          # No mapping for this output
          []
          
        {action_type, threshold} when output_value >= threshold ->
          # Output exceeds threshold, trigger action
          [%{type: action_type, value: output_value}]
          
        {action_type, threshold, params} when output_value >= threshold ->
          # Output exceeds threshold with additional parameters
          [%{type: action_type, value: output_value, params: params}]
          
        _ ->
          # Output below threshold or invalid mapping
          []
      end
    end)
  end
  
  defp evaluate_pattern_recognition(neural_outputs, perception_state) do
    # Extract known patterns from perception state
    known_patterns = perception_state.pattern_recognition.detected_patterns
    
    # Check how many patterns are correctly identified in neural outputs
    # This is a simplified evaluation - real implementation would have
    # specific output nodes mapped to patterns
    
    # For demonstration, we'll use a simple heuristic
    # Assuming outputs 0-9 correspond to pattern recognition
    pattern_outputs = Enum.slice(neural_outputs, 0..9)
    
    # Calculate activation pattern similarity
    if length(known_patterns) > 0 and length(pattern_outputs) > 0 do
      # Normalize both lists to same length
      normalized_known = normalize_pattern_list(known_patterns, 10)
      
      # Calculate cosine similarity
      similarity = cosine_similarity(normalized_known, pattern_outputs)
      max(0.0, similarity)
    else
      0.5  # Neutral score when no patterns to compare
    end
  end
  
  defp evaluate_attention_focus(neural_outputs, perception_state) do
    # Extract current attention focus from perception state
    current_focus = perception_state.attention_controller.focus_weights
    
    # Check how well neural network focus matches optimal focus
    # Assuming outputs 10-19 correspond to attention signals
    attention_outputs = Enum.slice(neural_outputs, 10..19)
    
    # Convert current focus to comparable format
    focus_values = Map.values(current_focus)
    normalized_focus = normalize_pattern_list(focus_values, 10)
    
    # Calculate similarity
    if length(normalized_focus) > 0 and length(attention_outputs) > 0 do
      similarity = cosine_similarity(normalized_focus, attention_outputs)
      max(0.0, similarity)
    else
      0.5  # Neutral score when no focus data
    end
  end
  
  defp evaluate_prediction(neural_outputs, perception_state) do
    # Evaluate how well the network predicts future perceptions
    # This would require historical data comparing previous predictions
    # with actual outcomes
    
    # For demonstration, we'll use a placeholder implementation
    # Assuming outputs 20-29 are prediction signals
    
    # This would need to be customized based on actual prediction metrics
    0.5  # Neutral score for now
  end
  
  defp evaluate_actions(actions, reward) do
    # Evaluate how appropriate the actions are given the reward
    # Simple case: If reward is positive, actions are good
    
    if reward > 0 and length(actions) > 0 do
      # Positive reward and some actions - good
      min(1.0, reward)
    elseif reward < 0 and length(actions) > 0 do
      # Negative reward but actions - bad
      0.0
    elseif reward == 0 and length(actions) == 0 do
      # No reward, no actions - neutral
      0.5
    else
      # Other cases - scale based on reward
      max(0.0, min(1.0, 0.5 + reward))
    end
  end
  
  defp normalize_pattern_list(list, target_length) do
    cond do
      length(list) == target_length ->
        list
        
      length(list) < target_length ->
        # Pad with zeros
        list ++ List.duplicate(0.0, target_length - length(list))
        
      length(list) > target_length ->
        # Truncate
        Enum.take(list, target_length)
    end
  end
  
  defp cosine_similarity(list1, list2) do
    # Calculate cosine similarity between two vectors
    dot_product = Enum.zip(list1, list2)
    |> Enum.map(fn {a, b} -> a * b end)
    |> Enum.sum()
    
    magnitude1 = :math.sqrt(Enum.map(list1, fn x -> x * x end) |> Enum.sum())
    magnitude2 = :math.sqrt(Enum.map(list2, fn x -> x * x end) |> Enum.sum())
    
    if magnitude1 > 0 and magnitude2 > 0 do
      dot_product / (magnitude1 * magnitude2)
    else
      0.0
    end
  end
end