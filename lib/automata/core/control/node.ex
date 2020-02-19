defmodule Automaton.Node do
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
  alias Automaton.{Behavior, Composite, Action}
  alias Automata.Blackboard, as: GlobalBlackboard
  alias Automaton.Blackboard, as: NodeBlackboard
  alias Automata.Utility, as: GlobalUtility
  alias Automaton.Utility, as: NodeUtility

  defmacro __using__(user_opts) do
    prepend =
      quote do
        # @type node :: {
        #         term() | :undefined,
        #         child() | :restarting,
        #         :worker | :supervisor,
        #         :supervisor.modules()
        #       }

        # all nodes are behaviors
        use Behavior, user_opts: unquote(user_opts)
      end

    # composite(control node) or action(execution node)?
    node_type =
      if Enum.member?(Composite.types(), user_opts[:node_type]) do
        # if its a composite(control node), it supervises actions(execution nodes)
        quote do
          use DynamicSupervisor
          use GenServer
          use Composite, user_opts: unquote(user_opts)
        end
      else
        # if its an action(execution) node, it is a supervised worker
        quote do
          use GenServer
          use Action, user_opts: unquote(user_opts)
        end
      end

    # TODO: allow user to choose from behavior tree, utility AI, or both
    # for the knowledge and decisioning system. Allow third-party strategies?
    intel =
      quote do
        use GlobalBlackboard
        use NodeBlackboard
        use GlobalUtility
        use NodeUtility
      end

    # extra stuff at end
    append =
      quote do
        def child_spec do
          %{
            id: __MODULE__,
            start: {__MODULE__, :start_link, []},
            restart: :transient,
            shutdown: 5000,
            type: :worker
          }
        end

        # Defoverridable makes the given functions in the current module overridable
        defoverridable update: 1, on_init: 1, on_terminate: 1
      end

    [prepend, node_type, intel, append]
  end
end
