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
        defmodule State do
          # bh_fresh is for when status has not been
          # initialized yet or has been reset
          defstruct a_status: :bh_fresh,
                    # control is the parent, nil when fresh
                    control: nil,
                    children: nil,
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

        # Defoverridable makes the given functions in the current module overridable
        # defoverridable update: 1, on_init: 1, on_terminate: 1
      end

    [prepend, node_type, control, append]
  end
end
