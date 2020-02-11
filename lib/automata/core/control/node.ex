defmodule Automaton.Node do
  @moduledoc """
    This is the primary user control interface to the Automata system. The
    configration parameters are used to inject the appropriate code into the
    user-defined nodes based on their node_type and other options.

    Initialization and shutdown require extra care:
    on_init: receive extra parameters, fetch data from blackboard, make requests, etc..
    shutdown: free resources to not effect other actions
    Task Switching: on success, failure, interruption by more important task
  """

  # When you call use in your module, the __using__ macro is called.
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      use DynamicSupervisor
      use Automaton.Behavior
      # TODO: tie in BlackBoards
      # # global BB
      # use Automata.Blackboard
      # # individual node BB
      # use Automaton.Blackboard

      if Enum.member?(Automaton.Composite.composites(), opts[:node_type]) do
        use Automaton.Composite, node_type: opts[:node_type], children: opts[:children]
      else
        use Automaton.Action
      end

      # Client API
      def start_link(args) do
        GenServer.start_link(__MODULE__, args)
      end

      # #######################
      # # GenServer Callbacks #
      # #######################
      def init(arg) do
        IO.inspect(["UserNode", arg], label: __MODULE__)

        {:ok, arg}
      end

      # should tick each subtree at a frequency corresponding to subtrees tick_freq
      # each subtree of the user-defined root node will be ticked recursively
      # every update (at rate tick_freq) as we update the tree until we find
      # the leaf node that is currently running (will be an action).
      def tick(status \\ :bh_fresh, arg \\ "stuff") do
        if status != :running, do: on_init(arg)
        status = update()
        if status != :running, do: on_terminate(status)
        {:ok, status}
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

      # Defoverridable makes the given functions in the current module overridable
      defoverridable on_init: 1, update: 0, on_terminate: 1, tick: 2
    end
  end
end
