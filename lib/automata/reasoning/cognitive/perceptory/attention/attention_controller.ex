defmodule Automata.Perceptory.AttentionController do
  @moduledoc """
  Controls the distribution of perceptual resources based on attention priorities.
  
  The attention controller manages focus within the perceptory system, directing
  resources to the most relevant stimuli based on current goals, salience, and
  context. This enables more efficient processing by focusing on important
  information while filtering out irrelevant details.
  
  Key capabilities:
  - Priority-based perception scheduling
  - Focus control for resource optimization
  - Reactive attention shifting based on salience
  - Sustained attention for ongoing monitoring
  - Context-sensitive resource allocation
  - Goal-directed attention control
  """
  
  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    focus_points: list(map()),
    focus_history: list(map()),
    attention_threshold: float(),
    max_focus_points: pos_integer(),
    context: map(),
    current_goal: any(),
    metrics: map()
  }
  
  defstruct [
    id: nil,
    name: "Attention Controller",
    focus_points: [],
    focus_history: [],
    attention_threshold: 0.3,
    max_focus_points: 5,
    context: %{},
    current_goal: nil,
    metrics: %{
      focus_shifts: 0,
      avg_focus_duration: 0,
      distraction_count: 0
    }
  ]
  
  @doc """
  Creates a new attention controller with the given configuration.
  """
  def new(attrs \\ %{}) do
    id = Map.get(attrs, :id, generate_id())
    
    %__MODULE__{
      id: id,
      name: Map.get(attrs, :name, "Attention #{id}"),
      attention_threshold: Map.get(attrs, :attention_threshold, 0.3),
      max_focus_points: Map.get(attrs, :max_focus_points, 5),
      current_goal: Map.get(attrs, :current_goal, nil)
    }
  end
  
  @doc """
  Updates the attention state based on new perceptual input and current context.
  
  Returns a tuple of {focus_points, updated_controller} where focus_points is a
  list of areas that currently have attention.
  """
  def update(controller, perceptual_input, context \\ %{}) do
    now = :os.system_time(:millisecond)
    
    # Merge new context with existing context
    updated_context = Map.merge(controller.context, context)
    
    # Calculate salience for all potential focus points
    salience_map = calculate_salience(perceptual_input, updated_context, controller.current_goal)
    
    # Update existing focus points with new information
    {updated_existing, dropped} = update_existing_focus(controller.focus_points, salience_map, now)
    
    # Find new focus points based on salience
    available_slots = controller.max_focus_points - length(updated_existing)
    new_focus = select_new_focus_points(
      salience_map, 
      updated_existing,
      available_slots,
      controller.attention_threshold,
      now
    )
    
    # Combine updated existing and new focus points
    all_focus = updated_existing ++ new_focus
    
    # Update focus history
    new_history_entries = 
      for focus <- dropped do
        Map.put(focus, :end_time, now)
      end
      
    updated_history = (new_history_entries ++ controller.focus_history)
                      |> Enum.take(20)  # Keep only 20 most recent entries
    
    # Update metrics
    updated_metrics = update_metrics(
      controller.metrics,
      length(new_focus),
      length(dropped),
      updated_history
    )
    
    updated_controller = %{controller |
      focus_points: all_focus,
      focus_history: updated_history,
      context: updated_context,
      metrics: updated_metrics
    }
    
    {all_focus, updated_controller}
  end
  
  @doc """
  Sets the current goal to direct attention.
  """
  def set_goal(controller, goal) do
    %{controller | current_goal: goal}
  end
  
  @doc """
  Explicitly directs attention to a specific focus point,
  regardless of its salience.
  """
  def direct_attention(controller, focus) do
    now = :os.system_time(:millisecond)
    
    # Create a new focus point with high priority
    new_focus = Map.merge(%{
      id: generate_id(),
      type: :directed,
      priority: 1.0,
      start_time: now,
      last_updated: now,
      duration: 0
    }, focus)
    
    # Add to focus points, ensuring we don't exceed max
    updated_focus = [new_focus | controller.focus_points]
                   |> Enum.sort_by(fn f -> f.priority end, :desc)
                   |> Enum.take(controller.max_focus_points)
    
    %{controller | 
      focus_points: updated_focus,
      metrics: Map.update(controller.metrics, :focus_shifts, 1, &(&1 + 1))
    }
  end
  
  @doc """
  Gets the current distribution of attentional resources.
  """
  def get_attention_distribution(controller) do
    total_priority = Enum.reduce(controller.focus_points, 0.0, fn f, acc -> 
      acc + f.priority
    end)
    
    if total_priority > 0.0 do
      Enum.map(controller.focus_points, fn focus ->
        {focus.id, focus.priority / total_priority}
      end)
    else
      []
    end
  end
  
  @doc """
  Checks if a specific item has attention currently.
  """
  def has_attention?(controller, item_id) do
    Enum.any?(controller.focus_points, fn focus ->
      focus.id == item_id
    end)
  end
  
  # Private helpers
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp calculate_salience(perceptual_input, context, goal) do
    # In a real implementation, this would analyze perceptual input in detail
    # For now, we'll simulate it with a simplified approach
    
    # Extract potential focus points from perceptual input
    potential_focus = 
      if is_map(perceptual_input) and Map.has_key?(perceptual_input, :percepts) do
        Map.get(perceptual_input, :percepts, [])
      else
        []
      end
    
    # Calculate salience for each potential focus point
    Enum.map(potential_focus, fn percept ->
      base_salience = Map.get(percept, :salience, 0.5)
      
      # Adjust salience based on context
      context_factor = context_relevance(percept, context)
      
      # Adjust salience based on goal relevance
      goal_factor = goal_relevance(percept, goal)
      
      # Novelty factor
      novelty = Map.get(percept, :novelty, 0.5)
      
      # Emotional significance
      emotion = Map.get(percept, :emotional_value, 0.0)
      
      # Calculate final salience
      salience = base_salience * 
                 (1.0 + context_factor) * 
                 (1.0 + goal_factor) *
                 (1.0 + novelty * 0.5) *
                 (1.0 + abs(emotion) * 0.5)
                 
      # Normalize to 0.0-1.0 range
      normalized_salience = min(1.0, salience / 4.0)
      
      Map.put(percept, :calculated_salience, normalized_salience)
    end)
    |> Enum.sort_by(fn p -> Map.get(p, :calculated_salience, 0.0) end, :desc)
  end
  
  defp context_relevance(percept, context) do
    # Simple context relevance based on matching keys
    # In a real implementation, this would be much more sophisticated
    percept_keys = Map.keys(percept)
    context_keys = Map.keys(context)
    
    common_keys = MapSet.intersection(
      MapSet.new(percept_keys),
      MapSet.new(context_keys)
    )
    
    # Return a factor based on overlap
    MapSet.size(common_keys) / max(1, length(percept_keys)) * 0.5
  end
  
  defp goal_relevance(percept, goal) do
    if goal == nil do
      0.0  # No goal adjustment if no goal is set
    else
      # Simple goal relevance calculation
      # In a real implementation, this would depend on the goal type
      cond do
        is_map(goal) and is_map(percept) ->
          # Count matching key-value pairs
          matches = Enum.count(goal, fn {k, v} -> Map.get(percept, k) == v end)
          matches / max(1, map_size(goal))
          
        is_atom(goal) and is_map(percept) ->
          # Check if percept has a type that matches the goal
          if Map.get(percept, :type) == goal, do: 1.0, else: 0.0
          
        true ->
          0.0
      end
    end
  end
  
  defp update_existing_focus(focus_points, salience_map, now) do
    # Update each existing focus point and determine if it should be kept
    Enum.reduce(focus_points, {[], []}, fn focus, {kept, dropped} ->
      # Find matching item in salience map
      matching = Enum.find(salience_map, fn item ->
        Map.get(item, :id) == focus.id
      end)
      
      cond do
        # Explicitly directed attention always stays
        focus.type == :directed ->
          new_focus = %{focus | 
            last_updated: now,
            duration: now - focus.start_time
          }
          {[new_focus | kept], dropped}
          
        # If we have updated salience, adjust the focus point
        matching != nil ->
          new_salience = Map.get(matching, :calculated_salience, 0.0)
          
          # Adjust priority based on new salience and existing momentum
          momentum = min(1.0, (now - focus.start_time) / 10000.0) * 0.3
          new_priority = new_salience + momentum
          
          new_focus = %{focus | 
            priority: new_priority,
            last_updated: now,
            duration: now - focus.start_time,
            data: Map.get(matching, :data, focus.data)
          }
          
          {[new_focus | kept], dropped}
          
        # No matching update, check if focus should be maintained
        true ->
          # Time decay for attention
          time_since_update = now - focus.last_updated
          
          if time_since_update > 5000 do
            # Too long without updates, drop focus
            {kept, [focus | dropped]}
          else
            # Maintain focus with reduced priority
            decay_factor = max(0.5, 1.0 - (time_since_update / 10000.0))
            new_priority = focus.priority * decay_factor
            
            new_focus = %{focus | 
              priority: new_priority,
              duration: now - focus.start_time
            }
            
            {[new_focus | kept], dropped}
          end
      end
    end)
  end
  
  defp select_new_focus_points(salience_map, existing_focus, available_slots, threshold, now) do
    # Skip items that are already in focus
    existing_ids = MapSet.new(Enum.map(existing_focus, fn f -> f.id end))
    
    new_candidates = Enum.filter(salience_map, fn item ->
      item_id = Map.get(item, :id)
      !MapSet.member?(existing_ids, item_id) &&
      Map.get(item, :calculated_salience, 0.0) >= threshold
    end)
    
    # Take top N based on available slots
    Enum.take(new_candidates, available_slots)
    |> Enum.map(fn item ->
      %{
        id: Map.get(item, :id, generate_id()),
        type: :automatic,
        priority: Map.get(item, :calculated_salience, 0.5),
        data: item,
        start_time: now,
        last_updated: now,
        duration: 0
      }
    end)
  end
  
  defp update_metrics(metrics, new_focus_count, dropped_focus_count, focus_history) do
    # Calculate average focus duration
    durations = Enum.map(focus_history, fn focus ->
      (Map.get(focus, :end_time, 0) - Map.get(focus, :start_time, 0))
    end)
    
    avg_duration = if length(durations) > 0 do
      Enum.sum(durations) / length(durations)
    else
      metrics.avg_focus_duration
    end
    
    # Count "distractions" - focus shifts not aligned with goals
    distraction_count = metrics.distraction_count + 
                        max(0, new_focus_count - 1)
    
    %{metrics |
      focus_shifts: metrics.focus_shifts + new_focus_count,
      avg_focus_duration: avg_duration,
      distraction_count: distraction_count
    }
  end
end