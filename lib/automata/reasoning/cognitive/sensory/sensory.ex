defmodule Automata.Sensory do
  @moduledoc """
    The World-Agent Division
    The Sensory System marks the single entry point into an agent from the
    World. All sensory input from the world must pass through the Sensory System
    before it can be processed by the rest of the agent's mind.

    The primary job of the Sensory System is to act as the enforcer of sensory
    honesty. As such, it processes each DataRecord so that it appears as it
    would from the agents point of view. Sometimes that means removing it
    completely – for example, culling VisualDataRecords outside of the
    perceptual field – or otherwise transforming it into the appropriate
    reference frame.

    Because the Sensory System offers a single entry point, it allows us to
    provide more or less uniform treatment to the many types of DataRecords that
    an agent may be called upon to process.

    Types of sensory data:
    Network:
      API calls to third parties
      API calls from third parties (WebHooks)
      Data Streams (WebSockets)
    Local Sys:
      Local Events
      Local Memory Stores RAM
      Local Database ROM

    The Sensory System is a filter through which all world events (represented
    by DataRecords) must pass. Unlike its physical equivalents, where any data
    that passes through is fair game, in Automata the Sensory System plays an
    active role in keeping the agents virtual sensation honest. In a simulated
    world, there is potentially much more accessible information than the agent,
    limited by its sensory apparatus, should be able to sense.
  """
  defmacro __using__(_opts) do
  end
end
