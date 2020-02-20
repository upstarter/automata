defmodule Automaton.Control do
  @moduledoc """
    This is the primary user control interface to the Automata system. The
    configration parameters are used to inject the appropriate modules into the
    user-defined nodes based on their node_type and other options.

    Notes:
    Initialization and shutdown require extra care:
    on_init: receive extra parameters, fetch data from blackboard/utility,  make requests, etc..
    shutdown: free resources to not effect other actions

    Multi-Agent Systems
      Proactive & Reactive agents
      BDI architecture: Beliefs, Desires, Intentions
  """
  alias Automaton.Behavior
  alias Automaton.CompositeServer

  defmacro __using__(user_opts) do
    prepend =
      quote do
        # @type node :: {
        #         term() | :undefined,
        #         child() | :restarting,
        #         :worker | :supervisor,
        #         :supervisor.modules()
        #       }

        # all nodes are Behavior's
        use Behavior, user_opts: unquote(user_opts)
      end

    # composite(control node) or action(execution node)? if its a
    # composite(control) node, the Automaton.CompositeSupervisor supervises the
    # this control(root) node, which runs all user
    # actions(which are GenServer workers ultimately supervised by
    # Automaton.CompositeSupervisor)
    node_type =
      quote do
        use CompositeServer, user_opts: unquote(user_opts)
      end

    control =
      quote do
        # should tick each subtree at a frequency corresponding to subtrees tick_freq
        # each subtree of the user-defined root node will be ticked recursively
        # every update (at rate tick_freq) as we update the tree until we find
        # the leaf node that is currently running (will be an action).
        def tick(state) do
          IO.inspect(["TICK: #{state.tick_freq}", state.m_children])
          if state.m_status != :bh_running, do: on_init(state)

          {:reply, state, new_state} = update(state)

          if new_state.m_status != :bh_running do
            on_terminate(new_state)
          end

          receive do
          after
            new_state.tick_freq ->
              tick(new_state)
          end
        end
      end

    [prepend, node_type, control]
  end
end
