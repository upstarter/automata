defmodule Automata.Perceptory do
  @moduledoc """
    Classification hierarchy (Perception System) Once the stimulus from the world
    has been “sensed,” it can then be “perceived.” The distinction between sensing
    and perceiving is important. An agent, for example, may “sense” an acoustic
    event, but it is up to the perception system to recognize it as an instance of a
    specific type of acoustic event that has some meaning to the agent. A segment of
    agents may interpret an UtteranceDataRecord as just another noise, but one should
    classify the utterance as the word "hello”. Similarly with multicast, unicast,
    broadcast events. Thus, it is within the Perception System that each agent assigns a
    unique “meaning” to events in the world.

    Once the stimulus from the world has been “sensed” it can then be “perceived.”
    The distinction between sensing and perceiving is important. A agent may “sense”
    an acoustic event, but it is up to the Perception System to recognize and
    process the event as something that has meaning to the agent. Thus, it is within
    the Perception System that “meaning” is assigned to events in the world.
  """
  defmacro __using__(_opts) do
  end
end
