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

  Bandit - one state, many actions
  MDP - many states, many actions

  At each episode, an agent takes X actions in parallel and receives:
    • X local observations for decision making

  We distinguish three types of feedback:
    - bandit feedback, when the algorithm observes the reward for the chosen arm, and no other feedback
    - full feedback, when the algorithm observes the rewards for all arms that could have been chosen
    - partial feedback, when some information is revealed, in addition to the
      reward of the chosen arm, but it does not always amount to full feedback.
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
                    # optional: apriori known ground truth action probability distribution as list
                    action_probs: unquote(action_probs),
                    optimal_action: nil,
                    num_arms: unquote(num_arms) || 12,
                    num_ep: unquote(num_ep) || 20,
                    num_iter: unquote(num_iter) || 1000,
                    ep_num: nil,
                    c_action_tally: Matrex.zeros(unquote(num_ep), unquote(num_arms)),
                    c_estimation: Matrex.zeros(unquote(num_ep), unquote(num_arms)),
                    c_reward: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    c_optimal_action: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    c_regret_total: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    temp_reward_expect: Matrex.zeros(1, unquote(num_arms)),
                    temp_action_tally: Matrex.zeros(1, unquote(num_arms)),
                    temp_estimation: Matrex.zeros(1, unquote(num_arms)),
                    temp_reward_hist: Matrex.zeros(1, unquote(num_iter)),
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

          IO.inspect(['Best Choice: ', optimal_action, Matrex.at(action_probs, 1, optimal_action)])

          # Run Episodes to converge to optimal action
          state =
            run_episodes(%{
              state
              | action_probs: action_probs,
                optimal_action: optimal_action
            })

          print_result(action_probs, state)

          {:ok, state}
        end

        def select_action(
              iter,
              %{
                num_arms: num_arms,
                epsilon: epsilon,
                optimal_action: optimal_action,
                temp_reward_expect: temp_reward_expect,
                temp_action_tally: temp_action_tally,
                temp_optimal_action: temp_optimal_action
              } = state
            ) do
          # explore or exploit? (epsilon decays by .01 each iteration,
          # starting with lots of exploration but less so on each episode).
          curr_action =
            if epsilon < :rand.uniform() do
              # e-greedy
              Matrex.argmax(temp_reward_expect)
            else
              :rand.uniform(num_arms)
            end

          # update num times action has been taken
          action_count = Matrex.at(temp_action_tally, 1, curr_action)
          tmp_times_action_taken = Matrex.set(temp_action_tally, 1, curr_action, action_count + 1)

          # is curr_action optimal?
          policy_action =
            if curr_action == optimal_action do
              1
            else
              0
            end

          # mark col in vector corresponding to action as 1 or 0 (optimal or not)
          tmp_optimal_action = Matrex.set(temp_optimal_action, 1, iter, policy_action)
          {curr_action, tmp_times_action_taken, tmp_optimal_action}
        end

        def update_reward(
              iter,
              curr_action,
              %{
                action_probs: action_probs,
                temp_estimation: temp_estimation,
                temp_action_tally: temp_action_tally,
                temp_reward_hist: temp_reward_hist,
                temp_reward_expect: temp_reward_expect
              } = state
            ) do
          # pursuit algorithm for value estimates
          # reward assignment count
          k = Matrex.at(temp_action_tally, 1, curr_action)

          # q is an action value estimate based on avg reward for k
          # i.e. a sample avg of first k rewards for curr_action
          # sample avg not appropriate for non-stationarity
          # use exponential, recency-weighted average for non-stationarity
          q = Matrex.at(temp_estimation, 1, curr_action)

          # curr_reward is 1 or 0
          curr_reward = reward_function(curr_action, state)
          step_size = 1 / (k + 1)
          reward_delta = curr_reward - q
          # NewEstimate = OldEstimate + StepSize[Target – OldEstimate]
          new_q = q + step_size * reward_delta

          # keeps running average of reward probability
          temp_estimation = Matrex.set(temp_estimation, 1, curr_action, new_q)

          # update reward history
          reward =
            if iter == 1 do
              curr_reward
            else
              Matrex.at(temp_reward_hist, 1, iter - 1) + curr_reward
            end

          temp_reward_hist = Matrex.set(temp_reward_hist, 1, iter, reward)

          # update expected reward for this action
          reward_expect = Matrex.at(temp_reward_expect, 1, curr_action)

          temp_reward_expect =
            Matrex.set(temp_reward_expect, 1, curr_action, reward_expect + curr_reward)

          {temp_estimation, temp_reward_hist, temp_reward_expect}
        end

        def reward_function(curr_action, %{action_probs: action_probs}) do
          action_prob = Matrex.at(action_probs, 1, curr_action)

          if(:rand.uniform() < action_prob) do
            1
          else
            0
          end
        end

        def run_episodes(%{num_ep: num_ep} = state) do
          Enum.reduce(Range.new(1, num_ep), %State{} = state, fn ep_num, state ->
            run_episode(%{state | ep_num: ep_num})
          end)
        end

        def run_episode(
              %{
                num_iter: num_iter,
                ep_num: ep_num,
                optimal_action: optimal_action,
                epsilon: epsilon
              } = state
            ) do
          Enum.reduce(Range.new(1, num_iter), %State{} = state, fn iter, state ->
            # select action & update action tally
            {curr_action, temp_action_tally, temp_optimal_action} = select_action(iter, state)

            # update reward & episodic reward estimate
            {temp_estimation, temp_reward_hist, temp_reward_expect} =
              update_reward(iter, curr_action, state)

            temp_regret = compute_regret(iter, curr_action, optimal_action, state)

            # update state for this episode
            %{
              state
              | epsilon: 0.99 * epsilon,
                temp_action_tally: temp_action_tally,
                temp_estimation: temp_estimation,
                temp_reward_hist: temp_reward_hist,
                temp_optimal_action: temp_optimal_action,
                temp_regret: temp_regret,
                temp_reward_expect: temp_reward_expect,
                c_action_tally:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(state.c_action_tally),
                      ep_num,
                      Matrex.transpose(state.temp_action_tally)
                    )
                  ),
                c_estimation:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(state.c_estimation),
                      ep_num,
                      Matrex.transpose(state.temp_estimation)
                    )
                  ),
                c_reward:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(state.c_reward),
                      ep_num,
                      Matrex.transpose(state.temp_reward_hist)
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

        # regret: the deficit suffered relative to the optimal policy
        # i.e. how much worse this action was compared to how the
        # best-possible action would have performed in hindsight
        def compute_regret(iter, curr_action, optimal_action, %{
              action_probs: action_probs,
              temp_regret: temp_regret
            }) do
          regret_deficit =
            Matrex.at(action_probs, 1, optimal_action) -
              Matrex.at(action_probs, 1, curr_action)

          regret =
            if iter == 1 do
              regret_deficit
            else
              Matrex.at(temp_regret, 1, iter - 1) + regret_deficit
            end

          Matrex.set(temp_regret, 1, iter, regret)
        end

        def assign_prob(%{action_probs: action_probs, num_arms: num_arms}) do
          action_probs =
            if action_probs do
              Matrex.new(action_probs)
            else
              Matrex.random(1, num_arms)
            end

          {action_probs, Matrex.argmax(action_probs)}
        end

        def print_result(action_probs, %{c_estimation: c_estimation} = episodic_state) do
          IO.puts("Ground Truth")
          IO.inspect(action_probs)

          IO.puts("Expected")
          c_est = Matrex.to_list_of_lists(Matrex.transpose(c_estimation))

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

    #
    [prepend, control, append]
  end
end
