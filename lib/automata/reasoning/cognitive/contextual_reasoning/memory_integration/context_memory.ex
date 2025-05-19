defmodule Automata.Reasoning.Cognitive.ContextualReasoning.MemoryIntegration.ContextMemory do
  @moduledoc """
  Integrates context-aware memory mechanisms with the contextual reasoning system.
  
  The ContextMemory module provides:
  - Context-sensitive memory storage and retrieval
  - Association of memories with specific contexts
  - Context-based memory activation and decay
  - Memory consolidation across contexts
  - Integration with the existing perception memory system
  """
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.Context
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.ContextManager
  alias Automata.Reasoning.Cognitive.Perceptory.PerceptMemories.PerceptMem
  alias Automata.Reasoning.Cognitive.Perceptory.Memory.AssociativeMemory
  
  require Logger
  
  defstruct [
    :context_manager,       # Reference to the context manager
    :context_memories,      # Map of context_id to memory sets
    :perception_memory,     # Reference to perception memory
    :global_memory,         # Shared memory accessible in all contexts
    :associative_memory,    # Reference to associative memory
    :recency_weights,       # Memory recency weights by context
    :memory_decay_rate      # Rate of memory decay over time
  ]
  
  # Memory item structure
  defmodule MemoryItem do
    @moduledoc "Represents a memory item in context memory"
    
    defstruct [
      :id,              # Unique identifier
      :content,         # Memory content
      :context_ids,     # Contexts where this memory is relevant
      :confidence,      # Confidence level (0.0 to 1.0)
      :creation_time,   # When the memory was created
      :last_accessed,   # When the memory was last accessed
      :access_count,    # Number of times the memory was accessed
      :metadata,        # Additional memory metadata
      :associations     # List of associated memory IDs
    ]
  end
  
  @doc """
  Creates a new context memory system.
  
  ## Parameters
  - context_manager: Reference to the context manager
  - perception_memory: Reference to the perception memory system
  - associative_memory: Reference to the associative memory system
  
  ## Returns
  A new ContextMemory struct
  """
  def new(context_manager, perception_memory, associative_memory) do
    %__MODULE__{
      context_manager: context_manager,
      context_memories: %{},
      perception_memory: perception_memory,
      global_memory: MapSet.new(),
      associative_memory: associative_memory,
      recency_weights: %{},
      memory_decay_rate: 0.05  # Default decay rate
    }
  end
  
  @doc """
  Stores a memory item in the appropriate contexts.
  
  ## Parameters
  - memory: The context memory system
  - content: Memory content
  - context_ids: List of context IDs to associate with the memory
  - confidence: Confidence level (default: 1.0)
  - metadata: Additional memory metadata
  
  ## Returns
  Updated memory system with the new memory item
  """
  def store(memory, content, context_ids \\ [], confidence \\ 1.0, metadata \\ %{}) do
    # Create a new memory item
    memory_id = generate_memory_id()
    memory_item = %MemoryItem{
      id: memory_id,
      content: content,
      context_ids: context_ids,
      confidence: confidence,
      creation_time: DateTime.utc_now(),
      last_accessed: DateTime.utc_now(),
      access_count: 0,
      metadata: metadata,
      associations: []
    }
    
    # Store in global memory if no specific contexts
    updated_memory = if Enum.empty?(context_ids) do
      %{memory | global_memory: MapSet.put(memory.global_memory, memory_item)}
    else
      memory
    end
    
    # Store in context-specific memories
    Enum.reduce(context_ids, updated_memory, fn context_id, acc ->
      context_memory = Map.get(acc.context_memories, context_id, MapSet.new())
      updated_context_memory = MapSet.put(context_memory, memory_item)
      
      %{acc | context_memories: Map.put(acc.context_memories, context_id, updated_context_memory)}
    end)
  end
  
  @doc """
  Retrieves memories relevant to the active contexts.
  
  ## Parameters
  - memory: The context memory system
  - query: Query pattern to filter memories (optional)
  - limit: Maximum number of memories to return (default: 10)
  
  ## Returns
  List of memory items
  """
  def retrieve(memory, query \\ nil, limit \\ 10) do
    # Get active contexts
    active_contexts = ContextManager.get_active_contexts(memory.context_manager)
    active_context_ids = Enum.map(active_contexts, fn context -> context.id end)
    
    # Collect memories from active contexts
    context_specific_memories = Enum.flat_map(active_context_ids, fn context_id ->
      Map.get(memory.context_memories, context_id, MapSet.new())
      |> MapSet.to_list()
    end)
    
    # Add global memories
    all_relevant_memories = context_specific_memories ++ MapSet.to_list(memory.global_memory)
    
    # Filter based on query if provided
    filtered_memories = if query do
      Enum.filter(all_relevant_memories, fn item ->
        matches_query?(item, query)
      end)
    else
      all_relevant_memories
    end
    
    # Sort by relevance and limit
    sorted_memories = sort_by_relevance(filtered_memories, active_context_ids, memory.recency_weights)
    |> Enum.take(limit)
    
    # Update access information for retrieved memories
    {retrieved_memories, updated_memory} = update_access_info(sorted_memories, memory)
    
    {retrieved_memories, updated_memory}
  end
  
  @doc """
  Associates a memory item with a context.
  
  ## Parameters
  - memory: The context memory system
  - memory_id: ID of the memory to associate
  - context_id: ID of the context to associate with
  
  ## Returns
  Updated memory system
  """
  def associate_with_context(memory, memory_id, context_id) do
    # Find the memory item
    {memory_item, source} = find_memory_item(memory, memory_id)
    
    case {memory_item, source} do
      {nil, _} ->
        # Memory not found
        {:error, :memory_not_found, memory}
        
      {item, :global} ->
        # Memory found in global memory
        updated_item = %{item | context_ids: [context_id | item.context_ids] |> Enum.uniq()}
        
        # Update global memory
        updated_global = MapSet.delete(memory.global_memory, item)
        |> MapSet.put(updated_item)
        
        # Add to context memory
        context_memory = Map.get(memory.context_memories, context_id, MapSet.new())
        updated_context_memory = MapSet.put(context_memory, updated_item)
        
        {:ok, %{memory | 
          global_memory: updated_global,
          context_memories: Map.put(memory.context_memories, context_id, updated_context_memory)
        }}
        
      {item, context_id} ->
        # Memory already associated with this context
        {:ok, memory}
        
      {item, other_context_id} ->
        # Memory found in another context
        updated_item = %{item | context_ids: [context_id | item.context_ids] |> Enum.uniq()}
        
        # Update original context memory
        original_context_memory = Map.get(memory.context_memories, other_context_id)
        updated_original = MapSet.delete(original_context_memory, item)
        |> MapSet.put(updated_item)
        
        # Add to new context memory
        target_context_memory = Map.get(memory.context_memories, context_id, MapSet.new())
        updated_target = MapSet.put(target_context_memory, updated_item)
        
        # Update memory system
        {:ok, %{memory |
          context_memories: memory.context_memories
          |> Map.put(other_context_id, updated_original)
          |> Map.put(context_id, updated_target)
        }}
    end
  end
  
  @doc """
  Creates associations between memory items.
  
  ## Parameters
  - memory: The context memory system
  - memory_id: ID of the memory to associate from
  - associated_id: ID of the memory to associate to
  - bidirectional: Whether the association is bidirectional (default: true)
  
  ## Returns
  Updated memory system
  """
  def associate_memories(memory, memory_id, associated_id, bidirectional \\ true) do
    # Find both memory items
    {memory_item, source1} = find_memory_item(memory, memory_id)
    {associated_item, source2} = find_memory_item(memory, associated_id)
    
    case {memory_item, associated_item} do
      {nil, _} ->
        {:error, :memory_not_found, memory}
        
      {_, nil} ->
        {:error, :associated_memory_not_found, memory}
        
      {item1, item2} ->
        # Update first memory
        updated_item1 = %{item1 | 
          associations: [associated_id | item1.associations] |> Enum.uniq()
        }
        
        # Update second memory if bidirectional
        updated_item2 = if bidirectional do
          %{item2 | 
            associations: [memory_id | item2.associations] |> Enum.uniq()
          }
        else
          item2
        end
        
        # Update memory system
        updated_memory = update_memory_item(memory, updated_item1, source1)
        updated_memory = update_memory_item(updated_memory, updated_item2, source2)
        
        # Also create association in the associative memory system if available
        if memory.associative_memory do
          # Convert to format expected by associative memory
          AssociativeMemory.create_association(
            memory.associative_memory,
            {memory_id, item1.content},
            {associated_id, item2.content},
            bidirectional
          )
        end
        
        {:ok, updated_memory}
    end
  end
  
  @doc """
  Consolidates memories across contexts based on similarity.
  
  ## Parameters
  - memory: The context memory system
  - similarity_threshold: Threshold for considering memories similar (default: 0.8)
  
  ## Returns
  Updated memory system with consolidated memories
  """
  def consolidate_memories(memory, similarity_threshold \\ 0.8) do
    # Collect all memories
    all_memories = collect_all_memories(memory)
    
    # Group similar memories
    # This is a simplified implementation - a real system would use more
    # sophisticated similarity measures
    groups = group_similar_memories(all_memories, similarity_threshold)
    
    # Merge each group
    Enum.reduce(groups, memory, fn group, acc ->
      if length(group) > 1 do
        merge_memory_group(acc, group)
      else
        acc
      end
    end)
  end
  
  @doc """
  Applies decay to memories based on time and context relevance.
  
  ## Parameters
  - memory: The context memory system
  - current_time: Current time for decay calculation (default: now)
  
  ## Returns
  Updated memory system with decayed memory confidences
  """
  def apply_decay(memory, current_time \\ DateTime.utc_now()) do
    # Apply decay to global memories
    updated_global = MapSet.new(
      Enum.map(memory.global_memory, fn item ->
        decay_memory_item(item, current_time, memory.memory_decay_rate)
      end)
    )
    
    # Apply decay to context memories
    updated_contexts = Enum.map(memory.context_memories, fn {context_id, items} ->
      # Get context activation level
      context = ContextManager.get_context(memory.context_manager, context_id)
      context_activation = if context, do: context.activation, else: 0.0
      
      # Apply context-modulated decay
      updated_items = MapSet.new(
        Enum.map(items, fn item ->
          # Decay rate is reduced for highly active contexts
          effective_decay_rate = memory.memory_decay_rate * (1.0 - context_activation * 0.5)
          decay_memory_item(item, current_time, effective_decay_rate)
        end)
      )
      
      {context_id, updated_items}
    end) |> Map.new()
    
    # Update memory system
    %{memory | 
      global_memory: updated_global,
      context_memories: updated_contexts
    }
  end
  
  @doc """
  Integrates perception memories into context memory.
  
  ## Parameters
  - memory: The context memory system
  - percept_memories: Perception memories to integrate
  - context_id: Context to associate with (optional)
  
  ## Returns
  Updated memory system with integrated perception memories
  """
  def integrate_perception_memories(memory, percept_memories, context_id \\ nil) do
    # If context_id is nil, determine based on current context
    context_ids = if context_id do
      [context_id]
    else
      # Get active contexts
      active_contexts = ContextManager.get_active_contexts(memory.context_manager)
      Enum.map(active_contexts, fn context -> context.id end)
    end
    
    # If no active contexts, use global memory
    context_ids = if Enum.empty?(context_ids), do: [], else: context_ids
    
    # Convert perception memories to context memories
    Enum.reduce(percept_memories, memory, fn percept_mem, acc ->
      # Convert percept memory to memory item content
      content = %{
        type: :perception,
        percept_type: percept_mem.type,
        value: percept_mem.value,
        attributes: percept_mem.attributes
      }
      
      # Store in context memory
      store(acc, content, context_ids, percept_mem.activation)
    end)
  end
  
  # Private helper functions
  
  defp generate_memory_id do
    # Generate a unique ID
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
  
  defp matches_query?(memory_item, nil), do: true
  
  defp matches_query?(memory_item, query) when is_function(query) do
    # Apply function-based query
    query.(memory_item)
  end
  
  defp matches_query?(memory_item, query) when is_map(query) do
    # Match based on map fields
    Enum.all?(query, fn {key, value} ->
      item_value = get_in(memory_item, [Access.key(key)])
      item_value == value
    end)
  end
  
  defp sort_by_relevance(memories, active_context_ids, recency_weights) do
    # Calculate relevance scores
    memories_with_scores = Enum.map(memories, fn memory ->
      # Context relevance
      context_score = calculate_context_relevance(memory, active_context_ids)
      
      # Recency score
      recency_score = calculate_recency_score(memory, recency_weights)
      
      # Confidence score
      confidence_score = memory.confidence
      
      # Combined score
      total_score = context_score * 0.4 + recency_score * 0.3 + confidence_score * 0.3
      
      {memory, total_score}
    end)
    
    # Sort by score
    Enum.sort_by(memories_with_scores, fn {_, score} -> score end, :desc)
    |> Enum.map(fn {memory, _} -> memory end)
  end
  
  defp calculate_context_relevance(memory, active_context_ids) do
    # Calculate how relevant the memory is to active contexts
    case {Enum.empty?(memory.context_ids), Enum.empty?(active_context_ids)} do
      {true, _} ->
        # Global memory has moderate relevance
        0.5
        
      {_, true} ->
        # No active contexts, all context memories equally relevant
        0.5
        
      _ ->
        # Calculate overlap between memory contexts and active contexts
        overlap = MapSet.intersection(
          MapSet.new(memory.context_ids),
          MapSet.new(active_context_ids)
        ) |> MapSet.size()
        
        overlap / Enum.count(active_context_ids)
    end
  end
  
  defp calculate_recency_score(memory, recency_weights) do
    # Calculate recency score based on last access time
    # This is a simplified implementation
    now = DateTime.utc_now()
    diff = DateTime.diff(now, memory.last_accessed)
    
    # Exponential decay based on time difference
    :math.exp(-diff / 86400)  # 86400 seconds in a day
  end
  
  defp update_access_info(memories, memory_system) do
    now = DateTime.utc_now()
    
    # Update each memory's access information
    Enum.reduce(memories, {[], memory_system}, fn memory, {acc_memories, acc_system} ->
      updated_memory = %{memory | 
        last_accessed: now,
        access_count: memory.access_count + 1
      }
      
      # Update the memory in the system
      updated_system = update_memory_item(
        acc_system, 
        updated_memory, 
        if Enum.empty?(memory.context_ids), do: :global, else: hd(memory.context_ids)
      )
      
      {[updated_memory | acc_memories], updated_system}
    end)
  end
  
  defp find_memory_item(memory, memory_id) do
    # Check global memory first
    global_match = Enum.find(memory.global_memory, fn item -> item.id == memory_id end)
    
    if global_match do
      {global_match, :global}
    else
      # Check context memories
      Enum.find_value(memory.context_memories, {nil, nil}, fn {context_id, items} ->
        match = Enum.find(items, fn item -> item.id == memory_id end)
        if match, do: {match, context_id}, else: nil
      end)
    end
  end
  
  defp update_memory_item(memory, item, :global) do
    # Update in global memory
    updated_global = MapSet.delete(memory.global_memory, find_exact_item(memory.global_memory, item.id))
    |> MapSet.put(item)
    
    %{memory | global_memory: updated_global}
  end
  
  defp update_memory_item(memory, item, context_id) do
    # Update in context memory
    context_memories = Map.get(memory.context_memories, context_id)
    if context_memories do
      updated_context_memories = MapSet.delete(context_memories, find_exact_item(context_memories, item.id))
      |> MapSet.put(item)
      
      %{memory | context_memories: Map.put(memory.context_memories, context_id, updated_context_memories)}
    else
      memory
    end
  end
  
  defp find_exact_item(memory_set, id) do
    Enum.find(memory_set, fn item -> item.id == id end)
  end
  
  defp collect_all_memories(memory) do
    # Get global memories
    global_memories = MapSet.to_list(memory.global_memory)
    
    # Get context memories
    context_memories = Enum.flat_map(memory.context_memories, fn {_, items} ->
      MapSet.to_list(items)
    end)
    
    global_memories ++ context_memories
  end
  
  defp group_similar_memories(memories, threshold) do
    # Group memories by similarity
    # This is a simplified implementation using content equality
    Enum.reduce(memories, [], fn memory, groups ->
      # Find a group that contains a similar memory
      matching_group = Enum.find(groups, fn group ->
        Enum.any?(group, fn other ->
          calculate_similarity(memory, other) >= threshold
        end)
      end)
      
      if matching_group do
        # Add to existing group
        groups |> List.delete(matching_group) |> List.insert_at(0, [memory | matching_group])
      else
        # Create new group
        [[memory] | groups]
      end
    end)
  end
  
  defp calculate_similarity(memory1, memory2) do
    # Calculate similarity between memories
    # This is a simplified implementation
    case {memory1.content, memory2.content} do
      {c1, c2} when c1 == c2 -> 1.0
      _ -> 0.0
    end
  end
  
  defp merge_memory_group(memory, group) do
    # Merge a group of similar memories
    # Take the highest confidence one as the base
    sorted_group = Enum.sort_by(group, & &1.confidence, :desc)
    base_memory = hd(sorted_group)
    
    # Collect all contexts and associations
    merged_context_ids = Enum.flat_map(group, & &1.context_ids) |> Enum.uniq()
    merged_associations = Enum.flat_map(group, & &1.associations) |> Enum.uniq()
    
    # Create merged memory
    merged_memory = %{base_memory |
      context_ids: merged_context_ids,
      associations: merged_associations,
      access_count: Enum.sum(Enum.map(group, & &1.access_count)),
      # Increase confidence if multiple memories agree
      confidence: min(1.0, base_memory.confidence * (1.0 + 0.1 * (length(group) - 1)))
    }
    
    # Remove old memories and add merged one
    updated_memory = Enum.reduce(group, memory, fn item, acc ->
      remove_memory_item(acc, item.id)
    end)
    
    # Add merged memory
    if Enum.empty?(merged_context_ids) do
      # Add to global memory
      %{updated_memory | global_memory: MapSet.put(updated_memory.global_memory, merged_memory)}
    else
      # Add to all relevant contexts
      Enum.reduce(merged_context_ids, updated_memory, fn context_id, acc ->
        context_memory = Map.get(acc.context_memories, context_id, MapSet.new())
        updated_context_memory = MapSet.put(context_memory, merged_memory)
        %{acc | context_memories: Map.put(acc.context_memories, context_id, updated_context_memory)}
      end)
    end
  end
  
  defp remove_memory_item(memory, memory_id) do
    # Remove from global memory
    updated_global = MapSet.new(Enum.reject(memory.global_memory, & &1.id == memory_id))
    
    # Remove from context memories
    updated_contexts = Enum.map(memory.context_memories, fn {context_id, items} ->
      updated_items = MapSet.new(Enum.reject(items, & &1.id == memory_id))
      {context_id, updated_items}
    end) |> Map.new()
    
    %{memory | 
      global_memory: updated_global,
      context_memories: updated_contexts
    }
  end
  
  defp decay_memory_item(item, current_time, decay_rate) do
    # Calculate time since last access
    seconds_since_access = DateTime.diff(current_time, item.last_accessed)
    
    # Apply decay based on time
    # Decay formula: confidence * exp(-decay_rate * time_factor)
    time_factor = seconds_since_access / 86400  # Convert to days
    new_confidence = item.confidence * :math.exp(-decay_rate * time_factor)
    
    # Update item
    %{item | confidence: new_confidence}
  end
end