defmodule Automaton do
  @moduledoc """
    This is the primary user control interface to the Automata system. The
    configration parameters are used to inject the appropriate modules into the
    user-defined nodes based on their node_type and other options.

    ## Notes:
      - Initialization and shutdown require extra care:
        - on_init: receive extra parameters, fetch data from blackboard/utility,  make requests, etc..
        - shutdown: free resources to not effect other actions

    TODO: store any currently processing nodes so they can be ticked directly
    within the behaviour tree engine rather than per tick traversal of the entire
    tree. Zipper Tree?
  """

  defmacro __using__(user_opts) do
    Automaton.Types.Typology.call(user_opts)
  end
end
