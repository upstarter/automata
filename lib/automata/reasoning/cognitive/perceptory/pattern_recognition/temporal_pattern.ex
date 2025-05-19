defmodule Automata.Perceptory.TemporalPattern do
  @moduledoc """
  A system for recognizing patterns that occur over time.
  
  The TemporalPattern module identifies sequences, rhythms, and trends in
  perceptual data across multiple time frames. This enables agents to detect
  complex behaviors, predict future events, and respond to changing conditions.
  
  Key capabilities:
  - Sequence detection (ordered events)
  - Frequency analysis (recurring patterns)
  - Trend identification (gradual changes)
  - Anomaly detection (unexpected deviations)
  - State transition analysis
  - Event prediction based on past sequences
  """
  
  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    sequence_patterns: list(map()),
    event_buffer: list({any(), integer()}),
    buffer_size: pos_integer(),
    time_window: pos_integer(),
    active_sequences: map(),
    identified_patterns: list({String.t(), float(), list(any()), integer()}),
    metrics: map()
  }
  
  defstruct [
    id: nil,
    name: "Temporal Pattern Detector",
    sequence_patterns: [],
    event_buffer: [],
    buffer_size: 100,
    time_window: 30_000,  # 30 seconds
    active_sequences: %{},
    identified_patterns: [],
    metrics: %{
      events_processed: 0,
      patterns_identified: 0,
      active_sequences: 0
    }
  ]
  
  @doc """
  Creates a new temporal pattern detector.
  """
  def new(attrs \\ %{}) do
    id = Map.get(attrs, :id, generate_id())
    
    %__MODULE__{
      id: id,
      name: Map.get(attrs, :name, "Temporal Pattern #{id}"),
      sequence_patterns: Map.get(attrs, :sequence_patterns, []),
      buffer_size: Map.get(attrs, :buffer_size, 100),
      time_window: Map.get(attrs, :time_window, 30_000)
    }
  end
  
  @doc """
  Processes a new event, updates active sequences, and identifies completed patterns.
  
  Returns a tuple of {identified_patterns, updated_detector} where identified_patterns
  is a list of {pattern_id, confidence, events, timestamp} tuples.
  """
  def process_event(detector, event) do
    now = :os.system_time(:millisecond)
    
    # Add event to buffer with timestamp
    updated_buffer = [{event, now} | detector.event_buffer] 
                    |> Enum.take(detector.buffer_size)
    
    # Remove events outside the time window
    recent_buffer = Enum.filter(updated_buffer, fn {_e, timestamp} -> 
      now - timestamp <= detector.time_window
    end)
    
    # Start new sequence trackers for patterns that match this event
    new_active_sequences = start_new_sequences(detector.sequence_patterns, event, now)
    
    # Update existing sequence trackers with this event
    {updated_active, completed_sequences} = update_active_sequences(
      detector.active_sequences, 
      event,
      now,
      detector.time_window
    )
    
    # Merge new and updated active sequences
    merged_active = Map.merge(updated_active, new_active_sequences)
    
    # Clean up expired sequences
    clean_active = clean_expired_sequences(merged_active, now, detector.time_window)
    
    # Update identified patterns
    new_identified = completed_sequences ++
                    detector.identified_patterns |>
                    Enum.take(50)  # Limit to 50 most recent patterns
    
    # Update metrics
    updated_metrics = %{detector.metrics |
      events_processed: detector.metrics.events_processed + 1,
      patterns_identified: detector.metrics.patterns_identified + length(completed_sequences),
      active_sequences: map_size(clean_active)
    }
    
    # Return newly identified patterns and updated detector
    identified = Enum.map(completed_sequences, fn {pattern_id, confidence, events, timestamp} ->
      {pattern_id, confidence, events, timestamp}
    end)
    
    updated_detector = %{detector |
      event_buffer: recent_buffer,
      active_sequences: clean_active,
      identified_patterns: new_identified,
      metrics: updated_metrics
    }
    
    {identified, updated_detector}
  end
  
  @doc """
  Adds a new sequence pattern to the detector.
  
  A sequence pattern consists of:
  - id: Unique identifier for the pattern
  - name: Descriptive name
  - sequence: List of event matchers
  - max_time: Maximum time window for the full sequence (in ms)
  - match_fn: Optional function to determine if an event matches a pattern element
  """
  def add_sequence_pattern(detector, pattern) do
    # Ensure pattern has required fields
    pattern = Map.merge(%{
      id: generate_id(),
      name: "Sequence_#{System.unique_integer([:positive])}",
      sequence: [],
      max_time: detector.time_window,
      match_fn: &default_match_fn/2
    }, pattern)
    
    %{detector | sequence_patterns: [pattern | detector.sequence_patterns]}
  end
  
  @doc """
  Gets all currently active (partial) sequence matches.
  """
  def get_active_sequences(detector) do
    detector.active_sequences
  end
  
  @doc """
  Gets all recently identified complete patterns.
  """
  def get_identified_patterns(detector) do
    detector.identified_patterns
  end
  
  @doc """
  Predicts the next likely events based on current active sequences.
  
  Returns a list of {event, probability} tuples.
  """
  def predict_next_events(detector) do
    # Gather all possible next events from active sequences
    next_events = Enum.flat_map(detector.active_sequences, fn {_id, sequence_state} ->
      pattern = Enum.find(detector.sequence_patterns, fn p -> 
        p.id == sequence_state.pattern_id
      end)
      
      if pattern do
        current_position = sequence_state.position
        
        if current_position < length(pattern.sequence) do
          # Get the next expected event template
          next_event_template = Enum.at(pattern.sequence, current_position)
          
          # Calculate confidence based on how far along we are and timing
          progress_factor = current_position / length(pattern.sequence)
          time_factor = min(1.0, sequence_state.max_time / sequence_state.elapsed_time)
          confidence = sequence_state.confidence * progress_factor * time_factor
          
          [{next_event_template, confidence}]
        else
          []
        end
      else
        []
      end
    end)
    
    # Group by event and combine probabilities
    next_events
    |> Enum.group_by(fn {event, _prob} -> event end)
    |> Enum.map(fn {event, occurrences} ->
      total_prob = Enum.reduce(occurrences, 0.0, fn {_e, prob}, acc -> acc + prob end)
      {event, min(1.0, total_prob)}
    end)
    |> Enum.sort_by(fn {_event, prob} -> prob end, :desc)
  end
  
  # Private helpers
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp start_new_sequences(patterns, event, now) do
    # Find patterns that start with this event
    Enum.reduce(patterns, %{}, fn pattern, acc ->
      if length(pattern.sequence) > 0 do
        first_event_template = List.first(pattern.sequence)
        match_fn = Map.get(pattern, :match_fn, &default_match_fn/2)
        
        if match_fn.(first_event_template, event) do
          # Start tracking this sequence
          sequence_id = "#{pattern.id}_#{now}_#{:erlang.unique_integer([:positive])}"
          sequence_state = %{
            pattern_id: pattern.id,
            start_time: now,
            last_event_time: now,
            position: 1,  # We've matched the first element
            events: [event],
            elapsed_time: 0,
            max_time: Map.get(pattern, :max_time, 30_000),
            confidence: 1.0
          }
          
          Map.put(acc, sequence_id, sequence_state)
        else
          acc
        end
      else
        acc
      end
    end)
  end
  
  defp update_active_sequences(active_sequences, event, now, default_time_window) do
    Enum.reduce(active_sequences, {%{}, []}, fn {seq_id, state}, {updated_active, completed} ->
      # Find the pattern for this sequence
      pattern = get_pattern_by_id(state.pattern_id)
      
      if pattern do
        # Check if this event matches the next expected element
        next_position = state.position
        
        if next_position < length(pattern.sequence) do
          next_template = Enum.at(pattern.sequence, next_position)
          match_fn = Map.get(pattern, :match_fn, &default_match_fn/2)
          
          if match_fn.(next_template, event) do
            # Event matches, update sequence state
            elapsed_time = now - state.start_time
            time_factor = min(1.0, state.max_time / max(1, elapsed_time))
            
            # Update confidence based on timing
            new_confidence = state.confidence * time_factor
            
            # Add event to sequence
            new_events = [event | state.events]
            
            # Check if sequence is now complete
            if next_position + 1 >= length(pattern.sequence) do
              # Sequence complete, add to completed list
              completed_seq = {
                state.pattern_id,
                new_confidence,
                Enum.reverse(new_events),
                now
              }
              
              {updated_active, [completed_seq | completed]}
            else
              # Update sequence state
              new_state = %{state |
                position: next_position + 1,
                last_event_time: now,
                events: new_events,
                elapsed_time: elapsed_time,
                confidence: new_confidence
              }
              
              {Map.put(updated_active, seq_id, new_state), completed}
            end
          else
            # Event doesn't match, keep sequence as is
            {Map.put(updated_active, seq_id, state), completed}
          end
        else
          # Sequence already at end, should not happen
          {updated_active, completed}
        end
      else
        # Unknown pattern, drop this sequence
        {updated_active, completed}
      end
    end)
  end
  
  defp clean_expired_sequences(active_sequences, now, time_window) do
    # Remove sequences that have been inactive for too long
    Enum.reduce(active_sequences, %{}, fn {seq_id, state}, acc ->
      if now - state.last_event_time > time_window do
        # Sequence has timed out, drop it
        acc
      else
        # Sequence is still active
        Map.put(acc, seq_id, state)
      end
    end)
  end
  
  defp get_pattern_by_id(pattern_id) do
    # In a real implementation, this would look up the pattern
    # For now, return a mock pattern
    %{
      id: pattern_id,
      sequence: [:any, :any, :any],
      max_time: 30_000,
      match_fn: &default_match_fn/2
    }
  end
  
  defp default_match_fn(template, event) do
    # Simple pattern matching
    cond do
      template == :any ->
        # Match any event
        true
        
      is_function(template) ->
        # Template is a function that evaluates the event
        template.(event)
        
      is_map(template) and is_map(event) ->
        # Match if all keys in template exist in event with matching values
        Enum.all?(template, fn {key, value} ->
          Map.get(event, key) == value
        end)
        
      true ->
        # Direct comparison
        template == event
    end
  end
end