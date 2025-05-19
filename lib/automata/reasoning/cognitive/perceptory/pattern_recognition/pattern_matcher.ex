defmodule Automata.Perceptory.PatternMatcher do
  @moduledoc """
  A sophisticated pattern matching system for the Perceptory.
  
  The PatternMatcher processes sensory input to detect known patterns,
  extract relevant features, and provide meaningful interpretations.
  This module serves as the foundation for advanced pattern recognition
  within the perception system.
  
  Key capabilities:
  - Template-based pattern matching
  - Statistical pattern recognition
  - Feature extraction from sensory data
  - Context-sensitive interpretation
  - Anomaly detection for unexpected inputs
  - Confidence scoring for matches
  - Multi-modal pattern matching
  
  The pattern matcher can be extended with additional pattern types,
  matching algorithms, and feature extractors to handle different
  sensory domains and recognition requirements.
  """
  
  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    patterns: list(map()),
    extractors: list(function()),
    context: map(),
    match_threshold: float(),
    recent_matches: list({String.t(), float(), map(), integer()}),
    metrics: map()
  }
  
  defstruct [
    id: nil,
    name: "Generic Pattern Matcher",
    patterns: [],
    extractors: [],
    context: %{},
    match_threshold: 0.7,
    recent_matches: [],
    metrics: %{
      total_processed: 0,
      matched: 0,
      avg_confidence: 0.0,
      execution_time: %{}
    }
  ]
  
  @doc """
  Creates a new pattern matcher with the given configuration.
  """
  def new(attrs \\ %{}) do
    id = Map.get(attrs, :id, generate_id())
    
    %__MODULE__{
      id: id,
      name: Map.get(attrs, :name, "Pattern Matcher #{id}"),
      patterns: Map.get(attrs, :patterns, []),
      extractors: Map.get(attrs, :extractors, [&default_extractor/1]),
      context: Map.get(attrs, :context, %{}),
      match_threshold: Map.get(attrs, :match_threshold, 0.7)
    }
  end
  
  @doc """
  Processes sensory input to identify patterns.
  
  Returns a tuple of {matches, updated_matcher} where matches is a list
  of {pattern_id, confidence, extracted_data} tuples for all patterns
  that matched above the threshold.
  """
  def process(matcher, input) do
    start_time = :os.system_time(:microsecond)
    
    # Extract features from input using all extractors
    features = extract_features(matcher, input)
    
    # Match extracted features against known patterns
    matches = match_patterns(matcher, features, input)
    
    # Filter matches based on threshold
    filtered_matches = Enum.filter(matches, fn {_id, confidence, _data} ->
      confidence >= matcher.match_threshold
    end)
    
    end_time = :os.system_time(:microsecond)
    execution_time = end_time - start_time
    
    # Update metrics
    updated_metrics = update_metrics(matcher.metrics, filtered_matches, execution_time)
    
    # Update recent matches list
    timestamp = :os.system_time(:millisecond)
    new_recent_matches = 
      (for {id, confidence, data} <- filtered_matches, do: {id, confidence, data, timestamp})
      ++ matcher.recent_matches
      |> Enum.take(20)  # Keep only 20 most recent matches
    
    updated_matcher = %{matcher | 
      recent_matches: new_recent_matches,
      metrics: updated_metrics
    }
    
    {filtered_matches, updated_matcher}
  end
  
  @doc """
  Adds a new pattern to the matcher.
  """
  def add_pattern(matcher, pattern) do
    # Ensure pattern has required fields
    pattern = Map.merge(%{
      id: generate_id(),
      name: "Pattern_#{System.unique_integer([:positive])}",
      features: %{},
      match_fn: &default_match_fn/2,
      weight: 1.0
    }, pattern)
    
    %{matcher | patterns: [pattern | matcher.patterns]}
  end
  
  @doc """
  Adds a feature extractor function to the matcher.
  """
  def add_extractor(matcher, extractor_fn) when is_function(extractor_fn, 1) do
    %{matcher | extractors: [extractor_fn | matcher.extractors]}
  end
  
  @doc """
  Updates the context used for pattern matching.
  """
  def update_context(matcher, context_updates) do
    updated_context = Map.merge(matcher.context, context_updates)
    %{matcher | context: updated_context}
  end
  
  @doc """
  Gets the most recent matches for a specific pattern.
  """
  def recent_matches_for_pattern(matcher, pattern_id) do
    matcher.recent_matches
    |> Enum.filter(fn {id, _conf, _data, _time} -> id == pattern_id end)
  end
  
  @doc """
  Adjusts the match threshold.
  """
  def set_threshold(matcher, threshold) when threshold >= 0.0 and threshold <= 1.0 do
    %{matcher | match_threshold: threshold}
  end
  
  # Private helpers
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp extract_features(matcher, input) do
    # Apply all feature extractors to the input
    Enum.reduce(matcher.extractors, %{}, fn extractor, acc ->
      extracted = extractor.(input)
      Map.merge(acc, extracted)
    end)
  end
  
  defp match_patterns(matcher, features, input) do
    # Match features against each pattern
    Enum.map(matcher.patterns, fn pattern ->
      # Calculate match confidence using pattern's match function
      match_fn = Map.get(pattern, :match_fn, &default_match_fn/2)
      {confidence, extracted_data} = match_fn.(pattern, {features, input, matcher.context})
      
      # Apply pattern weight to confidence
      weight = Map.get(pattern, :weight, 1.0)
      adjusted_confidence = confidence * weight
      
      {pattern.id, adjusted_confidence, extracted_data}
    end)
  end
  
  defp update_metrics(metrics, matches, execution_time) do
    # Update execution time metrics
    execution_times = Map.get(metrics, :execution_time, %{})
    updated_times = Map.update(
      execution_times,
      :recent,
      [execution_time],
      fn times -> [execution_time | times] |> Enum.take(100) end
    )
    
    # Update match metrics
    total_processed = metrics.total_processed + 1
    matched = metrics.matched + length(matches)
    
    # Calculate average confidence across all matches
    total_confidence = Enum.reduce(matches, 0.0, fn {_id, conf, _data}, acc -> acc + conf end)
    new_matches_count = length(matches)
    
    # Update average confidence
    avg_confidence =
      if total_processed == 0 do
        0.0
      else
        ((metrics.avg_confidence * metrics.matched) + 
         (if new_matches_count > 0, do: total_confidence, else: 0.0)) /
        (metrics.matched + new_matches_count)
      end
    
    %{metrics |
      total_processed: total_processed,
      matched: matched,
      avg_confidence: avg_confidence,
      execution_time: updated_times
    }
  end
  
  # Default implementations
  
  defp default_extractor(input) do
    # A simple default extractor that just returns the input as-is
    # if it's a map, or wraps it in a map otherwise
    if is_map(input) do
      input
    else
      %{value: input}
    end
  end
  
  defp default_match_fn(pattern, {features, _input, _context}) do
    # Simple pattern matching based on feature similarity
    pattern_features = Map.get(pattern, :features, %{})
    
    if map_size(pattern_features) == 0 do
      {0.0, %{}}
    else
      # Count matching features
      {matches, extracted} = Enum.reduce(pattern_features, {0, %{}}, fn {key, value}, {count, extracted} ->
        case Map.fetch(features, key) do
          {:ok, feature_value} ->
            similarity = calculate_similarity(value, feature_value)
            if similarity > 0.7 do
              {count + 1, Map.put(extracted, key, feature_value)}
            else
              {count, extracted}
            end
            
          :error ->
            {count, extracted}
        end
      end)
      
      # Calculate confidence based on proportion of matching features
      if map_size(pattern_features) > 0 do
        confidence = matches / map_size(pattern_features)
        {confidence, extracted}
      else
        {0.0, %{}}
      end
    end
  end
  
  defp calculate_similarity(value1, value2) do
    # Basic similarity calculation - can be extended for different types
    cond do
      is_number(value1) and is_number(value2) ->
        # For numbers, calculate similarity based on relative difference
        max_val = max(abs(value1), abs(value2))
        if max_val > 0 do
          1.0 - min(1.0, abs(value1 - value2) / max_val)
        else
          1.0  # Both are 0
        end
        
      is_binary(value1) and is_binary(value2) ->
        # For strings, use string distance
        string_similarity(value1, value2)
        
      is_atom(value1) and is_atom(value2) ->
        # For atoms, binary comparison
        if value1 == value2, do: 1.0, else: 0.0
        
      true ->
        # For other types, default comparison
        if value1 == value2, do: 1.0, else: 0.0
    end
  end
  
  defp string_similarity(str1, str2) do
    # Simple Levenshtein distance-based similarity
    # In a complete implementation, you would use a proper string distance algorithm
    len1 = String.length(str1)
    len2 = String.length(str2)
    
    if len1 == 0 or len2 == 0 do
      if len1 == 0 and len2 == 0, do: 1.0, else: 0.0
    else
      # Calculate basic similarity based on length difference
      # This is a very simple approximation - a real implementation would use
      # Levenshtein distance or another string similarity algorithm
      1.0 - min(1.0, abs(len1 - len2) / max(len1, len2))
    end
  end
end