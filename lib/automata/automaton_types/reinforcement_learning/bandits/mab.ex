<<i1::unsigned-integer-32, i2::unsigned-integer-32, i3::unsigned-integer-32>> =
  :crypto.strong_rand_bytes(12)

:rand.seed(:exsplus, {i1, i2, i3})

defmodule Automaton.Types.MAB do
  @moduledoc """
  Implements the Multi-Armed Bandit (MAB) state space representation (One State,
  many possible actions). Each bandit is goal-oriented, i.e. associated with a
  distinct, high-level goal which it attempts to achieve. A multi-armed bandit
  algorithm is designed to learn an optimal balance for allocating resources
  between a fixed number of choices, maximizing cumulative rewards over time by
  learning an efficient explore vs. exploit policy.

  Bandit - one state, many actions, non-sequential
  MDP - many states, many actions, sequential

  At each episode, an agent takes X actions in parallel and receives:
    • X local observations for decision making

  Greedy with optimistic initialization: We initialize the values of the actions
  to a highly optimistic value and assume that everything is good until proven
  otherwise. In the end, we suppress each action value to its realistic value.

  """

  # alias Automaton.Types.MAB.Config.Parser

  defmacro __using__(opts) do
    automaton_config = opts[:automaton_config]
    num_arms = automaton_config[:num_arms]
    num_ep = automaton_config[:num_ep]
    num_iter = automaton_config[:num_iter]
    tick_freq = automaton_config[:tick_freq]
    action_probs = automaton_config[:action_probs]

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
                    epsilon: 1.0,
                    decay: 0.99,
                    action_probs: unquote(action_probs),
                    optimal_action: nil,
                    num_arms: unquote(num_arms) || 12,
                    num_ep: unquote(num_ep) || 20,
                    num_iter: unquote(num_iter) || 1000,
                    ep_num: nil,
                    iter: nil,
                    curr_action: nil,
                    c_action_tally: Matrex.zeros(unquote(num_ep), unquote(num_arms)),
                    c_Q: Matrex.zeros(unquote(num_ep), unquote(num_arms)),
                    c_reward_hist: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    c_optimal_action: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    c_regret_total: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    temp_q_star: Matrex.zeros(1, unquote(num_arms)),
                    temp_action_tally: Matrex.zeros(1, unquote(num_arms)),
                    temp_Q: Matrex.zeros(1, unquote(num_arms)),
                    temp_cumulative_R: Matrex.zeros(1, unquote(num_iter)),
                    temp_optimal_action: Matrex.zeros(1, unquote(num_iter)),
                    temp_regret: Matrex.zeros(1, unquote(num_iter))
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
        def init([agent_sup, {m, _, _} = mfa, %{epsilon: epsilon} = state, name]) do
          Process.flag(:trap_exit, true)

          new_state = %{
            state
            | agent_sup: agent_sup,
              mfa: mfa,
              name: name
          }

          unless 0 <= epsilon and epsilon <= 1.0 do
            raise "Epsilon must be between 0 and 1"
          end

          # send(self(), :tick)

          {:ok, new_state}
        end
      end

    control =
      quote bind_quoted: [automaton_config: automaton_config] do
        def update(state) do
          {action_probs, optimal_action} = assign_prob(state)

          IO.inspect([
            'Best Choice: ',
            optimal_action,
            Matrex.at(action_probs, 1, optimal_action)
          ])

          state = %{
            state
            | action_probs: action_probs,
              optimal_action: optimal_action
          }

          state = run_episodes(state)

          print_result(action_probs, state)

          {:ok, state}
        end

        def run_episodes(%{num_ep: num_ep} = state) do
          Enum.reduce(1..num_ep, %State{} = state, fn ep_num, state ->
            run_episode(%{state | ep_num: ep_num})
          end)
        end

        def run_episode(
              %{
                num_iter: num_iter,
                ep_num: ep_num,
                optimal_action: optimal_action,
                epsilon: epsilon,
                decay: decay
              } = state
            ) do
          Enum.reduce(1..num_iter, %State{} = state, fn iter, state ->
            state =
              %{state | iter: iter}
              |> select_action()
              |> update_reward
              |> compute_regret

            %{
              state
              | epsilon: decay * epsilon,
                temp_regret: state.temp_regret,
                c_action_tally:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(state.c_action_tally),
                      ep_num,
                      Matrex.transpose(state.temp_action_tally)
                    )
                  ),
                c_Q:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(state.c_Q),
                      ep_num,
                      Matrex.transpose(state.temp_Q)
                    )
                  ),
                c_reward_hist:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(state.c_reward_hist),
                      ep_num,
                      Matrex.transpose(state.temp_cumulative_R)
                    )
                  ),
                c_optimal_action:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(state.c_optimal_action),
                      ep_num,
                      Matrex.transpose(state.temp_optimal_action)
                    )
                  ),
                c_regret_total:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(state.c_regret_total),
                      ep_num,
                      Matrex.transpose(state.temp_regret)
                    )
                  ),
                status: :mab_running
            }
          end)
        end

        def select_action(
              %{
                num_arms: num_arms,
                epsilon: epsilon,
                optimal_action: optimal_action,
                temp_q_star: temp_q_star,
                temp_action_tally: temp_action_tally,
                temp_optimal_action: temp_optimal_action,
                iter: iter
              } = state
            ) do
          state = determine_curr_action(state)

          # increment num times curr_action has been taken by 1
          state = incr_action_count(state)

          optimal_action_check(state)
        end

        def update_reward(
              %{
                action_probs: action_probs,
                temp_Q: temp_Q,
                temp_action_tally: temp_action_tally,
                temp_cumulative_R: temp_cumulative_R,
                temp_q_star: temp_q_star,
                curr_action: curr_action,
                iter: iter
              } = state
            ) do
          # action count
          action_count = Matrex.at(temp_action_tally, 1, curr_action)

          # q is an action value estimate based on avg reward for curr_action
          # i.e. a sample avg of first k rewards for curr_action
          q = Matrex.at(temp_Q, 1, curr_action)

          # curr_reward is 1 or 0
          curr_reward = reward_function(curr_action, state)

          # incrementally compute sample average. step size varies each step.
          # sample avg is not appropriate for non-stationarity. Use exponential,
          # recency-weighted average for non-stationarity One of the most
          # popular ways of doing this is to use a constant step-size
          # parameter.
          step_size = 1 / (action_count + 1)
          reward_gap = curr_reward - q
          # NewEstimate = OldEstimate + StepSize[Target – OldEstimate]
          new_q = q + step_size * reward_gap

          # update running average of reward probability
          # converges to q* over time
          temp_Q = Matrex.set(temp_Q, 1, curr_action, new_q)

          # update reward history
          reward =
            if iter == 1 do
              curr_reward
            else
              Matrex.at(temp_cumulative_R, 1, iter - 1) + curr_reward
            end

          temp_cumulative_R = Matrex.set(temp_cumulative_R, 1, iter, reward)

          # update expected reward for this action
          prev_q_star = Matrex.at(temp_q_star, 1, curr_action)

          temp_q_star = Matrex.set(temp_q_star, 1, curr_action, prev_q_star + curr_reward)

          %{
            state
            | temp_Q: temp_Q,
              temp_cumulative_R: temp_cumulative_R,
              temp_q_star: temp_q_star
          }
        end

        def reward_function(curr_action, %{action_probs: action_probs}) do
          action_prob = Matrex.at(action_probs, 1, curr_action)

          if(:rand.uniform() < action_prob) do
            1
          else
            0
          end
        end

        # regret: the deficit suffered relative to the optimal policy
        # i.e. how much worse this action was compared to how the
        # best-possible action would have performed in hindsight
        def compute_regret(
              %{
                action_probs: action_probs,
                temp_regret: temp_regret,
                iter: iter,
                curr_action: curr_action,
                optimal_action: optimal_action
              } = state
            ) do
          opportunity_loss =
            Matrex.at(action_probs, 1, optimal_action) -
              Matrex.at(action_probs, 1, curr_action)

          regret =
            if iter == 1 do
              opportunity_loss
            else
              Matrex.at(temp_regret, 1, iter - 1) + opportunity_loss
            end

          %{state | temp_regret: Matrex.set(temp_regret, 1, iter, regret)}
        end

        def assign_prob(%{action_probs: action_probs, num_arms: num_arms}) do
          action_probs =
            if action_probs do
              Matrex.new(action_probs)
            else
              Matrex.random(1, num_arms)
            end

          {action_probs, optimal_action = Matrex.argmax(action_probs)}
        end

        def incr_action_count(
              %{curr_action: curr_action, temp_action_tally: temp_action_tally} = state
            ) do
          action_count = Matrex.at(temp_action_tally, 1, curr_action)
          temp_action_tally = Matrex.set(temp_action_tally, 1, curr_action, action_count + 1)

          %{state | temp_action_tally: temp_action_tally}
        end

        def determine_curr_action(
              %{epsilon: epsilon, temp_q_star: temp_q_star, num_arms: num_arms} = state
            ) do
          # explore or exploit? (epsilon decays by .01 each iteration,
          # starting with lots of exploration but less so on each episode).
          curr_action =
            if epsilon < :rand.uniform() do
              # e-greedy
              Matrex.argmax(temp_q_star)
            else
              :rand.uniform(num_arms)
            end

          %{state | curr_action: curr_action}
        end

        def optimal_action_check(
              %{
                curr_action: curr_action,
                optimal_action: optimal_action,
                temp_optimal_action: temp_optimal_action,
                iter: iter
              } = state
            ) do
          policy_action =
            if curr_action == optimal_action do
              1
            else
              0
            end

          # mark col in vector corresponding to action as 1 or 0 (optimal or not)
          temp_optimal_action = Matrex.set(temp_optimal_action, 1, iter, policy_action)

          %{state | temp_optimal_action: temp_optimal_action}
        end

        def print_result(action_probs, %{c_Q: c_Q} = episodic_state) do
          IO.puts("Ground Truth")
          IO.inspect(action_probs)

          IO.puts("Expected")
          c_est = Matrex.to_list_of_lists(Matrex.transpose(c_Q))

          arr =
            c_est
            |> Stream.with_index()
            |> Enum.reduce([], fn {row, idx}, acc ->
              sum = Enum.sum(row)
              avg = sum / length(row)
              [avg | acc]
            end)

          IO.inspect(Enum.reverse(arr))
        end

        def tick(state) do
          init_state = if state.status != :mab_running, do: on_init(state), else: state

          {:ok, updated_state} = update(init_state)
          status = updated_state.status

          if status != :mab_running do
            on_terminate(updated_state)
          else
            if unquote(automaton_config[:episodic]) do
              schedule_next_tick(updated_state.tick_freq)
            end
          end

          {:ok, updated_state}
        end

        def schedule_next_tick(ms_delay) do
          Process.send_after(self(), :scheduled_tick, ms_delay)
        end

        def handle_info(:scheduled_tick, state) do
          [status, new_state] = tick(state)
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
            :mab_success ->
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
