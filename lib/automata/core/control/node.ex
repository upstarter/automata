# An Automaton.Node (for use in User-Defined Node) is an abstract interface that can be activated, run,
# and deactivated. Actions(Execution Nodes) provide specific implementations of
# this interface. Branches in the tree can be thought of as high
# level behaviors, heirarchically combining smaller behaviors to
# provide more complex and interesting behaviors

defmodule Automaton.Node do
  @moduledoc """
    Actions are Behaviors that access information from the world and change the world.
    Initialization and shutdown require extra care:
    on_init: receive extra parameters, fetch data from blackboard, make requests, etc..
    shutdown: free resources to not effect other actions
    Task Switching: on sucess, failure, interruption by more important task
  """

  # When you call use in your module, the __using__ macro is called.
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      use DynamicSupervisor
      use Automaton.Behavior

      # composite or execution node?
      # TODO move execution callbacks to module as well
      if Enum.member?(Automaton.Composite.composites(), opts[:node_type]) do
        use Automaton.Composite, node_type: opts[:node_type]
        @behaviour Automaton.Composite
      else
        def update do
          IO.puts("update/0")
          # return status, overidden by user
        end

        @impl Automaton.Behavior
        def on_init(str) do
          IO.inspect(unquote(opts))

          {:ok, "done with init " <> str}
        end
      end

      defmodule State do
        # bh_invalid is for when status has not been initialized yet
        defstruct m_status: :bh_invalid,
                  m_children: opts[:children],
                  m_current: nil
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
      def tick(status \\ :bh_invalid, arg \\ "stuff") do
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
