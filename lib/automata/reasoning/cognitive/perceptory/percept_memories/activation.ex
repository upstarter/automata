# To an agent, an object is the set of perceptions it imparts.
defmodule Activation do
  defstruct percept: nil,
            confidence: nil,
            # e.g. data: MovingAverageRecord
            data: nil
end
