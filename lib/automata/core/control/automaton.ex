defmodule Automaton do
  @moduledoc """
    This is the primary user control interface to the Automata system. The
    configration parameters are used to inject the appropriate modules into the
    user-defined nodes based on their node_type and other options.

    Notes:
    Initialization and shutdown require extra care:
    on_init: receive extra parameters, fetch data from blackboard/utility,  make requests, etc..
    shutdown: free resources to not effect other actions

    TODO: store any currently processing nodes so they can be ticked directly
    within the behaviour tree engine rather than per tick traversal of the entire
    tree. Zipper Tree?
  """
  alias Automaton.Behavior
  alias Automaton.CompositeServer
  alias Automaton.ComponentServer

  defmacro __using__(user_opts) do
    prepend =
      quote do
        use Behavior, user_opts: unquote(user_opts)
      end

    c_types = CompositeServer.types()
    cn_types = ComponentServer.types()
    allowed_node_types = c_types ++ cn_types
    node_type = user_opts[:node_type]
    unless Enum.member?(allowed_node_types, node_type), do: raise("NodeTypeError")

    node_type =
      cond do
        Enum.member?(c_types, node_type) ->
          quote do: use(CompositeServer, user_opts: unquote(user_opts))

        Enum.member?(cn_types, node_type) ->
          quote do: use(ComponentServer, user_opts: unquote(user_opts))
      end

    control =
      quote bind_quoted: [user_opts: user_opts] do
        def tick(state) do
          init_state = if state.status != :bh_running, do: on_init(state), else: state

          {:ok, updated_state} = update(init_state)
          status = updated_state.status

          if status != :bh_running do
            on_terminate(status)
          else
            if !unquote(user_opts[:children]) do
              schedule_next_tick(updated_state.tick_freq)
            end
          end

          [status, updated_state]
        end

        def schedule_next_tick(ms_delay) do
          Process.send_after(self(), :scheduled_tick, ms_delay)
        end

        def handle_call(:tick, _from, state) do
          [status, new_state] = tick(state)
          {:reply, status, %{new_state | status: status}}
        end

        def handle_info(:scheduled_tick, state) do
          [status, new_state] = tick(state)
          {:noreply, %{new_state | status: status}}
        end

        # only called on components to get parent(composite) state
        def handle_cast({:initialize, parent_pid}, state) do
          parent_state = GenServer.call(parent_pid, :get_state)

          new_state =
            if !unquote(user_opts[:children]) do
              %{state | tick_freq: parent_state.tick_freq}
            else
              state
            end

          {:noreply, %{new_state | parent: parent_pid}}
        end

        def handle_call(:get_state, _from, state) do
          {:reply, state, state}
        end
      end

    [prepend, node_type, control]
  end
end
