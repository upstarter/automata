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
          defstruct a_status: :bh_fresh,
                    # control is the parent, nil when fresh
                    control: nil,
                    a_children: unquote(user_opts[:children]) || nil,
                    a_current: nil,
                    tick_freq: unquote(user_opts[:tick_freq]) || 0
        end

        # Client API
        def start_link([composite_sup, {_, _, _} = mfa, name]) do
          new_name = to_string(name) <> "Action"

          GenServer.start_link(__MODULE__, [composite_sup, mfa, %State{}],
            name: String.to_atom(new_name)
          )
        end

        # #######################
        # # GenServer Callbacks #
        # #######################
        @impl true
        def init([composite_sup, mfa, %State{} = state]) do
          {:ok, state}
        end
      end

    control =
      quote do
        # should tick each subtree at a frequency corresponding to subtrees tick_freq
        # each subtree of the user-defined root node will be ticked recursively
        # every update (at rate tick_freq) as we update the tree until we find
        # the leaf node that is currently running (will be an action).
        def tick(state) do
          IO.inspect(["TICK: #{state.tick_freq}", state.a_children])
          if state.a_status != :bh_running, do: on_init(state)

          {:reply, state, new_state} = update(state)
          IO.inspect(["Child state after update", state, new_state])

          if new_state.a_status != :bh_running do
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
          if state.a_status == :bh_success do
            IO.inspect(["SEQUENCE SUCCESS!", state.a_status],
              label: __MODULE__
            )
          else
            IO.inspect(["SEQUENCE STATUS", state.a_status],
              label: __MODULE__
            )
          end

          {:reply, state}
        end

        @impl Behavior
        def on_terminate(state) do
          status = state.a_status

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
        def child_spec([[composite_server, {m, _f, a}, name]] = args) do
          %{
            id: to_string(name) <> "Action",
            start: {__MODULE__, :start_link, args},
            shutdown: 10000,
            restart: :transient,
            type: :worker
          }
        end

        # def child_spec([[node_sup, {m, _f, a}, name]] = args) do
        #   %{
        #     id: to_string(name) <> "Server",
        #     start: {__MODULE__, :start_link, args},
        #     shutdown: 10000,
        #     restart: :temporary,
        #     type: :worker
        #   }
        # end

        # Defoverridable makes the given functions in the current module overridable
        # defoverridable update: 1, on_init: 1, on_terminate: 1
      end

    [prepend, node_type, control, append]
  end
end
