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

        # TODO: when/if too much state, probably handle state somewhere
        # else? GenServer linked to Node w/ cc?
        defmodule State do
          # status is :bh_fresh when composite not initialized yet or has been reset
          # name is "UserDefinedModuleName" + "Server"
          defstruct name: nil,
                    status: :bh_fresh,
                    children: unquote(user_opts[:children]),
                    # workers are the pids of the running children
                    workers: [],
                    composite_sup: nil,
                    agent_sup: nil,
                    node_type: unquote(user_opts[:node_type]),
                    # parent is nil when fresh
                    parent: nil,
                    control: 0,
                    tick_freq: unquote(user_opts[:tick_freq]) || 50,
                    monitors: nil,
                    mfa: nil
        end
      end

    control =
      quote bind_quoted: [user_opts: opts[:user_opts]] do
        # Client API
        def start_link([agent_sup, {_, _, _} = mfa, name]) do
          new_name = to_string(name) <> "Server"

          GenServer.start_link(__MODULE__, [agent_sup, mfa, %State{}, new_name],
            name: String.to_atom(new_name)
          )
        end

        # #######################
        # # GenServer Callbacks #
        # #######################
        def init([agent_sup, {m, _, _} = mfa, state, name]) do
          Process.flag(:trap_exit, true)

          new_state = %{
            state
            | agent_sup: agent_sup,
              mfa: mfa,
              name: name
          }

          send(self(), :start_composite_supervisor)

          {:ok, new_state}
        end

        def handle_info(
              :start_composite_supervisor,
              state = %{agent_sup: agent_sup, mfa: mfa, name: name}
            ) do
          spec = {Automaton.CompositeSupervisor, [[self(), mfa, name]]}
          {:ok, composite_sup} = DynamicSupervisor.start_child(agent_sup, spec)
          new_state = %{state | composite_sup: composite_sup}

          send(self(), :start_children)

          {:noreply, new_state}
        end

        def handle_info(:start_children, state) do
          {:reply, :ok, new_state} = start_children(state)

          {:noreply, new_state}
        end

        def handle_info(:update, state) do
          {:noreply, %{state | status: update(state)}}
        end

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
          GenServer.cast(node, {:initialize, self()})
          node
        end
      end

    append =
      quote do
        def handle_info({:EXIT, pid, reason}, state = %{workers: workers}) do
          IO.puts("EXIT Composite 1")
          {:stop, reason, state}
        end

        def handle_info(
              {:EXIT, pid, _reason},
              state = %{
                workers: workers,
                children: children,
                agent_sup: agent_sup,
                mfa: {m, f, a} = mfa,
                name: name
              }
            ) do
          IO.inspect([
            "EXIT Composite 2",
            "#{Process.info(self())[:registered_name]}"
          ])

          # NOTE: child crashed, no monitor
          case Enum.member?(workers, pid) do
            true ->
              remaining_workers = workers |> Enum.reject(fn p -> p == pid end)

              new_state = %{
                state
                | workers: [
                    start_node(agent_sup, {m, :start_link, [[self(), mfa, name]]})
                    | workers
                  ]
              }

              {:noreply, new_state}

            false ->
              {:noreply, state}
          end
        end

        defp handle_child_exit(pid, state) do
          %{
            agent_sup: agent_sup,
            workers: workers,
            monitors: monitors
          } = state

          # TODO: since non-homogenous children, need to add new worker of same type back into worker list
          # Process.info(pid)[:registered_name]

          # retry anything other than :bh_failure?
          # 1. User defines retry? with default(s)?
          # - 2.
          #   - sequence: retry - how often?, how long?
          #   - selector: no retries? user can select?
        end

        def terminate(_reason, _state) do
          IO.puts("Terminate")
          :ok
        end

        # notifies listeners if child status is not :bh_fresh
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

        #####################
        # Private Functions #
        #####################

        defp name(tree_name) do
          :"#{tree_name}Server"
        end

        def child_spec([[agent_sup, {m, _f, a}, name]] = args) do
          %{
            id: to_string(name) <> "Server",
            start: {__MODULE__, :start_link, args},
            shutdown: 10_000,
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
