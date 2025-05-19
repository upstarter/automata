defmodule Automata.Perceptory.PercepMem do
  @moduledoc """
  When a DataRecord enters the Perception System, a new PerceptMemory is
  created, and as the DataRecord is pushed through the Percept Tree, each
  percept that registers a positive match adds its data to the new
  PerceptMemory.

  PerceptMemory can be thought of as Beliefs about the world (individually and
  in aggregate - histories of memories). Percepts are organized hierarchically
  in terms of their specificity.
  
  Both the confidence and the extracted data of every percept are cached in a
  PerceptMemory object. When a DataRecord enters the Perception System, a new
  PerceptMemory is created, and as the DataRecord is pushed through the
  Percept Tree, each percept that registers a positive match adds its
  data to the new PerceptMemory. Thus, given a sensory stimulus,
  the PerceptMemory represents all the agent can know about that stimulus.
  
  PerceptMemory objects become even more useful when they incorporate a time
  dimension with the data they contain. On any one timestep, the PerceptMemory
  objects that come out of the Perception System will by necessity only
  contain information gathered in that timestep. However, as events often
  extend through time, it is possible to match PerceptMemory objects from
  previous timesteps.
  """
  
  @type t :: %__MODULE__{
    sensory_input: any(),             # The original sensory input
    matches: map(),                   # Map of percept_id => {confidence, data}
    history: list({integer(), map()}), # List of {timestamp, matches} tuples
    created_at: integer(),            # Creation timestamp in milliseconds
    updated_at: integer(),            # Last update timestamp in milliseconds
    activation: float(),              # Current activation level (0.0-1.0)
    metadata: map()                   # Additional metadata
  }
  
  defstruct [
    sensory_input: nil,
    matches: %{},
    history: [],
    created_at: 0,
    updated_at: 0,
    activation: 1.0,
    metadata: %{}
  ]
  
  @doc """
  Creates a new perception memory.
  """
  def new(sensory_input, matches, timestamp \\ nil) do
    now = timestamp || :os.system_time(:millisecond)
    
    %__MODULE__{
      sensory_input: sensory_input,
      matches: matches,
      history: [{now, matches}],
      created_at: now,
      updated_at: now
    }
  end
  
  @doc """
  Merges a new memory with an existing one.
  """
  def merge(existing_memory, new_memory) do
    # Add the new matches to the history
    history = [{new_memory.updated_at, new_memory.matches} | existing_memory.history]
    
    # Merge the matches (taking the newer ones)
    merged_matches = Map.merge(existing_memory.matches, new_memory.matches)
    
    # Set the activation to full
    %{existing_memory |
      matches: merged_matches,
      history: history,
      updated_at: new_memory.updated_at,
      activation: 1.0
    }
  end
  
  @doc """
  Returns the timestamp of the last update to this memory.
  """
  def last_updated(memory), do: memory.updated_at
  
  @doc """
  Determines if two memories match (refer to the same entity/event).
  
  The default implementation checks for:
  1. Temporal proximity - memories close in time are more likely to match
  2. Perceptual similarity - memories with similar percepts are more likely to match
  3. Spatial similarity (if location data is available)
  
  The matching algorithm can be customized or extended based on specific needs.
  """
  def match(memory1, memory2, opts \\ []) do
    # Extract options
    temporal_threshold = Keyword.get(opts, :temporal_threshold, 2000) # milliseconds
    similarity_threshold = Keyword.get(opts, :similarity_threshold, 0.7) # 0.0-1.0
    
    # Check temporal proximity
    temporal_match = abs(memory1.updated_at - memory2.updated_at) < temporal_threshold
    
    # Only proceed if temporally close
    if temporal_match do
      # Calculate similarity between the matches
      similarity = calculate_similarity(memory1.matches, memory2.matches)
      
      # Check if similarity exceeds threshold
      similarity >= similarity_threshold
    else
      false
    end
  end
  
  @doc """
  Reduces the activation level of the memory by the given decay factor.
  """
  def decay(memory, decay_factor \\ 0.05) do
    new_activation = max(0.0, memory.activation - decay_factor)
    %{memory | activation: new_activation}
  end
  
  @doc """
  Adds metadata to the memory.
  """
  def add_metadata(memory, key, value) do
    new_metadata = Map.put(memory.metadata, key, value)
    %{memory | metadata: new_metadata}
  end
  
  @doc """
  Gets a value from the memory metadata.
  """
  def get_metadata(memory, key) do
    Map.get(memory.metadata, key)
  end
  
  # Private helpers
  
  # Calculate similarity between two sets of matches
  defp calculate_similarity(matches1, matches2) do
    # Get all percept IDs
    all_percepts = Map.keys(matches1) ++ Map.keys(matches2) |> Enum.uniq()
    
    if all_percepts == [] do
      0.0 # No percepts to compare
    else
      # Count matching percepts
      num_matches = Enum.count(all_percepts, fn percept_id ->
        case {Map.get(matches1, percept_id), Map.get(matches2, percept_id)} do
          {nil, nil} -> false
          {nil, _} -> false
          {_, nil} -> false
          {{conf1, _}, {conf2, _}} -> 
            # Both confidences need to be reasonably high
            conf1 > 0.5 && conf2 > 0.5
        end
      end)
      
      # Calculate similarity ratio
      num_matches / length(all_percepts)
    end
  end
end