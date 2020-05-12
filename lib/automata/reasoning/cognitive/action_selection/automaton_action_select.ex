defmodule Automaton.Types.BT.ActionSelect do
  @moduledoc """
  Agent is a function from percept sequences to actions
  Action Selection, Must be simple and fast
  Given a set of PerceptMemory objects(structs) that detail the perceived state
  of the world, the agent must decide which action(s) it is appropriate to
  perform. This process is known as Action Selection. There are three essential
  issues to be addressed when designing an Action Selection mechanism. First,
  what is the fundamental representation of action used by the system? Second,
  how does the system choose which actions to perform at a given instant? Many
  types of decision-making processes are possible here. Third, how can the
  choice of action be modified to allow the agent to learn from experience?

  ActionGroup = {}
  ActionTuple = {} fields:

  trigger - A piece of code that returns a scalar value representing the relevance of
    an ActionTuple given the current state of Working Memory. Triggers are
    typically references to percepts in the Percept Tree (a trigger that
    points to the "Bird Shape” percept will return a high relevance given any
    PerceptMemory that has a high "Bird Shape” confidence). However, the
    TriggerContext is general enough that more complex trigger-conditions can
    be hand-crafted. As we will see, Percept-based triggers are useful because
    they can be automatically generated through the learning process

  action - Primitive action to take (usually modify blackboard as event system)

  object - Target for the Action often defined in terms of percepts When an
    ActionTuple is active, the ObjectContext posts the PerceptMemory chosen into
    the OBJECT_OF_ATTENTION posting of the internal blackboard, thereby making
    it available to the rest of the system. The ObjectContext is an optional
    component, since not all actions are necessarily targeted

  do_until - A piece of code that returns a scalar representing the continuing
    relevance of an ActionTuple while it is active.

  value - intrinsic value/relevance, an indicator of how generally “good” the
    ActionTuple is. This is similar to the Q-value in Q-learning (see [Ballard
    1997])
  """

  defmacro __using__(_user_opts) do
  end
end
