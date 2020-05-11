defmodule Automaton.Types.BehaviorTree do
  @moduledoc """
  Implements the BehaviorTree state space representation.
  """
  alias Automaton.CompositeServer
  alias Automaton.ComponentServer
  alias Automaton.Config.Parser
  alias Automaton.Behavior

  defmacro __using__(opts) do
    user_opts = opts[:user_opts]

    c_types = CompositeServer.types()
    cn_types = ComponentServer.types()
    node_type = Parser.node_type(user_opts)

    prepend =
      quote do
        use Behavior, user_opts: unquote(user_opts)
      end

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
            on_terminate(updated_state)
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

        # called on startup to access parent's state
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
