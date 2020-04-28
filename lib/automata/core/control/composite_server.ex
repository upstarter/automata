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
  @callback clear_children :: {:ok, list} | {:error, String.t()}
  @callback continue_status() :: atom

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

        # TODO: probably handle state somewhere else? GenServer linked to Node?
        defmodule State do
          # bh_fresh is for when status has not been initialized
          # yet or has been reset, name is user-defined module name + "Server"
          defstruct name: nil,
                    status: :bh_fresh,
                    children: unquote(user_opts[:children]),
                    # the running children pids
                    workers: [],
                    composite_sup: nil,
                    node_sup: nil,
                    node_type: unquote(user_opts[:node_type]),
                    # control is the parent, nil when fresh
                    control: nil,
                    tick_freq: unquote(user_opts[:tick_freq]) || 2000,
                    monitors: nil,
                    mfa: nil
        end
      end

    control =
      quote bind_quoted: [user_opts: opts[:user_opts]] do
        # Client API
        def start_link([node_sup, {_, _, _} = mfa, name]) do
          new_name = to_string(name) <> "Server"

          GenServer.start_link(__MODULE__, [node_sup, mfa, %State{}, new_name],
            name: String.to_atom(new_name)
          )
        end

        # #######################
        # # GenServer Callbacks #
        # #######################
        def init([node_sup, {m, _, _} = mfa, state, name]) do
          Process.flag(:trap_exit, true)
          monitors = :ets.new(:monitors, [:private])

          new_state = %{
            state
            | node_sup: node_sup,
              mfa: mfa,
              monitors: monitors,
              name: name
          }

          send(self(), :start_composite_supervisor)

          {:ok, new_state}
        end

        def handle_info(
              :start_composite_supervisor,
              state = %{node_sup: node_sup, mfa: mfa, name: name}
            ) do
          spec = {Automaton.CompositeSupervisor, [[self(), mfa, name]]}
          {:ok, composite_sup} = DynamicSupervisor.start_child(node_sup, spec)
          new_state = %{state | composite_sup: composite_sup}

          send(self(), :start_children)

          {:noreply, new_state}
        end

        def handle_info(:start_children, state) do
          {:reply, :ok, new_state} = start_children(state)

          {:noreply, new_state}
        end

        # def handle_info(:update, state) do
        #   {:noreply, %{state | status: update(state)}}
        # end

        def start_children(
              %{
                children: children,
                mfa: {m, f, a} = mfa,
                name: name,
                composite_sup: composite_sup
              } = state
            ) do
          # start all the children
          workers =
            Enum.map(children, fn child ->
              start_node(
                :"#{name}CompositeSupervisor",
                {child, :start_link, [[composite_sup, {child, :start_link, a}, :"#{child}"]]}
              )
            end)

          new_state = %{state | workers: workers}

          {:reply, :ok, new_state}
        end

        defp start_node(composite_sup, {m, _f, a} = mfa) do
          {:ok, node} = DynamicSupervisor.start_child(composite_sup, {m, a})

          true = Process.link(node)
          node
        end

        # notifies listeners if child status is not fresh
        def add_child(child) do
          {:ok, []}
        end

        def remove_child(child) do
          {:ok, []}
        end

        def clear_children() do
          {:ok, []}
        end

        def continue_status() do
          {:ok, nil}
        end
      end

    append =
      quote do
        def handle_info(
              {:DOWN, ref, _, _, _},
              state = %{monitors: monitors, children: children}
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
                monitors: monitors,
                children: children,
                node_sup: node_sup,
                mfa: {m, f, a} = mfa,
                name: name
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

        # def handle_info(_info, state) do
        #   {:noreply, state}
        # end

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
            node_sup: node_sup,
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

    [imports, prepend, control, append]
  end
end
