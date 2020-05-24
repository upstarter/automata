defmodule Automaton.Types.BT do
  @moduledoc """
  Implements the Behavior Tree (BT) state space representation.
  Each tree is goal-oriented, i.e. associated with a distinct, high-level goal
  which it attempts to achieve.

  Behavior trees are a unique combination of state space representation
  (graphical, or tree) and action-selection decision scheme with plugin
  variations, where the user can choose or customize the logic for traversal and
  lifecycle management.

  ## Notes:
    - Initialization and shutdown require extra care:
      - on_init: receive extra parameters, fetch data from blackboard/utility,  make requests, etc..
      - shutdown: free resources to not effect other actions

  TODO: store any currently processing nodes along with any nodes with monitor decorators
  so when monitors are activated, reactivity is achieved.
  Use Zipper Tree to store both?
  """
  alias Automaton.Types.BT.CompositeServer
  alias Automaton.Types.BT.ComponentServer
  alias Automaton.Types.BT.Config.Parser
  alias Automaton.Types.BT.Behavior

  defmacro __using__(opts) do
    automaton_config = opts[:automaton_config]

    {node_type, c_types, cn_types} = Parser.call(automaton_config)

    prepend =
      quote do
        use Behavior, automaton_config: unquote(automaton_config)
      end

    node_type =
      cond do
        Enum.member?(c_types, node_type) ->
          quote do: use(CompositeServer, automaton_config: unquote(automaton_config))

        Enum.member?(cn_types, node_type) ->
          quote do: use(ComponentServer, automaton_config: unquote(automaton_config))
      end

    control =
      quote bind_quoted: [automaton_config: automaton_config] do
        def tick(state) do
          init_state = if state.status != :bh_running, do: on_init(state), else: state

          {:ok, updated_state} = update(init_state)
          status = updated_state.status

          if status != :bh_running do
            on_terminate(updated_state)
          else
            if !unquote(automaton_config[:children]) && Mix.env() != :test do
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
            if !unquote(automaton_config[:children]) do
              %{state | tick_freq: parent_state.tick_freq}
            else
              state
            end

          {:noreply, %{new_state | parent: parent_pid}}
        end

        def handle_call(:get_state, _from, state) do
          {:reply, state, state}
        end

        ## Behavior @behaviour, here because its not working in the module itself

        def handle_call(:status, _from, state) do
          {:reply, state.status, state}
        end

        def handle_call(:set_running, _from, state) do
          {:reply, :ok, %{state | status: :bh_running}}
        end

        def handle_call(:succeed, _from, state) do
          {:reply, :ok, %{state | status: :bh_success}}
        end

        def handle_call(:fail, _from, state) do
          {:reply, :ok, %{state | status: :bh_failure}}
        end

        def handle_call(:running?, _from, state) do
          {:reply, state.status == :bh_running, state}
        end

        def handle_call(:aborted?, _from, state) do
          {:reply, state.status == :bh_aborted, state}
        end

        def handle_call(:terminated?, _from, state) do
          status = state.status
          {:reply, status == :bh_success || status == :bh_failure, state}
        end

        def handle_call(:abort, _from, state) do
          on_terminate(state)
          {:reply, true, %{state | status: :bh_aborted}}
        end

        def handle_call(:reset, _from, state) do
          {:reply, true, %{state | status: :bh_invalid}}
        end

        # Defoverridable makes the given functions in the current module overridable
        defoverridable update: 1, on_init: 1, on_terminate: 1
      end

    [prepend, node_type, control]
  end
end
