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
  alias Automaton.CompositeSupervisor
  alias Automaton.Composite.{Sequence, Selector}

  # a composite is just an array of behaviors
  @callback add_child(term) :: {:ok, list} | {:error, String.t()}
  @callback remove_child(term) :: {:ok, list} | {:error, String.t()}
  @callback clear_children :: {:ok, term} | {:error, String.t()}
  @callback terminal_status() :: atom

  @types [:sequence, :selector]
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
                    c_children: unquote(user_opts[:children]) || nil,
                    c_status: :bh_fresh,
                    # control is the parent, nil when fresh
                    c_control: nil,
                    c_current: nil,
                    c_tick_freq: unquote(user_opts[:tick_freq]) || 0,
                    c_mfa: nil,
                    c_name: __MODULE__
        end

        # Client API
        def start_link([[node_sup, {_, _, _} = mfa, name]]) do
          GenServer.start_link(__MODULE__, [node_sup, mfa, %State{}, name], name: __MODULE__)
        end

        # #######################
        # # GenServer Callbacks #
        # #######################
        # TODO: Move all this out or make this the CompositeServer
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
          IO.inspect(['CompositeServer', String.to_atom("#{__MODULE__}"), name, self(), node_sup, mfa, state])

          # send(self(), :start_children)
          {:ok, state}
        end

        # def start_node_supervisor(node_sup, mfa, state) do
        #   spec = {Automaton.CompositeSupervisor, [[self(), mfa, __MODULE__]]}
        #   {:ok, bt_sup} = DynamicSupervisor.start_child(node_sup, spec)
        #
        #   {:noreply, %{state | c_control: bt_sup}}
        # end

        def handle_info(
              :start_node_supervisor,
              state = %{c_node_sup: node_sup, c_mfa: mfa, c_name: name}
            ) do

          spec = {Automaton.CompositeSupervisor, [[self(), mfa, name]]}

          {:ok, composite_sup} = DynamicSupervisor.start_child(node_sup, spec)
          IO.inspect(['Comp', self(), node_sup, spec])

          {:noreply, %{state | c_composite_sup: composite_sup}}
        end

        # def start_children(%{c_children: [current | remaining]} = state) do
        #   node = start_node(CompositeSupervisor, {current, :start_link, []})
        #   new_state = %{state | c_children: remaining, c_control: __MODULE__}
        #   IO.inspect(['Start BT', state, new_state, node])
        #
        #   start_children(new_state)
        # end

        def handle_info(
              :start_children,
              state = %{c_children: [current | remaining], c_node_sup: node_sup, c_mfa: mfa}
            ) do
          IO.inspect(['Start BT', state, node_sup])

          node = start_node(CompositeSupervisor, {current, :start_link, []})
          state = %{state | c_children: remaining}

          send(self(), :start_children)
          {:noreply, state}
        end

        defp start_node(bt_sup, {m, _f, a} = mfa) do
          # {:ok, worker} = DynamicSupervisor.start_child(bt_sup, {m, a})

          spec = {m, [[self(), mfa]]}
          {:ok, worker} = DynamicSupervisor.start_child(bt_sup, spec)
          true = Process.link(worker)
          worker
        end
      end

    bh_tree_control =
      quote bind_quoted: [user_opts: opts[:user_opts]] do
        def process_children(%{c_children: [current | remaining]} = state) do
          {:reply, state, new_state} = current.tick(state)

          status = new_state.c_status

          if status != terminal_status() do
            new_state
          else
            process_children(%{state | c_children: remaining})
          end
        end

        def process_children(%{c_children: []} = state) do
          %{state | c_status: terminal_status()}
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
        def child_spec(opts) do
          %{
            id: __MODULE__,
            start: {__MODULE__, :start_link, [opts]},
            type: :worker,
            restart: :permanent,
            shutdown: 500
          }
        end

        # Defoverridable makes the given functions in the current module overridable
        # defoverridable update: 1, on_init: 1, on_terminate: 1
      end

    [imports, prepend, bh_tree_control, append]
  end
end
