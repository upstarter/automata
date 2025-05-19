defmodule Automata.Reasoning.Cognitive.NeuroIntegration.NeuralPerceptionBuilder do
  @moduledoc """
  Builds integrated neural perception systems.
  
  This module provides factory functions for creating neural perception systems
  with evolved neural networks integrated at various levels:
  
  - Pattern recognition
  - Attention control
  - Memory association
  - Multi-modal integration
  
  The builder enables easy creation of complete perception systems with
  neural enhancements for specific cognitive functions.
  """
  
  alias Automata.Reasoning.Cognitive.Perceptory.EnhancedPerceptory
  alias Automata.Reasoning.Cognitive.Perceptory.PatternRecognition.PatternMatcher
  alias Automata.Reasoning.Cognitive.Perceptory.PatternRecognition.TemporalPattern
  alias Automata.Reasoning.Cognitive.Perceptory.Attention.AttentionController
  alias Automata.Reasoning.Cognitive.Perceptory.Memory.AssociativeMemory
  alias Automata.Reasoning.Cognitive.Perceptory.MultiModal.ModalityFusion
  alias Automata.Reasoning.Cognitive.Perceptory.PerceptorySuperisor
  alias Automata.Reasoning.Cognitive.NeuroIntegration.PerceptionAdapter
  alias Automaton.Types.TWEANN.ExoSelf
  
  require Logger
  
  @doc """
  Creates a complete neural-enhanced perception system.
  
  This function builds a full perception system with neural networks integrated
  at all levels.
  
  ## Parameters
  - config: Configuration for the perception system
  - network_files: Map of component names to network files
  
  ## Returns
  Complete neural-enhanced perception system
  """
  def build_complete_neural_perception(config, network_files) do
    # Create individual components with neural enhancements
    pattern_matcher = build_neural_pattern_matcher(
      config.pattern_matcher,
      network_files.pattern_recognition
    )
    
    temporal_pattern = build_neural_temporal_pattern(
      config.temporal_pattern,
      network_files.temporal_pattern
    )
    
    attention_controller = build_neural_attention_controller(
      config.attention,
      network_files.attention
    )
    
    associative_memory = build_neural_associative_memory(
      config.memory,
      network_files.memory
    )
    
    modality_fusion = build_neural_modality_fusion(
      config.modality_fusion,
      network_files.modality_fusion
    )
    
    # Create main perception adapter
    perception_adapter = PerceptionAdapter.new(
      nil,  # Will be set after initialization
      network_files.main,
      config.input_mapping,
      config.output_mapping
    )
    
    # Create enhanced perceptory
    perceptory = EnhancedPerceptory.new(
      pattern_matcher,
      temporal_pattern,
      attention_controller,
      associative_memory,
      modality_fusion,
      perception_adapter
    )
    
    # Update perception adapter with reference to the perceptory
    updated_adapter = %{perception_adapter | perceptory: perceptory}
    %{perceptory | perception_adapter: updated_adapter}
  end
  
  @doc """
  Builds a neural pattern matcher component.
  
  This function creates a pattern matcher that uses a neural network for
  pattern recognition.
  
  ## Parameters
  - config: Configuration for the pattern matcher
  - network_file: Path to neural network file
  
  ## Returns
  Neural-enhanced pattern matcher
  """
  def build_neural_pattern_matcher(config, network_file) do
    # Create basic pattern matcher
    matcher = PatternMatcher.new(
      config.patterns,
      config.similarity_threshold,
      config.feature_extractors
    )
    
    # Add neural network if provided
    if network_file do
      # Load neural network
      {:ok, network} = load_neural_network(network_file)
      
      # Enhance with neural capabilities
      %{matcher | 
        neural_network: network,
        use_neural_recognition: true
      }
    else
      matcher
    end
  end
  
  @doc """
  Builds a neural temporal pattern recognizer.
  
  This function creates a temporal pattern recognizer that uses a neural network
  for sequence recognition and prediction.
  
  ## Parameters
  - config: Configuration for the temporal pattern recognizer
  - network_file: Path to neural network file
  
  ## Returns
  Neural-enhanced temporal pattern recognizer
  """
  def build_neural_temporal_pattern(config, network_file) do
    # Create basic temporal pattern recognizer
    temporal = TemporalPattern.new(
      config.sequence_patterns,
      config.max_sequence_length,
      config.temporal_window
    )
    
    # Add neural network if provided
    if network_file do
      # Load neural network
      {:ok, network} = load_neural_network(network_file)
      
      # Enhance with neural capabilities
      %{temporal | 
        neural_network: network,
        use_neural_prediction: true
      }
    else
      temporal
    end
  end
  
  @doc """
  Builds a neural attention controller.
  
  This function creates an attention controller that uses a neural network
  for attention allocation and focus control.
  
  ## Parameters
  - config: Configuration for the attention controller
  - network_file: Path to neural network file
  
  ## Returns
  Neural-enhanced attention controller
  """
  def build_neural_attention_controller(config, network_file) do
    # Create basic attention controller
    controller = AttentionController.new(
      config.focus_types,
      config.default_weights,
      config.max_attention_capacity
    )
    
    # Add neural network if provided
    if network_file do
      # Load neural network
      {:ok, network} = load_neural_network(network_file)
      
      # Enhance with neural capabilities
      %{controller | 
        neural_network: network,
        use_neural_attention: true
      }
    else
      controller
    end
  end
  
  @doc """
  Builds a neural associative memory.
  
  This function creates an associative memory that uses a neural network
  for association formation and retrieval.
  
  ## Parameters
  - config: Configuration for the associative memory
  - network_file: Path to neural network file
  
  ## Returns
  Neural-enhanced associative memory
  """
  def build_neural_associative_memory(config, network_file) do
    # Create basic associative memory
    memory = AssociativeMemory.new(
      config.association_threshold,
      config.decay_rate,
      config.max_associations
    )
    
    # Add neural network if provided
    if network_file do
      # Load neural network
      {:ok, network} = load_neural_network(network_file)
      
      # Enhance with neural capabilities
      %{memory | 
        neural_network: network,
        use_neural_association: true
      }
    else
      memory
    end
  end
  
  @doc """
  Builds a neural modality fusion component.
  
  This function creates a modality fusion component that uses a neural network
  for integrating information across sensory modalities.
  
  ## Parameters
  - config: Configuration for the modality fusion component
  - network_file: Path to neural network file
  
  ## Returns
  Neural-enhanced modality fusion component
  """
  def build_neural_modality_fusion(config, network_file) do
    # Create basic modality fusion component
    fusion = ModalityFusion.new(
      config.modalities,
      config.fusion_strategies,
      config.confidence_thresholds
    )
    
    # Add neural network if provided
    if network_file do
      # Load neural network
      {:ok, network} = load_neural_network(network_file)
      
      # Enhance with neural capabilities
      %{fusion | 
        neural_network: network,
        use_neural_fusion: true
      }
    else
      fusion
    end
  end
  
  @doc """
  Initializes the neural networks in a perception system.
  
  This function activates all neural networks in the perception system.
  
  ## Parameters
  - perceptory: The perception system to initialize
  
  ## Returns
  Initialized perception system
  """
  def initialize_neural_networks(perceptory) do
    # Initialize main perception adapter
    updated_adapter = PerceptionAdapter.initialize_network(
      perceptory.perception_adapter,
      perceptory.perception_adapter.network_file
    )
    
    # Initialize component neural networks
    initialized_pattern_matcher = initialize_component_network(
      perceptory.pattern_matcher,
      :pattern_recognition
    )
    
    initialized_temporal_pattern = initialize_component_network(
      perceptory.temporal_pattern,
      :temporal_pattern
    )
    
    initialized_attention_controller = initialize_component_network(
      perceptory.attention_controller,
      :attention
    )
    
    initialized_associative_memory = initialize_component_network(
      perceptory.associative_memory,
      :memory
    )
    
    initialized_modality_fusion = initialize_component_network(
      perceptory.modality_fusion,
      :modality_fusion
    )
    
    # Update perceptory with initialized components
    %{perceptory | 
      perception_adapter: updated_adapter,
      pattern_matcher: initialized_pattern_matcher,
      temporal_pattern: initialized_temporal_pattern,
      attention_controller: initialized_attention_controller,
      associative_memory: initialized_associative_memory,
      modality_fusion: initialized_modality_fusion
    }
  end
  
  # Private helper functions
  
  defp load_neural_network(network_file) do
    # Use ExoSelf to load the neural network
    Task.async(fn -> ExoSelf.map(network_file) end)
    |> Task.await(:infinity)
    
    # ExoSelf.map returns the cortex PID
    {:ok, Process.whereis(:cortex)}
  end
  
  defp initialize_component_network(component, _component_type) do
    # Check if component has a neural network
    if Map.has_key?(component, :neural_network) && 
       component.neural_network && 
       Map.has_key?(component, :use_neural_recognition) do
      # Component has neural capabilities, initialize if not already active
      if component.neural_network == nil do
        # Initialize network
        case load_neural_network(component.network_file) do
          {:ok, network} ->
            %{component | neural_network: network}
          _ ->
            Logger.warning("Failed to initialize neural network for #{component}")
            component
        end
      else
        component
      end
    else
      # Component doesn't have neural capabilities
      component
    end
  end
end