defmodule Automaton.Types.DECPOMDP do
  @moduledoc """
  Implements the Decentralized Partially Observable Markov Decision Process (DEC-POMDP) state space representation.
  Each agent is goal-oriented, i.e. associated with a distinct, high-level goal
  which it attempts to achieve.

  At each stage, each agent takes an action and receives:
    • A local observation for local decision making
    • A joint immediate reward

  DECPOMDP's can be defined with the tuple: { I, S, {A_i}, T, R, {Omega_i}, O }
    • I, a finite set of agents
    • S, a finite set of states with designated initial distribution b^0
    • A_i, each agents finite set of actions
    • T, the state transition model: P(s'|s,a->), depends on all agents
    • R, the reward model, depends on all agents
    • Omeaga_i, each agents finite set of observations
    • O, the observation model: P(o|s',a->), depends on all agents
    • h, horizon or discount factor

  DECPOMDP
    • considers outcome, sensory, and communication uncertainty in a single
  framework
    • Can model any multi-agent coordination problem
    • Macro-actions provide an sbstraction to improve scalability
    • Learning methods can remove the need to generate a details multi-agent model
    • Methods also apply when less uncertainty
    • Begun demonstrating scalability and quality in a number of domains, but a lot
    of great open questions to solve

  """
  alias Automaton.Types.DECPOMDP.Config.Parser

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
            if !unquote(automaton_config[:children]) do
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
