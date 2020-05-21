defmodule Automaton.Types.BT.Action do
  @moduledoc """
    An action is a leaf in the tree.
    It operates on the world as a component of a composite(control) node.
    Actions can alter the system configuration, returning one of three possible
    state values: Success, Failure, or Running. Conditions cannot alter the
    system configuration, returning one of two possible state values: Success,
    or Failure.
  """

  defmacro __using__(automaton_config) do
    prepend =
      quote do
        use GenServer
      end

    node_type =
      quote do
        defmodule State do
          # bh_fresh is for when status has not been
          # initialized yet or has been reset
          defstruct status: :bh_fresh,
                    # parent is nil when fresh
                    parent: nil,
                    control: 0,
                    children: nil,
                    current: nil,
                    tick_freq: unquote(automaton_config[:tick_freq]) || 50,
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
        def init([composite_sup, mfa, %State{} = state]) do
          {:ok, state}
        end
      end

    control =
      quote do
        def on_init(state) do
          case state.status do
            :bh_success ->
              nil

            _ ->
              nil
          end

          state
        end

        def on_terminate(state) do
          case state.status do
            :bh_running ->
              IO.inspect("ACTION TERMINATED — RUNNING",
                label: Process.info(self())[:registered_name]
              )

            :bh_failure ->
              IO.inspect("ACTION TERMINATED — FAILED",
                label: Process.info(self())[:registered_name]
              )

            :bh_success ->
              IO.inspect("ACTION TERMINATED — SUCCEEDED",
                label: Process.info(self())[:registered_name]
              )

            :bh_aborted ->
              IO.inspect("ACTION TERMINATED — ABORTED",
                label: Process.info(self())[:registered_name]
              )

            :bh_fresh ->
              IO.inspect("ACTION TERMINATED — FRESH",
                label: Process.info(self())[:registered_name]
              )
          end

          state.status
        end
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
