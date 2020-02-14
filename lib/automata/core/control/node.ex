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
    a =
      if Enum.member?(Composite.types(), user_opts[:node_type]) do
        # IO.inspect(user_opts)

        quote do
          use DynamicSupervisor
          use Composite, user_opts: unquote(user_opts)
        end
      else
        quote do: use(Action)
      end

    b =
      quote bind_quoted: [user_opts: user_opts] do
        use Behavior, user_opts: user_opts

        use GlobalBlackboard
        use NodeBlackboard
        use GlobalUtility
        use NodeUtility

        # @type a_node :: {
        #         term() | :undefined,
        #         child() | :restarting,
        #         :worker | :supervisor,
        #         :supervisor.modules()
        #       }

        def child_spec do
          %{
            id: __MODULE__,
            start: {__MODULE__, :start_link, []},
            restart: :temporary,
            shutdown: 5000,
            type: :worker
          }
        end

        # Defoverridable makes the given functions in the current module overridable
        defoverridable update: 1, tick: 1, on_init: 1, on_terminate: 1
      end

    [a, b]
  end
end
