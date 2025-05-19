# To an agent, an object is the set of perceptions it imparts.
defmodule Activation do
  defstruct percept: nil,
            confidence: nil,
            # e.g. data: MovingAverageRecord
            data: nil
end

defmodule Automata.Perceptory.Activation do
  @moduledoc """
  Activation represents the dynamic activation level of percepts and memories in
  the perception system.
  
  Activation levels control how percepts and memories influence behavior:
  - Higher activation means the percept/memory is more available for decision-making
  - Activation decays over time unless refreshed by new stimuli
  - Activation can be boosted by attention mechanisms

  This enables:
  - Working memory effects (recently activated percepts are more available)
  - Attention focusing (boosting activation of relevant percepts)
  - Emergent behavior based on activation patterns
  """
  
  @type t :: %__MODULE__{
    value: float(),         # Current activation level (0.0-1.0)
    decay_rate: float(),    # Rate at which activation decays
    boost_history: list(),  # History of activation boosts
    last_updated: integer() # Timestamp of last update
  }
  
  defstruct [
    value: 0.0,
    decay_rate: 0.05,
    boost_history: [],
    last_updated: 0
  ]
  
  @doc """
  Creates a new activation with the given initial value.
  """
  def new(initial_value \\ 0.0) do
    %__MODULE__{
      value: initial_value,
      last_updated: :os.system_time(:millisecond)
    }
  end
  
  @doc """
  Applies decay to the activation based on elapsed time.
  """
  def decay(activation, current_time \\ nil) do
    now = current_time || :os.system_time(:millisecond)
    elapsed_ms = now - activation.last_updated
    
    # Calculate decay factor based on elapsed time (exponential decay)
    # Convert milliseconds to seconds for more intuitive decay rates
    elapsed_seconds = elapsed_ms / 1000
    decay_factor = activation.decay_rate * elapsed_seconds
    
    # Calculate new activation value
    new_value = max(0.0, activation.value - decay_factor)
    
    %{activation | 
      value: new_value,
      last_updated: now
    }
  end
  
  @doc """
  Boosts the activation by the given amount.
  """
  def boost(activation, amount, reason \\ nil) do
    now = :os.system_time(:millisecond)
    
    # First apply decay to get current value
    decayed = decay(activation, now)
    
    # Then apply boost
    new_value = min(1.0, decayed.value + amount)
    
    # Record the boost
    boost_record = {now, amount, reason}
    
    %{decayed | 
      value: new_value,
      boost_history: [boost_record | decayed.boost_history] |> Enum.take(10)
    }
  end
  
  @doc """
  Returns true if the activation is above the given threshold.
  """
  def active?(activation, threshold \\ 0.1) do
    # Apply decay first to get current value
    current = decay(activation)
    current.value >= threshold
  end
  
  @doc """
  Sets the decay rate for this activation.
  """
  def set_decay_rate(activation, rate) do
    %{activation | decay_rate: rate}
  end
  
  @doc """
  Returns the current activation value after applying decay.
  """
  def current_value(activation) do
    decay(activation).value
  end
end