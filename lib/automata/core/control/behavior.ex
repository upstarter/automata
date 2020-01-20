# An Automaton.Behavior is an abstract interface that can be activated, run,
# and deactivated. Actions provide specific implementations of
# this interface. Branches in the tree can be thought of as high
# level behaviors, heirarchically combining smaller behaviors to
# provide more complex and interesting behaviors

# C++ code from Behavior Tree Starter Kit online
# enum Status
# /**
#  * Return values of and valid states for behaviors.
#  */
# {
#     BH_INVALID,
#     BH_SUCCESS,
#     BH_FAILURE,
#     BH_RUNNING,
#     BH_ABORTED,
# };
#
# class Behavior
# /**
#  * Base class for actions, conditions and composites.
#  */
# {
# public:
#     virtual Status update()				= 0;
#
#     virtual void onInitialize()			{}
#     virtual void onTerminate(Status)	{}
#
#     Behavior()
#     :   m_eStatus(BH_INVALID)
#     {
#     }
#
#     virtual ~Behavior()
#     {
#     }
#
#     Status tick()
#     {
#         if (m_eStatus != BH_RUNNING)
#         {
#             onInitialize();
#         }
#
#         m_eStatus = update();
#
#         if (m_eStatus != BH_RUNNING)
#         {
#             onTerminate(m_eStatus);
#         }
#         return m_eStatus;
#     }
#
#     void reset()
#     {
#         m_eStatus = BH_INVALID;
#     }
#
#     void abort()
#     {
#         onTerminate(BH_ABORTED);
#         m_eStatus = BH_ABORTED;
#     }
#
#     bool isTerminated() const
#     {
#         return m_eStatus == BH_SUCCESS  ||  m_eStatus == BH_FAILURE;
#     }
#
#     bool isRunning() const
#     {
#         return m_eStatus == BH_RUNNING;
#     }
#
#     Status getStatus() const
#     {
#         return m_eStatus;
#     }
#
# private:
#     Status m_eStatus;
# };

defmodule Automaton.Behavior do
  @moduledoc """
    Actions are Behaviors that access information from the world and change the world.
    Initialization and shutdown require extra care:
    init: receive extra parameters, fetch data from blackboard, make requests, etc..
    shutdown: free resources to not effect other actions
    Task Switching: on sucess, failure, interruption by more important task
  """

  # Define behaviours which user modules have to implement, with type annotations
  # TODO: move to included elixir behavior module? or leave here?
  @callback on_init([]) :: {:ok, term} | {:error, String.t()}
  @callback update() :: atom
  @callback on_terminate(atom) :: atom
  # make m_eStatus = :invalid
  @callback reset() :: atom
  # make m_eStatus = :aborted
  @callback abort() :: atom
  @callback termintated?() :: bool
  @callback running?() :: bool
  @callback get_status() :: atom

  # TODO: enum type for the status?
  # invalid is for when status has not been initialized yet

  # When you call use in your module, the __using__ macro is called.
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      use DynamicSupervisor
      @behaviour Automaton.Behavior
      @behaviour Automata.Composite

      defmodule State do
        defstruct status: :bh_invalid,
                  children: []
      end

      # def start_link([node_sup, node_config]) do
      #   GenServer.start_link(__MODULE__, [node_sup, node_config], name: name(node_config[:name]))
      # end
      #
      # def status(tree_name) do
      #   GenServer.call(name(tree_name), :status)
      # end
      #
      # #############
      # # Callbacks #
      # ############ j
      #
      # def init([node_sup, node_config]) when is_pid(node_sup) do
      #   Process.flag(:trap_exit, true)
      #   monitors = :ets.new(:monitors, [:private])
      #   state = %State{node_sup: node_sup, monitors: monitors}
      #
      #   init(node_config, state)
      # end

      # BEHAVIOR INTERFACE
      # should dynamically supervise user-defined ChildNode1-3
      # and tick them at a frequency corresponding to their tick_freq
      # TODO how to have status as state, external GenServer?
      @impl Automaton.Behavior
      def on_init(str) do
        IO.inspect(unquote(opts))

        # {:ok, _tree_sup} =
        #   DynamicSupervisor.start_child(
        #     Automata.AutomataSupervisor,
        #     {Automata.AutomatonSupervisor, [node_config]}
        #   )
        #
        # nodes = prepopulate(size, node_sup)

        {:ok, "done with init " <> str}
      end

      @impl Automaton.Behavior
      def update do
        IO.puts("update/0")
        # return status, overidden by user
      end

      def tick(status \\ :bh_invalid, arg \\ "stuff") do
        if status != :running, do: on_init(arg)
        status = update()
        if status != :running, do: on_terminate(status)
        {:ok, status}
      end

      @impl Automaton.Behavior
      def on_terminate(status) do
        {:ok, status}
      end

      @impl Automaton.Behavior
      def get_status() do
      end

      @impl Automaton.Behavior
      def running?() do
      end

      @impl Automaton.Behavior
      def terminated?() do
      end

      # Defoverridable makes the given functions in the current module overridable
      defoverridable on_init: 1, update: 0, on_terminate: 1, tick: 2
    end
  end
end

# user-defined actions
defmodule ChildBehavior1 do
  use Automaton.Behavior,
    # required
    # one of :sequence, :selector, :parallel, etc...
    # or type :execution for execution nodes (no children)
    node_type: :selector,

    # the frequency of updates for this node(tree), in seconds
    # 1ms
    tick_freq: 0.001,

    # not included for execution nodes
    # list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes
    # and in parallel for type :parallel
    children: [ChildNode1, ChildNode2, ChildNode3]

  def update do
    {:ok, "overrides update/0"}
  end
end

defmodule ChildBehavior2 do
  use Automaton.Behavior
end
