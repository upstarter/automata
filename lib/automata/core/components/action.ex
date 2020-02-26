defmodule Automaton.Action do
  @moduledoc """
    This is the primary user control interface to the Automata system. The
    configration parameters are used to inject the appropriate modules into the
    user-defined nodes based on their node_type and other options.

    Notes:
    Initialization and shutdown require extra care:
    on_init: receive extra parameters, fetch data from blackboard/utility,  make requests, etc..
    shutdown: free resources to not effect other actions
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
          defstruct status: :bh_fresh,
                    # control is the parent, nil when fresh
                    control: nil,
                    children: nil,
                    current: nil,
                    tick_freq: unquote(user_opts[:tick_freq]) || 500,
                    workers: nil
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
          case state.status do
            :bh_success ->
              IO.inspect(["on_init status", state.status, state.workers],
                label: Process.info(self)[:registered_name]
              )

            _ ->
              IO.inspect(["on_init status", state.status, state.workers],
                label: Process.info(self)[:registered_name]
              )
          end

          state
        end

        @impl Behavior
        def on_terminate(status) do
          case status do
            :bh_running ->
              IO.inspect("TERMINATED — RUNNING", label: Process.info(self)[:registered_name])

            :bh_failure ->
              IO.inspect("TERMINATED — FAILED", label: Process.info(self)[:registered_name])

            :bh_success ->
              IO.inspect("TERMINATED — SUCCEEDED",
                label: Process.info(self)[:registered_name]
              )

            :bh_aborted ->
              IO.inspect("TERMINATED — ABORTED", label: Process.info(self)[:registered_name])

            :bh_fresh ->
              IO.inspect("TERMINATED — FRESH???", label: Process.info(self)[:registered_name])
          end

          status
        end

        #
        # @impl Behaviour
        # def update(state) do
        #   status = :bh_running
        #   IO.inspect("Action Updated", label: Process.info(self)[:registered_name])
        #
        #   # return status, overidden by user
        #   status
        # end
      end

    # extra stuff at end
    append =
      quote do
        def child_spec([[composite_server, {m, _f, a}, name]] = args) do
          %{
            id: to_string(name) <> "Action",
            start: {__MODULE__, :start_link, args},
            shutdown: 10_000,
            restart: :transient,
            type: :worker
          }
        end

        # Defoverridable makes the given functions in the current module overridable
        defoverridable update: 1, on_init: 1, on_terminate: 1
      end

    [prepend, node_type, control, append]
  end
end
