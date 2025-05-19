defmodule Automata.Perceptory.AssociativeMemory do
  @moduledoc """
  A memory system that connects related perceptions through associations.
  
  AssociativeMemory creates links between related perceptions, enabling
  spreading activation, memory priming, and contextual recall. This allows
  agents to retrieve relevant memories based on relationships rather than
  just direct matches.
  
  Key capabilities:
  - Association between related memories
  - Spreading activation for retrieval
  - Memory consolidation and strengthening
  - Semantic network for knowledge representation
  - Contextual memory retrieval
  - Recency and frequency-based relevance
  """
  
  alias Automata.Perceptory.PercepMem
  alias Automata.Perceptory.Activation
  
  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    memories: map(),                 # Map of memory_id -> memory
    associations: map(),             # Map of memory_id -> list of {connected_id, strength}
    activation_values: map(),        # Map of memory_id -> activation
    retrieval_threshold: float(),
    spreading_factor: float(),
    consolidation_interval: pos_integer(),
    last_consolidation: integer(),
    metrics: map()
  }
  
  defstruct [
    id: nil,
    name: "Associative Memory",
    memories: %{},
    associations: %{},
    activation_values: %{},
    retrieval_threshold: 0.2,
    spreading_factor: 0.5,
    consolidation_interval: 60_000,  # 1 minute
    last_consolidation: 0,
    metrics: %{
      total_memories: 0,
      total_associations: 0,
      retrievals: 0,
      avg_associations_per_memory: 0.0
    }
  ]
  
  @doc """
  Creates a new associative memory system.
  """
  def new(attrs \\ %{}) do
    id = Map.get(attrs, :id, generate_id())
    
    %__MODULE__{
      id: id,
      name: Map.get(attrs, :name, "AssociativeMemory #{id}"),
      retrieval_threshold: Map.get(attrs, :retrieval_threshold, 0.2),
      spreading_factor: Map.get(attrs, :spreading_factor, 0.5),
      consolidation_interval: Map.get(attrs, :consolidation_interval, 60_000),
      last_consolidation: :os.system_time(:millisecond)
    }
  end
  
  @doc """
  Stores a new memory, creating associations with existing memories.
  
  Returns the updated memory system.
  """
  def store(memory_system, memory) do
    now = :os.system_time(:millisecond)
    memory_id = Map.get(memory, :id) || generate_id()
    
    # Ensure memory has an ID
    memory_with_id = Map.put(memory, :id, memory_id)
    
    # Store memory
    updated_memories = Map.put(memory_system.memories, memory_id, memory_with_id)
    
    # Create initial activation for this memory
    activation = Activation.new(1.0)  # Start with full activation
    updated_activations = Map.put(memory_system.activation_values, memory_id, activation)
    
    # Find existing memories that should be associated with this one
    new_associations = find_associations(memory_system, memory_with_id)
    
    # Add associations
    updated_associations = add_associations(memory_system.associations, memory_id, new_associations)
    
    # Update metrics
    updated_metrics = %{memory_system.metrics |
      total_memories: map_size(updated_memories),
      total_associations: count_total_associations(updated_associations),
      avg_associations_per_memory: avg_associations_per_memory(updated_associations)
    }
    
    # Check if consolidation is needed
    updated = %{memory_system |
      memories: updated_memories,
      associations: updated_associations,
      activation_values: updated_activations,
      metrics: updated_metrics
    }
    
    if now - memory_system.last_consolidation >= memory_system.consolidation_interval do
      # Perform memory consolidation
      consolidated = consolidate_memory(updated)
      %{consolidated | last_consolidation: now}
    else
      updated
    end
  end
  
  @doc """
  Retrieves memories related to a query, using spreading activation.
  
  Returns a tuple of {retrieved_memories, updated_memory_system} where
  retrieved_memories is a list of memories sorted by relevance.
  """
  def retrieve(memory_system, query, max_results \\ 10) do
    # Calculate initial activations based on query
    initial_activations = calculate_initial_activations(memory_system, query)
    
    # Apply spreading activation
    final_activations = spread_activation(
      memory_system.associations,
      initial_activations,
      memory_system.spreading_factor,
      3  # max_depth
    )
    
    # Select memories above threshold
    retrieved = final_activations
                |> Enum.filter(fn {_id, activation} -> 
                  activation >= memory_system.retrieval_threshold
                end)
                |> Enum.sort_by(fn {_id, activation} -> activation end, :desc)
                |> Enum.take(max_results)
                |> Enum.map(fn {id, activation} -> 
                  {Map.get(memory_system.memories, id), activation}
                end)
    
    # Update activations based on retrieval
    updated_activations = update_activations_after_retrieval(
      memory_system.activation_values,
      Enum.map(retrieved, fn {memory, _act} -> memory.id end)
    )
    
    # Update metrics
    updated_metrics = %{memory_system.metrics |
      retrievals: memory_system.metrics.retrievals + 1
    }
    
    updated_memory_system = %{memory_system |
      activation_values: updated_activations,
      metrics: updated_metrics
    }
    
    {retrieved, updated_memory_system}
  end
  
  @doc """
  Explicitly creates an association between two memories.
  """
  def associate(memory_system, memory_id1, memory_id2, strength \\ 0.5) do
    # Verify both memories exist
    if Map.has_key?(memory_system.memories, memory_id1) &&
       Map.has_key?(memory_system.memories, memory_id2) do
      
      # Add bi-directional association
      assocs1 = Map.get(memory_system.associations, memory_id1, [])
      assocs2 = Map.get(memory_system.associations, memory_id2, [])
      
      # Check if association already exists
      existing1 = Enum.find(assocs1, fn {id, _str} -> id == memory_id2 end)
      existing2 = Enum.find(assocs2, fn {id, _str} -> id == memory_id1 end)
      
      updated_assocs1 = if existing1 do
        # Update existing association
        Enum.map(assocs1, fn
          {^memory_id2, _} -> {memory_id2, strength}
          other -> other
        end)
      else
        # Add new association
        [{memory_id2, strength} | assocs1]
      end
      
      updated_assocs2 = if existing2 do
        # Update existing association
        Enum.map(assocs2, fn
          {^memory_id1, _} -> {memory_id1, strength}
          other -> other
        end)
      else
        # Add new association
        [{memory_id1, strength} | assocs2]
      end
      
      # Update associations map
      updated_associations = memory_system.associations
                            |> Map.put(memory_id1, updated_assocs1)
                            |> Map.put(memory_id2, updated_assocs2)
      
      # Update metrics
      updated_metrics = %{memory_system.metrics |
        total_associations: count_total_associations(updated_associations),
        avg_associations_per_memory: avg_associations_per_memory(updated_associations)
      }
      
      %{memory_system |
        associations: updated_associations,
        metrics: updated_metrics
      }
    else
      # One or both memories don't exist
      memory_system
    end
  end
  
  @doc """
  Removes a memory and all its associations.
  """
  def forget(memory_system, memory_id) do
    if Map.has_key?(memory_system.memories, memory_id) do
      # Remove memory
      updated_memories = Map.delete(memory_system.memories, memory_id)
      
      # Remove activation
      updated_activations = Map.delete(memory_system.activation_values, memory_id)
      
      # Remove associations to this memory from all other memories
      updated_associations = 
        Enum.reduce(memory_system.associations, %{}, fn {id, assocs}, acc ->
          if id == memory_id do
            # Skip associations for the forgotten memory
            acc
          else
            # Remove any associations to the forgotten memory
            updated_assocs = Enum.reject(assocs, fn {target_id, _} -> 
              target_id == memory_id
            end)
            Map.put(acc, id, updated_assocs)
          end
        end)
      
      # Update metrics
      updated_metrics = %{memory_system.metrics |
        total_memories: map_size(updated_memories),
        total_associations: count_total_associations(updated_associations),
        avg_associations_per_memory: avg_associations_per_memory(updated_associations)
      }
      
      %{memory_system |
        memories: updated_memories,
        associations: updated_associations,
        activation_values: updated_activations,
        metrics: updated_metrics
      }
    else
      # Memory doesn't exist
      memory_system
    end
  end
  
  @doc """
  Gets the activation level of a memory.
  """
  def get_activation(memory_system, memory_id) do
    activation = Map.get(memory_system.activation_values, memory_id)
    
    if activation do
      Activation.current_value(activation)
    else
      0.0
    end
  end
  
  @doc """
  Gets metrics about the memory system.
  """
  def get_metrics(memory_system) do
    memory_system.metrics
  end
  
  # Private helpers
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp find_associations(memory_system, memory) do
    # Find memories that are similar to the new one
    Enum.filter(memory_system.memories, fn {id, existing_memory} ->
      # Don't associate with self
      id != memory.id &&
      # Check if memories are related
      memories_related?(memory, existing_memory)
    end)
    |> Enum.map(fn {id, _memory} ->
      # Calculate association strength
      strength = 0.5  # For now, use a fixed strength
      {id, strength}
    end)
  end
  
  defp memories_related?(memory1, memory2) do
    # In a real implementation, this would use more sophisticated
    # similarity measures based on content, context, time, etc.
    
    # For this example, we'll use a simple check based on common keys
    # with similar values
    if is_map(memory1) && is_map(memory2) do
      # Count common keys
      common_keys = MapSet.intersection(
        MapSet.new(Map.keys(memory1)),
        MapSet.new(Map.keys(memory2))
      )
      
      # Check for similarity in common attributes
      similar_values = Enum.count(common_keys, fn key ->
        val1 = Map.get(memory1, key)
        val2 = Map.get(memory2, key)
        values_similar?(val1, val2)
      end)
      
      # Consider memories related if they share enough similar attributes
      similar_values >= 2
    else
      false
    end
  end
  
  defp values_similar?(val1, val2) do
    # Basic similarity check for different types
    cond do
      is_number(val1) && is_number(val2) ->
        # For numbers, check if they're within 10% of each other
        max_val = max(abs(val1), abs(val2))
        if max_val > 0 do
          abs(val1 - val2) / max_val < 0.1
        else
          val1 == val2
        end
        
      is_binary(val1) && is_binary(val2) ->
        # For strings, check for exact match or if one contains the other
        val1 == val2 || 
        String.contains?(String.downcase(val1), String.downcase(val2)) ||
        String.contains?(String.downcase(val2), String.downcase(val1))
        
      is_atom(val1) && is_atom(val2) ->
        # For atoms, exact match only
        val1 == val2
        
      is_list(val1) && is_list(val2) ->
        # For lists, check if they share elements
        common = MapSet.intersection(
          MapSet.new(val1),
          MapSet.new(val2)
        )
        MapSet.size(common) > 0
        
      is_map(val1) && is_map(val2) ->
        # For maps, check if they share keys
        common_keys = MapSet.intersection(
          MapSet.new(Map.keys(val1)),
          MapSet.new(Map.keys(val2))
        )
        MapSet.size(common_keys) > 0
        
      true ->
        # For other types, only exact match
        val1 == val2
    end
  end
  
  defp add_associations(associations, memory_id, new_associations) do
    # Get existing associations for this memory
    existing = Map.get(associations, memory_id, [])
    
    # Combine with new associations
    combined = existing ++ new_associations
    
    # Ensure no duplicates by merging based on ID
    merged = Enum.reduce(combined, %{}, fn {id, strength}, acc ->
      case Map.get(acc, id) do
        nil ->
          # New association
          Map.put(acc, id, strength)
          
        existing_strength ->
          # Merge strengths (take the higher value)
          Map.put(acc, id, max(existing_strength, strength))
      end
    end)
    
    # Convert back to list format
    merged_list = Enum.map(merged, fn {id, strength} -> {id, strength} end)
    
    # Add reciprocal associations for each new association
    final_associations = Enum.reduce(new_associations, associations, fn {other_id, strength}, acc ->
      other_existing = Map.get(acc, other_id, [])
      
      # Check if reverse association already exists
      has_reverse = Enum.any?(other_existing, fn {id, _} -> id == memory_id end)
      
      if has_reverse do
        # Update existing reverse association
        updated_other = Enum.map(other_existing, fn
          {^memory_id, _} -> {memory_id, strength}
          other -> other
        end)
        Map.put(acc, other_id, updated_other)
      else
        # Add new reverse association
        Map.put(acc, other_id, [{memory_id, strength} | other_existing])
      end
    end)
    
    # Update the primary association
    Map.put(final_associations, memory_id, merged_list)
  end
  
  defp count_total_associations(associations) do
    Enum.reduce(associations, 0, fn {_id, assocs}, acc ->
      acc + length(assocs)
    end)
  end
  
  defp avg_associations_per_memory(associations) do
    if map_size(associations) > 0 do
      count_total_associations(associations) / map_size(associations)
    else
      0.0
    end
  end
  
  defp consolidate_memory(memory_system) do
    # Decay all activations
    updated_activations = Enum.reduce(memory_system.activation_values, %{}, fn {id, activation}, acc ->
      # Apply heavier decay during consolidation
      decayed = Activation.decay(activation, nil, 0.1)
      Map.put(acc, id, decayed)
    end)
    
    # Strengthen associations for frequently co-activated memories
    # In a real implementation, this would analyze activation patterns
    # and strengthen meaningful associations
    
    # For this example, we'll just return the system with decayed activations
    %{memory_system | activation_values: updated_activations}
  end
  
  defp calculate_initial_activations(memory_system, query) do
    # Calculate activation for each memory based on query match
    Enum.reduce(memory_system.memories, %{}, fn {id, memory}, acc ->
      # Calculate match between query and memory
      match_score = calculate_query_match(query, memory)
      
      # Only include memories with non-zero match
      if match_score > 0 do
        Map.put(acc, id, match_score)
      else
        acc
      end
    end)
  end
  
  defp calculate_query_match(query, memory) do
    # In a real implementation, this would use sophisticated matching
    # based on the query type (keyword, example memory, etc.)
    
    # For this example, we'll use a simple approach
    cond do
      is_map(query) && is_map(memory) ->
        # Calculate match based on shared key-values
        matches = Enum.count(query, fn {k, v} ->
          Map.get(memory, k) == v
        end)
        
        if map_size(query) > 0 do
          matches / map_size(query)
        else
          0.0
        end
        
      is_binary(query) && is_map(memory) ->
        # Check if any string value in memory contains the query
        string_values = Enum.filter(memory, fn {_k, v} -> is_binary(v) end)
        
        matches = Enum.any?(string_values, fn {_k, v} ->
          String.contains?(String.downcase(v), String.downcase(query))
        end)
        
        if matches, do: 0.8, else: 0.0
        
      is_atom(query) && is_map(memory) ->
        # Check if memory has a matching type or category
        if Map.get(memory, :type) == query or
           Map.get(memory, :category) == query do
          1.0
        else
          0.0
        end
        
      true ->
        # Default case - no match
        0.0
    end
  end
  
  defp spread_activation(associations, initial_activations, spread_factor, max_depth) do
    # Initialize with initial activations
    all_activations = initial_activations
    
    # Perform spreading activation for specified depth
    spread(associations, initial_activations, all_activations, spread_factor, max_depth, 0)
  end
  
  defp spread(_associations, _current_wave, final_activations, _factor, max_depth, depth) 
      when depth >= max_depth do
    # Reached maximum depth, return final activations
    final_activations
  end
  
  defp spread(associations, current_wave, accumulated_activations, factor, max_depth, depth) do
    # Calculate next wave of spreading activation
    next_wave = Enum.reduce(current_wave, %{}, fn {id, activation}, acc ->
      # Get associations for this memory
      assocs = Map.get(associations, id, [])
      
      # Spread activation to associated memories
      Enum.reduce(assocs, acc, fn {target_id, strength}, inner_acc ->
        # Calculate spreading value
        spread_value = activation * strength * factor
        
        # Add to accumulated value for this target
        Map.update(inner_acc, target_id, spread_value, &(max(&1, spread_value)))
      end)
    end)
    
    if map_size(next_wave) == 0 do
      # No more spreading, return accumulated activations
      accumulated_activations
    else
      # Combine with accumulated activations
      combined = Map.merge(accumulated_activations, next_wave, fn _k, v1, v2 ->
        # Take the higher activation value
        max(v1, v2)
      end)
      
      # Continue spreading with the next wave
      spread(associations, next_wave, combined, factor * 0.7, max_depth, depth + 1)
    end
  end
  
  defp update_activations_after_retrieval(activations, retrieved_ids) do
    # Boost activation for retrieved memories
    Enum.reduce(retrieved_ids, activations, fn id, acc ->
      current = Map.get(acc, id)
      
      if current do
        # Boost activation for retrieved memory
        boosted = Activation.boost(current, 0.5, :retrieval)
        Map.put(acc, id, boosted)
      else
        acc
      end
    end)
  end
end