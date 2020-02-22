defmodule Automaton.CompositeServer do
  @moduledoc """
  When a child behavior is complete and returns its status code the Composite
  decides whether to continue through its children or whether to stop there and
  then and return a value.

  The behavior tree represents all possible Actions that your AI can take.
  The route from the top level to each leaf represents one course of action, and
  the behavior tree algorithm traverses among those courses of action in a
  left-to-right manner. In other words, it performs a depth-first traversal.
  """
  alias Automaton.CompositeServer
  alias Automaton.Composite.{Sequence, Selector}

  # a composite is just an array of behaviors
  @callback add_child(term) :: {:ok, list} | {:error, String.t()}
  @callback remove_child(term) :: {:ok, list} | {:error, String.t()}
  @callback clear_children :: {:ok, term} | {:error, String.t()}
  @callback terminal_status() :: atom

  @types [:sequence, :selector, :parallel, :priority]
  def types, do: @types

  defmacro __using__(opts) do
    user_opts = opts[:user_opts]

    imports =
      case user_opts[:node_type] do
        :sequence ->
          quote do: use(Sequence)

        :selector ->
          quote do: use(Selector)
      end

    prepend =
      quote do
        use GenServer
        import CompositeServer
        @behaviour CompositeServer
        # TODO: probably handle state somewhere else? GenServer linked to Node?
        defmodule State do
          # bh_fresh is for when status has not been initialized
          # yet or has been reset
          defstruct c_composite_sup: nil,
                    c_node_sup: nil,
                    c_monitors: nil,
                    children: unquote(user_opts[:children]),
                    c_status: :bh_fresh,
                    # control is the parent, nil when fresh
                    c_control: nil,
                    c_current: nil,
                    c_tick_freq: unquote(user_opts[:tick_freq]) || 0,
                    c_mfa: nil,
                    c_name: __MODULE__
        end

        # Client API
        def start_link([node_sup, {_, _, _} = mfa, name]) do
          new_name = to_string(name) <> "Server"

          GenServer.start_link(__MODULE__, [node_sup, mfa, %State{}, name],
            name: String.to_atom(new_name)
          )
        end

        # #######################
        # # GenServer Callbacks #
        # #######################
        @impl true
        def init([node_sup, {m, _, _} = mfa, state, name]) do
          Process.flag(:trap_exit, true)
          monitors = :ets.new(:monitors, [:private])

          state = %State{
            c_node_sup: node_sup,
            c_mfa: mfa,
            c_monitors: monitors,
            c_name: name
          }

          send(self(), :start_node_supervisor)

          IO.inspect([
            "[INIT] CompositeServer",
            name,
            self(),
            node_sup,
            mfa,
            state
          ])

          {:ok, state}
        end

        def handle_info(
              :start_node_supervisor,
              state = %{c_node_sup: node_sup, c_mfa: mfa, c_name: name}
            ) do
          IO.inspect(
            log: "[POST_INIT PRE]",
            self: Process.info(self())[:registered_name],
            node_sup: Process.info(node_sup)[:registered_name]
          )

          spec = {Automaton.CompositeSupervisor, [[self(), mfa, name]]}
          {:ok, composite_sup} = DynamicSupervisor.start_child(node_sup, spec)

          IO.inspect(
            log: "[POST_INIT PRE] Starting Children",
            self: Process.info(self())[:registered_name],
            node_sup: Process.info(node_sup)[:registered_name],
            comp_sup: Process.info(composite_sup)[:registered_name],
            spec: spec
          )

          send(self(), :start_children)

          {:noreply, %{state | c_composite_sup: composite_sup}}
        end

        def handle_info(
              :start_children,
              state = %{
                children: [current | remaining],
                c_node_sup: node_sup,
                c_mfa: mfa,
                c_name: name
              }
            ) do
          IO.inspect(
            log: "Start Children",
            current: current,
            children: state.children,
            node_sup: Process.info(node_sup)[:registered_name]
          )

          start_children(state)

          {:noreply, state}
        end

        def start_children(
              %{
                children: [current | remaining],
                c_mfa: {m, f, a} = mfa,
                c_name: name,
                c_composite_sup: composite_sup
              } = state
            ) do
          IO.inspect(
            log:
              "#{Process.info(composite_sup)[:registered_name]} starting child #{
                IO.inspect(current)
              }",
            current: current,
            mfa: mfa,
            name: name,
            self: "#{Process.info(self())[:registered_name]}",
            children: state.children,
            remaining: remaining
          )

          node =
            start_node(
              :"#{name}CompositeSupervisor",
              {current, :start_link, [[composite_sup, {current, :start_link, a}, :"#{current}"]]}
            )

          start_children(%{state | children: remaining})

          IO.inspect(
            log: "#{Process.info(composite_sup)[:registered_name]} started child #{current}.",
            current: current,
            mfa: mfa,
            name: name,
            self: "#{Process.info(self())[:registered_name]}",
            remaining: remaining
          )

          {:reply, {:ok, node}, state}
        end

        def start_children(%{children: []} = state) do
          IO.inspect(
            log: "End CompositeSupervisor",
            children: state.children
          )

          {:reply, :ok, state}
        end

        # TODO: handle composite OR component function pattern matching logic
        # type declaration flag passed in state for each composite, component(action, decorator, etc..)?
        # or `m.composite?` and/or `m.component?` static flag to access on each module?
        defp start_node(composite_sup, {m, _f, a} = mfa) do
          IO.inspect(
            log: "Starting child #{m}}",
            comp_sup: composite_sup,
            mfa: mfa
          )

          {:ok, composite} = DynamicSupervisor.start_child(composite_sup, {m, a})

          # info = Process.info(m)[:registered_name]

          IO.inspect(
            log: "Started child...",
            comp: Process.info(composite)[:registered_name],
            mfa: {m, a}
          )

          true = Process.link(composite)
          composite
        end
      end

    bh_tree_control =
      quote bind_quoted: [user_opts: opts[:user_opts]] do
        def process_children(%{children: [current | remaining]} = state) do
          {:reply, state, new_state} = current.tick(state)

          status = new_state.a_status

          if status != terminal_status() do
            new_state
          else
            process_children(%{state | children: remaining})
          end
        end

        def process_children(%{children: []} = state) do
          %{state | a_status: terminal_status()}
        end

        # notifies listeners if this task status is not fresh
        @impl CompositeServer
        def add_child(child) do
          {:ok, nil}
        end

        @impl CompositeServer
        def remove_child(child) do
          {:ok, nil}
        end

        @impl CompositeServer
        def clear_children() do
          {:ok, nil}
        end
      end

    # extra stuff at end
    append =
      quote do
        def handle_info(
              {:DOWN, ref, _, _, _},
              state = %{c_monitors: monitors, children: children}
            ) do
          case :ets.match(monitors, {:"$1", ref}) do
            [[pid]] ->
              true = :ets.delete(monitors, pid)
              new_state = %{state | children: [pid | children]}
              {:noreply, new_state}

            [[]] ->
              {:noreply, state}
          end
        end

        def handle_info({:EXIT, node_sup, reason}, state = %{node_sup: node_sup}) do
          {:stop, reason, state}
        end

        def handle_info(
              {:EXIT, pid, _reason},
              state = %{
                c_monitors: monitors,
                children: children,
                c_node_sup: node_sup,
                c_mfa: {m, f, a} = mfa,
                c_name: name
              }
            ) do
          case :ets.lookup(monitors, pid) do
            [{pid, ref}] ->
              true = Process.demonitor(ref)
              true = :ets.delete(monitors, pid)
              new_state = handle_child_exit(pid, state)
              {:noreply, new_state}

            [] ->
              # NOTE: child crashed, no monitor
              case Enum.member?(children, pid) do
                true ->
                  remaining_children = children |> Enum.reject(fn p -> p == pid end)

                  new_state = %{
                    state
                    | children: [
                        start_node(node_sup, {m, :start_link, [[self(), mfa, name]]})
                        | remaining_children
                      ]
                  }

                  {:noreply, new_state}

                false ->
                  {:noreply, state}
              end
          end
        end

        def handle_info(_info, state) do
          {:noreply, state}
        end

        @impl true
        def terminate(_reason, _state) do
          :ok
        end

        #####################
        # Private Functions #
        #####################

        defp name(tree_name) do
          :"#{tree_name}Server"
        end

        defp handle_child_exit(pid, state) do
          %{
            c_node_sup: node_sup,
            children: children,
            monitors: monitors
          } = state

          # TODO
        end

        def child_spec([[node_sup, {m, _f, a}, name]] = args) do
          %{
            id: to_string(name) <> "Server",
            start: {__MODULE__, :start_link, args},
            shutdown: 10000,
            restart: :temporary,
            type: :worker
          }
        end

        # Defoverridable makes the given functions in the current module overridable
        defoverridable update: 1, on_init: 1, on_terminate: 1
      end

    [imports, prepend, bh_tree_control, append]
  end
end
