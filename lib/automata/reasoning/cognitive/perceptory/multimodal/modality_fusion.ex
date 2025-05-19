defmodule Automata.Perceptory.ModalityFusion do
  @moduledoc """
  Integrates perceptions across different sensory modalities.
  
  The ModalityFusion module combines information from different sensory channels
  (visual, auditory, tactile, etc.) to create a unified perceptual representation.
  This enables more robust perception by leveraging the complementary nature of
  different sensory inputs and resolving conflicts across modalities.
  
  Key capabilities:
  - Cross-modal integration of sensory data
  - Temporal alignment of multi-modal inputs
  - Confidence-weighted fusion of perceptions
  - Conflict resolution across modalities
  - Complementary information extraction
  - Multi-modal pattern recognition
  """
  
  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    modalities: map(),
    buffer_duration: pos_integer(),
    sensory_buffers: map(),
    fusion_strategies: map(),
    confidence_thresholds: map(),
    integration_window: pos_integer(),
    metrics: map()
  }
  
  defstruct [
    id: nil,
    name: "Modality Fusion",
    modalities: %{},
    buffer_duration: 1000,  # Buffer 1 second of sensory data
    sensory_buffers: %{},
    fusion_strategies: %{},
    confidence_thresholds: %{},
    integration_window: 200,  # 200ms window for temporal integration
    metrics: %{
      processed_inputs: %{},
      fusion_operations: 0,
      modality_conflicts: 0
    }
  ]
  
  @doc """
  Creates a new modality fusion system.
  """
  def new(attrs \\ %{}) do
    id = Map.get(attrs, :id, generate_id())
    
    # Define supported modalities
    default_modalities = %{
      visual: %{weight: 0.8, decay_rate: 0.1},
      auditory: %{weight: 0.7, decay_rate: 0.2},
      tactile: %{weight: 0.6, decay_rate: 0.3},
      proprioceptive: %{weight: 0.9, decay_rate: 0.05},
      semantic: %{weight: 0.8, decay_rate: 0.1}
    }
    
    modalities = Map.merge(default_modalities, Map.get(attrs, :modalities, %{}))
    
    # Initialize buffers for each modality
    buffers = Enum.reduce(modalities, %{}, fn {modality, _config}, acc ->
      Map.put(acc, modality, [])
    end)
    
    # Default confidence thresholds
    default_thresholds = %{
      visual: 0.6,
      auditory: 0.7,
      tactile: 0.7,
      proprioceptive: 0.6,
      semantic: 0.7
    }
    
    thresholds = Map.merge(default_thresholds, Map.get(attrs, :confidence_thresholds, %{}))
    
    # Default fusion strategies
    default_strategies = %{
      object_identification: &weighted_average_fusion/3,
      spatial_localization: &weighted_average_fusion/3,
      temporal_events: &temporal_fusion/3,
      semantic_interpretation: &hierarchical_fusion/3
    }
    
    strategies = Map.merge(default_strategies, Map.get(attrs, :fusion_strategies, %{}))
    
    %__MODULE__{
      id: id,
      name: Map.get(attrs, :name, "ModalityFusion #{id}"),
      modalities: modalities,
      sensory_buffers: buffers,
      fusion_strategies: strategies,
      confidence_thresholds: thresholds,
      buffer_duration: Map.get(attrs, :buffer_duration, 1000),
      integration_window: Map.get(attrs, :integration_window, 200)
    }
  end
  
  @doc """
  Processes a sensory input from a specific modality.
  
  Returns a tuple of {fused_percepts, updated_fusion_system}.
  """
  def process_input(fusion, modality, sensory_data) do
    now = :os.system_time(:millisecond)
    
    # Validate modality
    if !Map.has_key?(fusion.modalities, modality) do
      # Unsupported modality, return unchanged
      {[], fusion}
    else
      # Add timestamp to sensory data
      timestamped_data = Map.put(sensory_data, :timestamp, now)
      
      # Add to appropriate buffer
      updated_buffer = [timestamped_data | fusion.sensory_buffers[modality]]
                      |> clean_buffer(now, fusion.buffer_duration)
      
      updated_buffers = Map.put(fusion.sensory_buffers, modality, updated_buffer)
      
      # Update metrics
      updated_metrics = update_input_metrics(fusion.metrics, modality)
      
      updated_fusion = %{fusion |
        sensory_buffers: updated_buffers,
        metrics: updated_metrics
      }
      
      # Perform fusion across modalities
      {fused_percepts, fusion_after_percepts} = create_fused_percepts(updated_fusion, now)
      
      {fused_percepts, fusion_after_percepts}
    end
  end
  
  @doc """
  Retrieves the latest fused perceptual information.
  
  Takes a fusion type (e.g., :object_identification, :spatial_localization)
  and returns the most recent fused percepts of that type.
  """
  def get_latest_fusion(fusion, fusion_type) do
    now = :os.system_time(:millisecond)
    
    # First clean all buffers
    cleaned_buffers = Enum.reduce(fusion.sensory_buffers, %{}, fn {modality, buffer}, acc ->
      Map.put(acc, modality, clean_buffer(buffer, now, fusion.buffer_duration))
    end)
    
    updated_fusion = %{fusion | sensory_buffers: cleaned_buffers}
    
    # Create fused percepts focusing on requested type
    create_fused_percepts(updated_fusion, now, fusion_type)
  end
  
  @doc """
  Gets the current confidence level for a specific modality.
  """
  def get_modality_confidence(fusion, modality) do
    case Map.fetch(fusion.modalities, modality) do
      {:ok, config} ->
        # Calculate confidence based on recency and quantity of data
        buffer = Map.get(fusion.sensory_buffers, modality, [])
        
        if Enum.empty?(buffer) do
          0.0
        else
          now = :os.system_time(:millisecond)
          
          # Average age of data
          avg_age = Enum.reduce(buffer, 0, fn data, acc ->
            timestamp = Map.get(data, :timestamp, 0)
            acc + (now - timestamp)
          end) / length(buffer)
          
          # Normalize age factor (newer is better)
          age_factor = max(0.1, min(1.0, fusion.buffer_duration / max(1, avg_age)))
          
          # Quantity factor (more data is better, up to a point)
          quantity_factor = min(1.0, length(buffer) / 10)
          
          # Modality weight
          weight = Map.get(config, :weight, 0.5)
          
          # Calculate confidence
          weight * age_factor * quantity_factor
        end
        
      :error ->
        0.0  # Modality not supported
    end
  end
  
  @doc """
  Updates the configuration for a specific modality.
  """
  def configure_modality(fusion, modality, config) do
    if Map.has_key?(fusion.modalities, modality) do
      # Update existing modality config
      updated_modalities = Map.update!(fusion.modalities, modality, fn existing ->
        Map.merge(existing, config)
      end)
      
      %{fusion | modalities: updated_modalities}
    else
      # Add new modality
      updated_modalities = Map.put(fusion.modalities, modality, config)
      updated_buffers = Map.put(fusion.sensory_buffers, modality, [])
      
      %{fusion |
        modalities: updated_modalities,
        sensory_buffers: updated_buffers
      }
    end
  end
  
  # Private helpers
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp clean_buffer(buffer, now, duration) do
    # Remove items older than the buffer duration
    Enum.filter(buffer, fn data ->
      timestamp = Map.get(data, :timestamp, 0)
      now - timestamp <= duration
    end)
  end
  
  defp update_input_metrics(metrics, modality) do
    # Update processed inputs count for this modality
    updated_inputs = Map.update(
      metrics.processed_inputs,
      modality,
      1,
      &(&1 + 1)
    )
    
    %{metrics | processed_inputs: updated_inputs}
  end
  
  defp create_fused_percepts(fusion, now, specific_type \\ nil) do
    # Get strategies to apply
    strategies_to_apply = 
      if specific_type do
        # Only use the specified strategy
        case Map.fetch(fusion.fusion_strategies, specific_type) do
          {:ok, strategy} -> [{specific_type, strategy}]
          :error -> []
        end
      else
        # Use all strategies
        Map.to_list(fusion.fusion_strategies)
      end
    
    # Apply each fusion strategy
    {all_percepts, updated_fusion} = 
      Enum.reduce(strategies_to_apply, {[], fusion}, fn {type, strategy_fn}, {percepts_acc, fusion_acc} ->
        # Apply fusion strategy
        {fused, updated_fusion} = apply_fusion_strategy(fusion_acc, type, strategy_fn, now)
        
        # Add results to accumulated percepts
        {percepts_acc ++ fused, updated_fusion}
      end)
    
    {all_percepts, updated_fusion}
  end
  
  defp apply_fusion_strategy(fusion, fusion_type, strategy_fn, now) do
    # Find temporally aligned inputs from different modalities
    aligned_inputs = align_temporal_inputs(fusion.sensory_buffers, now, fusion.integration_window)
    
    # Apply fusion strategy to aligned inputs
    fused_percepts = strategy_fn.(aligned_inputs, fusion.modalities, fusion.confidence_thresholds)
    
    # Tag percepts with fusion type and timestamp
    tagged_percepts = Enum.map(fused_percepts, fn percept ->
      Map.merge(percept, %{
        fusion_type: fusion_type,
        fusion_timestamp: now
      })
    end)
    
    # Update metrics
    updated_metrics = %{fusion.metrics |
      fusion_operations: fusion.metrics.fusion_operations + 1
    }
    
    {tagged_percepts, %{fusion | metrics: updated_metrics}}
  end
  
  defp align_temporal_inputs(buffers, now, window) do
    # Group inputs that fall within the temporal integration window
    Enum.reduce(buffers, %{}, fn {modality, buffer}, acc ->
      # Find recent inputs within the window
      recent = Enum.filter(buffer, fn data ->
        timestamp = Map.get(data, :timestamp, 0)
        now - timestamp <= window
      end)
      
      if length(recent) > 0 do
        Map.put(acc, modality, recent)
      else
        acc
      end
    end)
  end
  
  # Fusion strategies
  
  defp weighted_average_fusion(aligned_inputs, modality_configs, thresholds) do
    # Extract common properties across modalities
    all_properties = extract_common_properties(aligned_inputs)
    
    # Fuse properties with weighted average
    Enum.map(all_properties, fn property_set ->
      # For each property, compute weighted average across modalities
      fused_values = Enum.reduce(property_set.values, %{}, fn {modality, value_data}, acc ->
        # Get modality weight
        config = Map.get(modality_configs, modality, %{weight: 0.5})
        weight = Map.get(config, :weight, 0.5)
        
        # Get confidence from value data
        confidence = Map.get(value_data, :confidence, 0.5)
        
        # Check against threshold
        threshold = Map.get(thresholds, modality, 0.5)
        
        if confidence >= threshold do
          # Extract the actual value
          value = Map.get(value_data, :value)
          
          # Add weighted value to accumulator
          Map.update(acc, :weighted_sum, weight * value, &(&1 + weight * value))
          |> Map.update(:weight_sum, weight, &(&1 + weight))
          |> Map.update(:confidence_sum, confidence * weight, &(&1 + confidence * weight))
          |> Map.update(:contributors, [modality], &[modality | &1])
        else
          # Below threshold, don't include
          acc
        end
      end)
      
      # Compute final value
      weight_sum = Map.get(fused_values, :weight_sum, 0)
      
      if weight_sum > 0 do
        weighted_sum = Map.get(fused_values, :weighted_sum, 0)
        confidence_sum = Map.get(fused_values, :confidence_sum, 0)
        contributors = Map.get(fused_values, :contributors, [])
        
        fused_value = weighted_sum / weight_sum
        fused_confidence = confidence_sum / weight_sum
        
        # Create fused percept
        %{
          property: property_set.property,
          value: fused_value,
          confidence: fused_confidence,
          contributing_modalities: contributors
        }
      else
        # No values above threshold
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
  
  defp temporal_fusion(aligned_inputs, modality_configs, thresholds) do
    # For temporal fusion, we need to establish a timeline of events
    # and merge events that are likely to be the same
    
    # Extract events from all modalities
    all_events = Enum.flat_map(aligned_inputs, fn {modality, inputs} ->
      Enum.map(inputs, fn input ->
        # Extract events from this input
        events = Map.get(input, :events, [])
        
        # Get modality config
        config = Map.get(modality_configs, modality, %{weight: 0.5})
        threshold = Map.get(thresholds, modality, 0.5)
        
        # Filter events by confidence threshold
        Enum.filter(events, fn event ->
          Map.get(event, :confidence, 0.5) >= threshold
        end)
        |> Enum.map(fn event ->
          # Tag with modality
          Map.put(event, :modality, modality)
          |> Map.put(:modality_weight, Map.get(config, :weight, 0.5))
        end)
      end)
      |> List.flatten()
    end)
    
    # Sort events by timestamp
    sorted_events = Enum.sort_by(all_events, fn event ->
      Map.get(event, :timestamp, 0)
    end)
    
    # Merge events that are close in time and similar in nature
    merge_temporal_events(sorted_events, 100)  # 100ms window for merging
  end
  
  defp hierarchical_fusion(aligned_inputs, modality_configs, thresholds) do
    # Hierarchical fusion uses a priority order of modalities
    # and fills in gaps from lower-priority modalities
    
    # Define modality hierarchy (higher priority first)
    hierarchy = [:visual, :auditory, :semantic, :proprioceptive, :tactile]
    
    # Filter to only modalities in the aligned inputs
    available_modalities = MapSet.intersection(
      MapSet.new(Map.keys(aligned_inputs)),
      MapSet.new(hierarchy)
    )
    |> MapSet.to_list()
    
    # Sort by hierarchy
    sorted_modalities = Enum.sort_by(available_modalities, fn modality ->
      Enum.find_index(hierarchy, &(&1 == modality)) || 999
    end)
    
    # Start with highest priority modality
    if Enum.empty?(sorted_modalities) do
      []  # No modalities available
    else
      primary_modality = List.first(sorted_modalities)
      primary_inputs = Map.get(aligned_inputs, primary_modality, [])
      
      # Create initial percepts from primary modality
      initial_percepts = extract_percepts_from_modality(
        primary_inputs, 
        primary_modality,
        thresholds
      )
      
      # Enhance with lower-priority modalities
      Enum.reduce(Enum.drop(sorted_modalities, 1), initial_percepts, fn modality, percepts ->
        modality_inputs = Map.get(aligned_inputs, modality, [])
        modality_percepts = extract_percepts_from_modality(
          modality_inputs,
          modality,
          thresholds
        )
        
        # Enhance existing percepts with supplementary information
        enhance_percepts(percepts, modality_percepts, modality)
      end)
    end
  end
  
  # Helper functions for fusion strategies
  
  defp extract_common_properties(aligned_inputs) do
    # Extract all properties from all modalities
    properties = Enum.flat_map(aligned_inputs, fn {modality, inputs} ->
      Enum.flat_map(inputs, fn input ->
        # Get properties from this input
        props = Map.get(input, :properties, %{})
        
        # Convert to list of {property, value, confidence} tuples
        Enum.map(props, fn {property, data} ->
          {property, modality, data}
        end)
      end)
    end)
    
    # Group by property
    Enum.group_by(properties, fn {property, _modality, _data} -> property end)
    |> Enum.map(fn {property, entries} ->
      # Convert to map of modality -> value for each property
      values = Enum.reduce(entries, %{}, fn {_prop, modality, data}, acc ->
        Map.put(acc, modality, data)
      end)
      
      %{property: property, values: values}
    end)
  end
  
  defp merge_temporal_events(events, time_window) do
    # Group events that are close in time
    grouped = Enum.chunk_by(events, fn event ->
      # Create temporal buckets
      time = Map.get(event, :timestamp, 0)
      div(time, time_window)
    end)
    
    # Merge each group
    Enum.map(grouped, fn group ->
      if length(group) <= 1 do
        # Single event, no merging needed
        group
      else
        # Multiple events in this time window, try to merge
        merge_event_group(group)
      end
    end)
    |> List.flatten()
  end
  
  defp merge_event_group(events) do
    # Group events by type
    by_type = Enum.group_by(events, fn event ->
      Map.get(event, :type, :unknown)
    end)
    
    # Merge each type group
    Enum.flat_map(by_type, fn {type, type_events} ->
      if length(type_events) <= 1 do
        # Single event of this type, no merging needed
        type_events
      else
        # Multiple events of same type, merge
        [merge_same_type_events(type_events, type)]
      end
    end)
  end
  
  defp merge_same_type_events(events, type) do
    # Calculate weighted average for numeric properties
    numeric_props = [:x, :y, :z, :intensity, :duration, :magnitude]
    
    merged_props = Enum.reduce(numeric_props, %{}, fn prop, acc ->
      # Collect values and weights for this property
      values_weights = Enum.map(events, fn event ->
        value = Map.get(event, prop)
        weight = Map.get(event, :modality_weight, 0.5)
        {value, weight}
      end)
      |> Enum.reject(fn {value, _weight} -> is_nil(value) end)
      
      if Enum.empty?(values_weights) do
        # No values for this property
        acc
      else
        # Calculate weighted average
        {sum, weight_sum} = Enum.reduce(values_weights, {0, 0}, fn {value, weight}, {s, w} ->
          {s + value * weight, w + weight}
        end)
        
        if weight_sum > 0 do
          Map.put(acc, prop, sum / weight_sum)
        else
          acc
        end
      end
    end)
    
    # Merge string properties (take most frequent)
    string_props = [:name, :description, :category]
    
    merged_strings = Enum.reduce(string_props, %{}, fn prop, acc ->
      # Collect values for this property
      values = Enum.map(events, fn event -> Map.get(event, prop) end)
                |> Enum.reject(&is_nil/1)
      
      if Enum.empty?(values) do
        # No values for this property
        acc
      else
        # Take most frequent value
        frequencies = Enum.frequencies(values)
        {most_frequent, _count} = Enum.max_by(frequencies, fn {_val, count} -> count end)
        
        Map.put(acc, prop, most_frequent)
      end
    end)
    
    # Get contributing modalities
    modalities = Enum.map(events, fn event -> Map.get(event, :modality) end)
                |> Enum.uniq()
    
    # Get average timestamp
    timestamps = Enum.map(events, fn event -> Map.get(event, :timestamp, 0) end)
    avg_timestamp = Enum.sum(timestamps) / length(timestamps)
    
    # Create merged event
    event_base = %{
      type: type,
      timestamp: avg_timestamp,
      contributing_modalities: modalities,
      confidence: calculate_merged_confidence(events)
    }
    
    Map.merge(event_base, merged_props)
    |> Map.merge(merged_strings)
  end
  
  defp calculate_merged_confidence(events) do
    # Calculate confidence based on agreement across modalities
    confidence_values = Enum.map(events, fn event ->
      Map.get(event, :confidence, 0.5)
    end)
    
    # Average confidence, weighted by number of modalities
    # More modalities agreeing = higher confidence
    modality_factor = min(1.0, length(events) / 3)  # Cap at 3 modalities
    
    Enum.sum(confidence_values) / length(confidence_values) * 
    (0.7 + 0.3 * modality_factor)  # Scale between 0.7-1.0 based on modality count
  end
  
  defp extract_percepts_from_modality(inputs, modality, thresholds) do
    # Get threshold for this modality
    threshold = Map.get(thresholds, modality, 0.5)
    
    # Extract percepts from inputs
    Enum.flat_map(inputs, fn input ->
      percepts = Map.get(input, :percepts, [])
      
      # Filter by confidence threshold
      Enum.filter(percepts, fn percept ->
        Map.get(percept, :confidence, 0.5) >= threshold
      end)
      |> Enum.map(fn percept ->
        # Tag with source modality
        Map.put(percept, :source_modality, modality)
      end)
    end)
  end
  
  defp enhance_percepts(base_percepts, supplementary_percepts, modality) do
    # Enhance base percepts with supplementary information
    Enum.map(base_percepts, fn base ->
      # Find matching supplementary percepts
      matches = find_matching_percepts(base, supplementary_percepts)
      
      if Enum.empty?(matches) do
        # No matching supplementary percepts
        base
      else
        # Merge with supplementary information
        supplementary_fields = extract_supplementary_fields(matches, modality)
        Map.merge(base, supplementary_fields)
      end
    end)
  end
  
  defp find_matching_percepts(base_percept, candidates) do
    # Find candidates that match the base percept
    # Matching criteria depend on the percept type
    
    # Simple matching based on ID or location
    Enum.filter(candidates, fn candidate ->
      cond do
        # If both have IDs, match on ID
        Map.has_key?(base_percept, :id) && Map.has_key?(candidate, :id) ->
          base_percept.id == candidate.id
          
        # If both have locations, match on proximity
        Map.has_key?(base_percept, :location) && Map.has_key?(candidate, :location) ->
          locations_match?(base_percept.location, candidate.location)
          
        # If both have types, match on type
        Map.has_key?(base_percept, :type) && Map.has_key?(candidate, :type) ->
          base_percept.type == candidate.type
          
        # No matching criteria
        true ->
          false
      end
    end)
  end
  
  defp locations_match?(loc1, loc2) do
    # Check if two locations are close enough to be considered the same
    # Simplistic implementation - in a real system would use proper distance calculation
    
    cond do
      is_map(loc1) && is_map(loc2) &&
      Map.has_key?(loc1, :x) && Map.has_key?(loc1, :y) &&
      Map.has_key?(loc2, :x) && Map.has_key?(loc2, :y) ->
        # Calculate Euclidean distance
        dx = loc1.x - loc2.x
        dy = loc1.y - loc2.y
        distance = :math.sqrt(dx*dx + dy*dy)
        
        # Consider match if within threshold
        distance < 10.0
        
      true ->
        # Cannot compare locations
        false
    end
  end
  
  defp extract_supplementary_fields(supplementary_percepts, modality) do
    # Extract fields that the base percept doesn't have
    # Simple implementation - in a real system would be more sophisticated
    
    # Group percepts by field
    all_fields = Enum.flat_map(supplementary_percepts, fn percept ->
      Enum.map(percept, fn {key, value} ->
        {key, value, Map.get(percept, :confidence, 0.5)}
      end)
    end)
    
    # Group by field name
    by_field = Enum.group_by(all_fields, fn {key, _value, _conf} -> key end)
    
    # For each field, take highest confidence value
    Enum.reduce(by_field, %{}, fn {key, values}, acc ->
      # Skip certain fields
      if key in [:id, :source_modality, :confidence] do
        acc
      else
        # Find highest confidence value
        {_k, value, conf} = Enum.max_by(values, fn {_k, _v, confidence} -> confidence end)
        
        # Add to supplementary fields with modality tag
        Map.put(acc, :"#{key}_from_#{modality}", value)
        |> Map.put(:"#{key}_confidence", conf)
      end
    end)
    |> Map.put(:enhanced_by_modalities, [modality])
  end
end