defmodule Automata.Reasoning.Cognitive.NeuroIntegration.PerceptionAdapter do
  @moduledoc """
  Integrates the advanced perception system with neural networks.
  
  This module acts as a bridge between the perception system and neural networks,
  converting perception data into neural inputs and neural outputs into perception
  focus or behavior signals.
  
  Key features:
  - Perception-to-neuron input mapping
  - Attention direction based on neural output
  - Pattern recognition informed by neural processing
  - Bidirectional information flow between systems
  """
  
  alias Automata.Reasoning.Cognitive.Perceptory.EnhancedPerceptory
  alias Automata.Reasoning.Cognitive.Perceptory.Memory.AssociativeMemory
  alias Automata.Reasoning.Cognitive.Perceptory.Attention.AttentionController
  alias Automata.Reasoning.Cognitive.Perceptory.PatternRecognition.PatternMatcher
  alias Automata.Reasoning.Cognitive.Perceptory.Percepts.Percept
  alias Automata.Reasoning.Cognitive.Perceptory.PerceptMemories.PerceptMem
  alias Automaton.Types.TWEANN.Cortex
  alias Automaton.Types.TWEANN.ExoSelf
  
  require Logger
  
  defstruct [
    :perceptory,           # Reference to the perception system
    :network_manager,      # Reference to the neural network manager
    :input_mapping,        # How perceptions map to neural inputs
    :output_mapping,       # How neural outputs map to system actions
    :attention_weights,    # Current attention focus weights from neural feedback
    :cortex_pid,           # PID of the active neural network cortex
    :active               # Whether the adapter is currently active
  ]
  
  @doc """
  Creates a new perception adapter connecting perception to neural networks.
  
  ## Parameters
  - perceptory: The perceptory system reference
  - network_config: Neural network configuration
  - input_mapping: Map of perception types to neural input indices
  - output_mapping: Map of neural output indices to action types
  
  ## Returns
  A new PerceptionAdapter struct
  """
  def new(perceptory, network_config, input_mapping, output_mapping) do
    %__MODULE__{
      perceptory: perceptory,
      network_manager: nil,  # Will be set when network is loaded
      input_mapping: input_mapping,
      output_mapping: output_mapping,
      attention_weights: %{},
      cortex_pid: nil,
      active: false
    }
  end
  
  @doc """
  Initializes the neural network and establishes connections.
  
  ## Parameters
  - adapter: The perception adapter
  - network_file: Path to neural network definition file
  
  ## Returns
  Updated adapter with initialized network
  """
  def initialize_network(adapter, network_file) do
    # Start the neural network
    {:ok, cortex_pid} = load_neural_network(network_file)
    
    # Set up adapter state
    %{adapter | 
      cortex_pid: cortex_pid,
      active: true
    }
  end
  
  @doc """
  Processes perceptory data through the neural network.
  
  ## Parameters
  - adapter: The perception adapter
  - perceptory_state: Current state of the perception system
  
  ## Returns
  Tuple of {updated_adapter, actions} where actions are derived from neural outputs
  """
  def process(adapter, perceptory_state) do
    if adapter.active do
      # Convert perceptions to neural inputs
      neural_inputs = map_perceptions_to_neural_inputs(perceptory_state, adapter.input_mapping)
      
      # Send inputs to neural network
      neural_outputs = send_to_network(adapter.cortex_pid, neural_inputs)
      
      # Map neural outputs to actions
      actions = map_neural_outputs_to_actions(neural_outputs, adapter.output_mapping)
      
      # Update attention weights based on neural feedback
      updated_adapter = update_attention_focus(adapter, neural_outputs)
      
      {updated_adapter, actions}
    else
      {adapter, []}
    end
  end
  
  @doc """
  Updates the adapter's perception-to-neuron input mapping.
  
  ## Parameters
  - adapter: The perception adapter
  - input_mapping: New mapping of perception types to neural input indices
  
  ## Returns
  Updated adapter
  """
  def update_input_mapping(adapter, input_mapping) do
    %{adapter | input_mapping: input_mapping}
  end
  
  @doc """
  Updates the adapter's neuron-output-to-action mapping.
  
  ## Parameters
  - adapter: The perception adapter
  - output_mapping: New mapping of neural output indices to action types
  
  ## Returns
  Updated adapter
  """
  def update_output_mapping(adapter, output_mapping) do
    %{adapter | output_mapping: output_mapping}
  end
  
  @doc """
  Provides feedback to the perception system based on neural processing.
  
  ## Parameters
  - adapter: The perception adapter
  - perceptory: The perception system to update
  
  ## Returns
  Updated perception system
  """
  def provide_perception_feedback(adapter, perceptory) do
    if adapter.active and map_size(adapter.attention_weights) > 0 do
      # Update attention focus in perception system
      AttentionController.update_focus_weights(
        perceptory.attention_controller,
        adapter.attention_weights
      )
    else
      perceptory
    end
  end
  
  @doc """
  Trains the neural network using perception data and reinforcement.
  
  ## Parameters
  - adapter: The perception adapter
  - perceptory_states: Sequence of perception states
  - rewards: Corresponding rewards for each state
  
  ## Returns
  Updated adapter with trained network
  """
  def train_with_perceptions(adapter, perceptory_states, rewards) do
    # Future implementation for training the network
    # This would use the perceptory states and rewards to adjust network weights
    adapter
  end
  
  # Private helper functions
  
  defp load_neural_network(network_file) do
    # Use ExoSelf to load the neural network
    Task.async(fn -> ExoSelf.map(network_file) end)
    |> Task.await(:infinity)
    
    # ExoSelf.map returns the cortex PID
    {:ok, Process.whereis(:cortex)}
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
  
  defp update_attention_focus(adapter, neural_outputs) do
    # Extract attention focus signals from neural outputs
    attention_weights = Enum.with_index(neural_outputs)
    |> Enum.reduce(%{}, fn {output_value, index}, acc ->
      case Map.get(adapter.output_mapping, index) do
        {:attention, threshold, focus_type} when output_value >= threshold ->
          # Neural output indicates attention focus change
          Map.put(acc, focus_type, output_value)
          
        _ -> acc
      end
    end)
    
    %{adapter | attention_weights: attention_weights}
  end
end