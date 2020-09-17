defmodule Automaton.Types.MCSIM do
  @moduledoc """
  Implements a multi-agent state space representation to infer outcome
  possibilies using *Monte Carlo Simulation* for global optimal sequential
  decisioning. Very useful when the outcome depends on a sequence of actions and
  the total number of outcomes is too large for computation.

  On each global update, each agent makes an independent estimate of their
  future state(s) stochastically by sampling from some local population(s). At
  each stage in the "global population process" (or "reality check"), each agent
  samples from a population and subsequently takes an action to produce an
  estimation of the next state. The sample space can be **categorical**
  (*nominal and/or ordinal*), and/or **numerical** (*discrete or continuous*).

  Global decision making is thus achieved by inference based on the frequency
  distribution of estimated values made by the population of agents(a->) which
  consequently depend on the ontology and environment(s) within which all agents
  are deployed.

  Examines complex aggregations from simple actions, useful for problems where
  we can easily determine and measure the complete set of actions within the
  system but are unsure of the aggregate result. i.e. in f(x) = y, we know f and
  x, but not y.

  For example, in the continuous case using least squares regression — each
  agent updates using **y_i = Alpha + Beta * X_i + E_i**, *where **E_i** is normally
  distributed with mean 0 and variance sigma^2*.

  The meta-level control can communicate estimates produced by one or more MC_SIM
  agents to other agent(s), or as global decisioning signals.

  MCSIM can be defined with the tuple: { s, S, {A_i}, E, {Omega_i}, O, h}
    • s, the trial sample set acquired from a population
    • S, state vector for each agent with designated initial distribution b^0
    • A_i, each agents finite, comparable, and orderable set of actions
    • E, estimation model P(s'|s, a->). Computes pdf based on updated states,
      depends on agent vector a->
    • Omega_i, each agents finite set of observations (using the next state and the joint action)
    • O, the observation model: P(o|s', a->), depends on agent vector a->
    • L, dynamic vector assigning number of trials for each agent [a_i .. a_n]
    • h, horizon discount factor vector. Each agent assigned float in [0,1] to emphasize current and near future
      estimates on a per agent basis

  MCSIM
    • Model Free learning (no prior knowledge of state transition variables needed (MDP))
    • Alternative to *Bellman Equation Botstrapping*
    • Requires exploration/exploitation balance

    Pros:
      • Good for measuring the risk of future decisions
      • Efficient inference method for very large dimensional search spaces
      • Can emphasize exploration to emphasize correctness over efficiency
      • Simplification of complex systems
      • Demonstrates scalability and quality in a number of domains including games
        (i.e. Monte Carlo Tree Search (MCTS) with alphago, alphazero, muzero), finance,
        physics

    Cons:
      • Not good for examining simple actions from complex aggregations (i.e. in f(x) = y, we know y but don't know f or x)
      • Doesn't provide the most realistic result
      • Hard to communicate model (teams)
  """

  # alias Automaton.Types.MCSIM.Config.Parser
  defmacro __using__(opts) do
    automaton_config = opts[:automaton_config]
    s_size = automaton_config[:s_size]
    num_epoch = automaton_config[:num_epoch]
    num_ep = automaton_config[:num_ep]
    tick_freq = automaton_config[:tick_freq]

    prepend =
      quote do
        use GenServer

        defmodule State do
          defstruct name: nil,
                    status: :mab_fresh,
                    agent_sup: nil,
                    control: 0,
                    tick_freq: unquote(tick_freq) || 50,
                    mfa: nil,
                    s_size: unquote(s_size) || 30,
                    num_epoch: unquote(num_epoch) || 20,
                    num_ep: unquote(num_ep) || 1000,
                    epoch_num: nil,
                    ep_num: nil
        end

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

          # send(self(), :tick)

          {:ok, new_state}
        end
      end

    control =
      quote bind_quoted: [automaton_config: automaton_config] do
        def update(state) do
          state =
            state
            |> run_epochs

          {:ok, state}
        end

        def run_epochs(%{num_epoch: num_epoch} = state) do
          Enum.reduce(1..num_epoch, %State{} = state, fn epoch_num, state ->
            run_episode(%{state | epoch_num: epoch_num})
          end)
        end

        def run_episode(
              %{
                num_ep: num_ep,
                epoch_num: epoch_num
              } = state
            ) do
          Enum.reduce(1..num_ep, %State{} = state, fn ep_num, state ->
            state =
              %{state | ep_num: ep_num}
              |> aggregate_automata

            %{state | status: :mab_running}
          end)
        end

        def aggregate_automata(%{ep_num: ep_num} = state) do
          state
        end

        def tick(state) do
          init_state = if state.status != :mab_running, do: on_init(state), else: state

          {:ok, updated_state} = update(init_state)
          status = updated_state.status

          if status != :mab_running do
            on_terminate(updated_state)
          else
            if unquote(automaton_config[:num_epochs]) do
              schedule_next_tick(updated_state.tick_freq)
            end
          end

          {:ok, updated_state}
        end

        def schedule_next_tick(ms_delay) do
          Process.send_after(self(), :scheduled_tick, ms_delay)
        end

        def handle_info(:scheduled_tick, state) do
          {status, new_state} = tick(state)
          {:noreply, %{new_state | status: status}}
        end

        # async updates
        def handle_info(:tick, state) do
          {status, new_state} = tick(state)
          {:noreply, %{new_state | status: status}}
        end
      end

    append =
      quote do
        def on_init(state) do
          case state.status do
            :mab_fresh ->
              nil

            _ ->
              nil
          end

          state
        end

        def on_terminate(state) do
          case state.status do
            :mab_running ->
              IO.inspect("EPOCH TERMINATED - RUNNING",
                label: Process.info(self())[:registered_name]
              )

            :mab_failure ->
              IO.inspect("EPOCH TERMINATED - FAILED",
                label: Process.info(self())[:registered_name]
              )

            :mab_success ->
              IO.inspect(["EPOCH TERMINATED - SUCCEEDED"],
                label: Process.info(self())[:registered_name]
              )

            :mab_aborted ->
              IO.inspect("EPOCH TERMINATED - ABORTED",
                label: Process.info(self())[:registered_name]
              )

            :mab_fresh ->
              IO.inspect("EPOCH TERMINATED - FRESH",
                label: Process.info(self())[:registered_name]
              )
          end

          state.status
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
      end

    [prepend, control, append]
  end
end
