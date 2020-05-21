defmodule Automata.Blackboard do
  @moduledoc """
    A global Blackboard for knowledge representations

    Memory and Interaction Protocols

      With large trees, we face another challenge: storage. In an ideal world,
    each AI would have an entire tree allocated to it, with each behavior having
    a persistent amount of storage allocated to it, so that any state necessary
    for its functioning would simply always be available. However, assuming
    about 100 actors allocated at a time about 60 behaviors in the average tree,
    and each behavior taking up about 32 bytes of memory, this gives us about
    192K of persistent behavior storage. Clearly, as the tree grows even further
    this becomes even more of a memory burden, ExUnitially for a platform like
    the Xbox.

      We can cut down on this burden considerably if we note that in the vast majority
    of cases, we are only really interested in a small number of behaviors - those
    that are actually running (the current leaf, its parent, it grandparent and so
    on up the tree). The obvious optimization to make is to create a small pool of
    state memory for each actor divided into chunks corresponding to levels of the
    hierarchy. The tree becomes a free-standing static structure (i.e. is not
    allocated per actor) and the behaviors themselves become code fragments that
    operate on a chunk. (The same sort of memory usage can be obtained in an object
    oriented way if parent behavior objects only instantiate their children at the
    time that the children are selected. This was the approach taken in [Alt04]).
    Our memory usage suddenly becomes far more efficient: 100 actors times 64 bytes
    (an upper bound on the amount behavior storage needed) times 4 layers (in the
    case of Halo 2), or about 25K. Very importantly, this number only grows with the
    maximum depth of the tree, not the number of behaviors.

    This leaves us with another problem however, the problem of persistent
    behavior state. There are numerous instances in the Halo 2 repertoire
    where behaviors are disallowed for a certain amount of time after their
    last successful performance (grenade-throwing, for example). In the ideal
    world, this information about "last execution time" would be stored in the
    persistently allocated grenade behavior. However, as that storage in the
    above scheme is only temporarily allocated, we need somewhere else to
    store the persistent behavior data.

    There is an even worse example - what about per-target persistent behavior
    state? Consider the search behavior. Search would like to indicate when it
    fails in its operation on a particular target. This lets the actor know to
    forget about that target and concentrate its efforts elsewhere. However,
    this doesn't preclude the actor going and searching for a different target -
    so the behavior cannot simply be turned off once it has failed.

    Memory - in the psychological sense of stored information on past actions
    and events, not in the sense of RAM - presents a problem that is inherent to
    the tree structure. The solution in any world besides the ideal one is to
    create a memory pool - or a number of memory pools - outside the tree to act
    as its storage proxy.

    When we consider our memory needs more generally, we can quickly distinguish
    at least four different categories:

      Per-behavior (persistent): grenade throws, recent vehicle actions
      Per-behavior (short-term): state lost when the behavior finishes
      Per-object: perception information, last seen position, last seen orientation
      Per-object per-behavior: last-meleed time, search failures, pathfinding-to failures
  """

  defmacro __using__(_automaton_config) do
  end
end
