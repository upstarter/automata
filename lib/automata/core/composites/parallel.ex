defmodule Automata.Composite.Parallel do
  @moduledoc """
    Parallel Node
    When the execution of a parallel node starts, then the node’s children are
    executed in succession from left to right without waiting for a return status
    from any child before ticking the next one. It returns success if a given number
    of children M ∈ N return success, it returns failure when the children that
    return running and success are not enough to reach the given number, even if
    they would all return success. It returns running otherwise. The purpose of
    the parallel node is to model those tasks separable in independent sub-tasks
    performing non-conflicting actions (e.g. a multi object tracking can be
    performed using several cameras).

    We could also configure Parallel to have the policy of the Selector task so it
    returns success when its first child succeeds and failure only when all have
    failed. We could also use hybrid policies, where it returns success or failure
    after some specific number or proportion of its children have succeeded or
    failed.

    Using Parallel blocks to make sure that Conditions hold is an important use-case
    in behavior trees. With it we can get much of the power of a state machine, and
    in particular the state machine’s ability to switch tasks when important events
    occur and new opportunities arise. Rather than events triggering transitions
    between states, we can use sub-trees as states and have them running in parallel
    with a set of conditions.
  """
end
