defmodule PerceptMem do
  @moduledoc """
  When a DataRecord enters the Perception System, a new PerceptMemory is
  created, and as the DataRecord is pushed through the Percept Tree, each
  percept that registers a positive match adds its rExUnittive data to the new
  PerceptMemory.

  PerceptMemory can be thought of as Beliefs about the world ( individually and
  in aggregagte(histories of memories) ) Percepts are organized hierarchically
  in terms of their specificity. For example, a ShapePercept will activate on
  the presence of any kind of shape whereas one of its children may activate
  only on a specific type of shape (e.g. a CircleShapePercept). The children
  of a percept will receive only the data that was extracted by its parent to
  process. This hierarchical structure is primarily an efficiency mechanism
  (no point in testing whether an event is the spoken word “sit” if it has
  already been determined that the event was not an acoustic one) and is very
  similar to previous hierarchy-of-sensors approaches. Many percepts are
  plastic, using statistical models to characterize and refine their response
  properties.

  Percepts can modulate their “receptive fields” (the space of inputs to which
  they will respond positively), and, in concert with the Action System, can
  modify the topology of the tree itself, dynamically growing a hierarchy of
  children in a process called innovation.

  The process of innovation is reward-driven, with only percepts that are
  believed to be correlated with increasing the reliability of an action in
  producing a desirable outcome being prompted to innovate. Both the
  confidence and the extracted data of every percept are cached in a
  PerceptMemory object.

  Both the confidence and the extracted data of every percept are cached in a
  PerceptMemory object. When a DataRecord enters the Perception System, a new
  PerceptMemory is created, and as the DataRecord is pushed through the
  Percept Tree, each percept that registers a positive match adds its
  rExUnittive data to the new PerceptMemory. Thus, given a sensory stimulus,
  the PerceptMemory represents all the agent can know about that stimulus.

  Thus, given a sensory stimulus, the PerceptMemory represents all the agent
  can know about that stimulus.

  Working Memory

  Like other agent-control architectures, we use a Working Memory structure
  whose function mirrors that of the pyschological conception of Working Memory –
  an object-based memory that contains information about the immediate task or
  context. The ultimate goal of Working Memory is to provide a sensory history
  of objects in the world.

  It is on the basis of these histories that action-decisions will be made,
  internal credit for reward assigned, motor-movements modulated, etc. Working
  Memory is a repository for persistent PerceptMemory objects. Taken together,
  they constitute the agent's “view” of the world.

  The PerceptMemory is itself a useful structure. By caching
  together the various perceptual impressions made by a world event (“the
  thing that was in front of me was also blue,” blueness and relative location
  being separate Percepts) they solve (or perhaps avoid) the infamous
  perceptual binding problem ([Treisman 1998]). They also allow us to submit
  complex queries to WorkingMemory: “which is the bird that is nearest me?”

  PerceptMemory objects become even more useful when they incorporate a time
  dimension with the data they contain. On any one timestep, the PerceptMemory
  objects that come out of the Perception System will by necessity only
  contain information gathered in that timestep. However, as events often
  extend through time, it is possible to match PerceptMemory objects from
  previous timesteps. Thus a recent visual event may represent only the latest
  sighting of an object that we have been tracking for some time.

  A DataRecord representing the utterance comes in from the world, causing
  certain Percepts in the Percept Tree to activate. The Perception System caches
  the confidences and data corresponding to these Percepts in a PerceptMemory
  object. This object then matches itself with the most similar existing
  PerceptMemory in Working Memory, and adds its data onto the history of data
  that it maintains.

  The Working Memory structure is meant to mirror this psychological conception
  of Working Memory. The Working Memory maintains a list of persistent
  PerceptMemory objects that together constitute the agent’s “view” of the
  current context. That “view,” however, is informed by more than just direct
  perception. Instead, it is a patchwork of perceptions, predictions and
  hypotheses. Any component of Automata that has something to say about how the
  world is (or might be) can modify PerceptMemory objects or post new ones. It
  is on the basis of these objects, whether directly perceived or not, that
  action-decisions will be made, internal credit for reward will be assigned,
  motor-movements will be modulated, and so on.

  When a new DataRecord is pushed through the Percept Tree, each Percept that
  registers a positive match caches its confidence and data in a table in the
  PerceptMemory. This PerceptMemory is then passed off to Working Memory. It
  is then “matched” against existing PerceptMemory objects stored there to
  determine if it is truly novel, or rather a continuation of an existing
  PerceptMemory (for example, is it the same red ball as the red ball that we
  saw an instant ago in the same place).

  In the case of visual events, matching is done on the basis of shape, or on
  the basis of location when shape is not enough to disambiguate incoming visual
  events (as is often the case with two nearby bird). This matching mechanism
  also allows events of differing modalities to be combined. If there is good
  indication that an acoustic event and a visual one belong together (for
  example, they originate in more or less the same region of space) then they
  may be matched together in Working Memory, presenting both sight and sound
  information through a single PerceptMemory and thus giving the impression
  that, for example, it was the shepherd who said, “sit.” In either case, if a
  match is found, the data from the new PerceptMemory is added to the history
  being kept in the old one. The new confidence is also added to a history of
  confidences. On timesteps in which new information for a given Percept is not
  observed, its confidence level is decayed. The rate of decay is determined in
  part by the Percept itself (confidence in another agent’s location might decay
  rapidly without observation, but confidence in its shape probably would not.)
  """

  @callback match(any()) :: any()

  defmacro __using__(_opts) do
    # @impl PerceptMem
    # def match(args)
  end
end
