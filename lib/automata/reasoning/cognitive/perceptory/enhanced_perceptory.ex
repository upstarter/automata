defmodule Automata.Perceptory.Enhanced do
  @moduledoc """
  Enhanced Perceptory module that integrates all perception components.
  
  This module provides a comprehensive interface to the enhanced perception system,
  including pattern recognition, temporal sequences, attention control, associative
  memory, and multi-modal fusion. It coordinates the interaction between these
  components to create a sophisticated perception system capable of filtering,
  processing, and remembering environmental information in a contextually relevant way.
  """
  
  alias Automata.Perceptory
  alias Automata.Perceptory.Supervisor, as: PerceptorySupervisor
  alias Automata.Perceptory.PatternMatcher
  alias Automata.Perceptory.TemporalPattern
  alias Automata.Perceptory.AttentionController
  alias Automata.Perceptory.AssociativeMemory
  alias Automata.Perceptory.ModalityFusion
  
  @doc """
  Starts the enhanced perceptory system.
  
  This starts the perceptory supervisor which manages all perception components.
  """
  def start_link(opts) do
    PerceptorySupervisor.start_link(opts)
  end
  
  @doc """
  Processes sensory input through the enhanced perception system.
  
  This is the main entry point for perception. It coordinates the processing
  of sensory input through all perception components:
  
  1. Sensory data is processed by the pattern matcher to identify patterns
  2. Identified patterns are passed to the attention controller to determine focus
  3. Focused patterns are stored in associative memory
  4. Temporal patterns are updated based on the sequence of percepts
  5. Multi-modal fusion combines information across sensory modalities
  
  Returns a comprehensive perception result with identified patterns, attention
  focus, memory activations, and temporal predictions.
  """
  def process_sensory_input(agent_id, sensory_input, context \\ %{}) do
    # Process through pattern matcher
    pattern_matches = pattern_matcher_process(agent_id, sensory_input)
    
    # Update attention with pattern matches
    focus_points = attention_update(agent_id, %{percepts: pattern_matches}, context)
    
    # Store focused percepts in associative memory
    focused_percepts = Enum.filter(pattern_matches, fn percept ->
      percept_has_attention?(agent_id, percept)
    end)
    
    memory_results = store_in_memory(agent_id, focused_percepts)
    
    # Update temporal patterns
    temporal_patterns = process_temporal_events(agent_id, focused_percepts)
    
    # Process through modality fusion if input has modality info
    fusion_results = 
      if is_map(sensory_input) && Map.has_key?(sensory_input, :modality) do
        modality = Map.get(sensory_input, :modality)
        modality_fusion_process(agent_id, modality, sensory_input)
      else
        []
      end
    
    # Build comprehensive result
    %{
      pattern_matches: pattern_matches,
      focus_points: focus_points,
      memory_results: memory_results,
      temporal_patterns: temporal_patterns,
      fusion_results: fusion_results,
      predictions: predict_next_events(agent_id)
    }
  end
  
  @doc """
  Processes input from a specific sensory modality.
  
  This is used for multi-modal perception when sensory inputs come from
  different modalities (visual, auditory, etc.) and need to be combined.
  """
  def process_modality(agent_id, modality, sensory_data) do
    modality_fusion_process(agent_id, modality, sensory_data)
  end
  
  @doc """
  Gets the latest fused perceptual information of a specific type.
  """
  def get_fused_perception(agent_id, fusion_type) do
    fusion_pid = PerceptorySupervisor.via_tuple(agent_id, :modality_fusion)
    GenServer.call(fusion_pid, {:get_latest_fusion, fusion_type})
  end
  
  @doc """
  Directs attention to a specific focus point.
  
  This allows for explicit control of attention rather than letting the
  attention controller decide based on salience.
  """
  def direct_attention(agent_id, focus) do
    attention_pid = PerceptorySupervisor.via_tuple(agent_id, :attention)
    GenServer.call(attention_pid, {:direct_attention, focus})
  end
  
  @doc """
  Sets a goal to direct attention toward goal-relevant percepts.
  """
  def set_attention_goal(agent_id, goal) do
    attention_pid = PerceptorySupervisor.via_tuple(agent_id, :attention)
    GenServer.call(attention_pid, {:set_goal, goal})
  end
  
  @doc """
  Retrieves memories related to a query using associative memory.
  """
  def retrieve_memories(agent_id, query, max_results \\ 10) do
    memory_pid = PerceptorySupervisor.via_tuple(agent_id, :associative_memory)
    GenServer.call(memory_pid, {:retrieve, query, max_results})
  end
  
  @doc """
  Adds a pattern for the pattern matcher to recognize.
  """
  def add_pattern(agent_id, pattern) do
    pattern_pid = PerceptorySupervisor.via_tuple(agent_id, :pattern_matcher)
    GenServer.call(pattern_pid, {:add_pattern, pattern})
  end
  
  @doc """
  Adds a sequence pattern for the temporal pattern detector to recognize.
  """
  def add_sequence_pattern(agent_id, pattern) do
    temporal_pid = PerceptorySupervisor.via_tuple(agent_id, :temporal_pattern)
    GenServer.call(temporal_pid, {:add_sequence_pattern, pattern})
  end
  
  @doc """
  Predicts the next likely events based on observed temporal patterns.
  """
  def predict_next_events(agent_id) do
    temporal_pid = PerceptorySupervisor.via_tuple(agent_id, :temporal_pattern)
    GenServer.call(temporal_pid, :predict_next_events)
  end
  
  @doc """
  Explicitly creates an association between two memories.
  """
  def associate_memories(agent_id, memory_id1, memory_id2, strength \\ 0.5) do
    memory_pid = PerceptorySupervisor.via_tuple(agent_id, :associative_memory)
    GenServer.call(memory_pid, {:associate, memory_id1, memory_id2, strength})
  end
  
  @doc """
  Configures a specific sensory modality in the fusion system.
  """
  def configure_modality(agent_id, modality, config) do
    fusion_pid = PerceptorySupervisor.via_tuple(agent_id, :modality_fusion)
    GenServer.call(fusion_pid, {:configure_modality, modality, config})
  end
  
  @doc """
  Gets performance metrics from all perception components.
  """
  def get_perception_metrics(agent_id) do
    # Gather metrics from all components
    pattern_pid = PerceptorySupervisor.via_tuple(agent_id, :pattern_matcher)
    pattern_matcher = GenServer.call(pattern_pid, :get_state)
    
    temporal_pid = PerceptorySupervisor.via_tuple(agent_id, :temporal_pattern)
    temporal_pattern = GenServer.call(temporal_pid, :get_state)
    
    attention_pid = PerceptorySupervisor.via_tuple(agent_id, :attention)
    attention = GenServer.call(attention_pid, :get_state)
    
    memory_pid = PerceptorySupervisor.via_tuple(agent_id, :associative_memory)
    memory_metrics = GenServer.call(memory_pid, :get_metrics)
    
    fusion_pid = PerceptorySupervisor.via_tuple(agent_id, :modality_fusion)
    fusion = GenServer.call(fusion_pid, :get_state)
    
    # Combine metrics into a unified report
    %{
      pattern_matcher: pattern_matcher.metrics,
      temporal_pattern: temporal_pattern.metrics,
      attention: attention.metrics,
      associative_memory: memory_metrics,
      modality_fusion: fusion.metrics
    }
  end
  
  # Private helpers for component interaction
  
  defp pattern_matcher_process(agent_id, sensory_input) do
    pattern_pid = PerceptorySupervisor.via_tuple(agent_id, :pattern_matcher)
    GenServer.call(pattern_pid, {:process, sensory_input})
  end
  
  defp attention_update(agent_id, perceptual_input, context) do
    attention_pid = PerceptorySupervisor.via_tuple(agent_id, :attention)
    GenServer.call(attention_pid, {:update, perceptual_input, context})
  end
  
  defp percept_has_attention?(agent_id, percept) do
    percept_id = Map.get(percept, :id)
    
    if percept_id do
      attention_pid = PerceptorySupervisor.via_tuple(agent_id, :attention)
      GenServer.call(attention_pid, {:has_attention, percept_id})
    else
      false
    end
  end
  
  defp store_in_memory(agent_id, percepts) do
    memory_pid = PerceptorySupervisor.via_tuple(agent_id, :associative_memory)
    
    # Store each percept as a memory
    Enum.map(percepts, fn percept ->
      GenServer.call(memory_pid, {:store, percept})
      percept
    end)
  end
  
  defp process_temporal_events(agent_id, events) do
    temporal_pid = PerceptorySupervisor.via_tuple(agent_id, :temporal_pattern)
    
    # Process each event
    Enum.flat_map(events, fn event ->
      GenServer.call(temporal_pid, {:process_event, event})
    end)
  end
  
  defp modality_fusion_process(agent_id, modality, sensory_data) do
    fusion_pid = PerceptorySupervisor.via_tuple(agent_id, :modality_fusion)
    GenServer.call(fusion_pid, {:process_input, modality, sensory_data})
  end
end