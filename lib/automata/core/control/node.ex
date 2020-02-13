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
  # TODO: Is becoming somewhat of a "Central point of failure". Rather than
  # injecting tons of code into a single process, we should probably link
  # with some GenServer(s) to handle state, restart independently?

  alias Automaton.{Behavior, Composite, Action}
  alias Automata.Blackboard, as: GlobalBlackboard
  alias Automaton.Blackboard, as: NodeBlackboard
  alias Automata.Utility, as: GlobalUtility
  alias Automaton.Utility, as: NodeUtility

  # When you call use in your module, the __using__ macro is called.
  defmacro __using__(user_opts) do
    quote bind_quoted: [user_opts: user_opts] do
      use Behavior

      if Enum.member?(Composite.types(), user_opts[:node_type]) do
        use DynamicSupervisor
        use Composite, user_opts: user_opts
      else
        use Action
      end

      use GlobalBlackboard
      use NodeBlackboard
      use GlobalUtility
      use NodeUtility

      # TODO: probably handle state somewhere else? GenServer linked to Node?
      defmodule State do
        # bh_fresh is for when status has not been initialized
        # yet or has been reset
        defstruct m_status: :bh_fresh,
                  # control is the parent, nil when fresh
                  control: nil,
                  m_children: user_opts[:children] || [],
                  m_current: nil
      end

      # Client API
      def start_link(args) do
        GenServer.start_link(__MODULE__, %State{})
        # tick()
      end

      def tick_freq do
        # default of 0 is an infinite loop
        unquote(user_opts[:tick_freq]) || 0
      end

      # #######################
      # # GenServer Callbacks #
      # #######################
      def init(%State{} = state) do
        IO.inspect(["Node.ex State:", state], label: __MODULE__)

        {:ok, nil}
      end

      def child_spec do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, []},
          restart: :temporary,
          shutdown: 5000,
          type: :worker
        }
      end

      #####################
      # Private Functions #
      #####################

      #####################
      # typespec          #
      #####################
      # @type a_node :: {
      #         term() | :undefined,
      #         child() | :restarting,
      #         :worker | :supervisor,
      #         :supervisor.modules()
      #       }
      # Defoverridable makes the given functions in the current module overridable
      defoverridable update: 0, tick: 0
    end
  end
end
