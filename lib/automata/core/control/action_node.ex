defmodule Automaton.Action do
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

        # all nodes are GenServer's & Behavior's
        use GenServer
        use Behavior
      end

    node_type =
      quote do
        # TODO: probably handle state somewhere else? GenServer linked to Node?
        defmodule State do
          # bh_fresh is for when status has not been initialized
          # yet or has been reset
          defstruct m_status: :bh_fresh,
                    # control is the parent, nil when fresh
                    control: nil,
                    m_children: unquote(user_opts[:children]) || nil,
                    m_current: nil,
                    tick_freq: unquote(user_opts[:tick_freq]) || 0
        end

        # Client API
        def start_link([[automaton_server, {_, _, _} = mfa]]) do
          GenServer.start_link(__MODULE__, [automaton_server, mfa, %State{}], name: __MODULE__)
        end

        # #######################
        # # GenServer Callbacks #
        # #######################
        @impl true
        def init([automaton_server, mfa, %State{} = state]) do
          {:ok, state}
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
          IO.inspect(["Child state after update", state, new_state])

          if new_state.m_status != :bh_running do
            on_terminate(new_state)
          else
            # TODO: needs to be per control node
            schedule_next(new_state.tick_freq)
          end

          {:reply, state, new_state}
        end

        def schedule_next(freq), do: Process.send_after(self(), :scheduled_tick, freq)

        @impl GenServer
        def handle_call(:tick, _from, state) do
          {:reply, state, new_state} = tick(state)
        end

        @impl GenServer
        def handle_info(:scheduled_tick, state) do
          {:reply, state, new_state} = tick(state)
          {:noreply, new_state}
        end

        @impl Behavior
        def on_init(state) do
          if state.m_status == :bh_success do
            IO.inspect(["SEQUENCE SUCCESS!", state.m_status],
              label: __MODULE__
            )
          else
            IO.inspect(["SEQUENCE STATUS", state.m_status],
              label: __MODULE__
            )
          end

          {:reply, state}
        end

        @impl Behavior
        def on_terminate(state) do
          status = state.m_status

          case status do
            :bh_running -> IO.inspect("TERMINATED SEQUENCE RUNNING")
            :bh_failure -> IO.inspect("TERMINATED SEQUENCE FAILED")
            :bh_success -> IO.inspect("TERMINATED SEQUENCE SUCCEEDED")
            :bh_aborted -> IO.inspect("TERMINATED SEQUENCE ABORTED")
          end

          {:ok, state}
        end
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

    [prepend, node_type, intel, control, append]
  end
end
