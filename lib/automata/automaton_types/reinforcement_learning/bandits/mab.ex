<<i1::unsigned-integer-32, i2::unsigned-integer-32, i3::unsigned-integer-32>> =
  :crypto.strong_rand_bytes(12)

:rand.seed(:exsplus, {i1, i2, i3})

defmodule Automaton.Types.MAB do
  @moduledoc """
  Implements the Multi-Armed Bandit (MAB) state space representation (One State,
  many possible actions). Each bandit is goal-oriented, i.e. associated with a
  distinct, high-level goal which it attempts to achieve.

  MDP - many states, many actions
  Bandit - one state, many actions

  At each episode, an agent takes X actions in parallel and receives:
    • X local observations for decision making
  """

  # alias Automaton.Types.MAB.Config.Parser

  defmacro __using__(opts) do
    automaton_config = opts[:automaton_config]
    num_arms = automaton_config[:num_arms]
    num_ep = automaton_config[:num_ep]
    num_iter = automaton_config[:num_iter]
    tick_freq = automaton_config[:tick_freq]
    action_prob = automaton_config[:action_prob]

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
                    epsilon: :rand.uniform(),
                    # optional: apriori known ground truth action probability distribution as list
                    action_prob: unquote(action_prob),
                    optimal_action: nil,
                    num_arms: unquote(num_arms) || 12,
                    num_ep: unquote(num_ep) || 20,
                    num_iter: unquote(num_iter) || 1000,
                    c_action_tally: Matrex.zeros(unquote(num_ep), unquote(num_arms)),
                    c_estimation: Matrex.zeros(unquote(num_ep), unquote(num_arms)),
                    c_reward: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    c_optimal_action: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    c_regret_total: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    temp_expect: Matrex.zeros(1, unquote(num_arms)),
                    temp_action_tally: Matrex.zeros(1, unquote(num_arms)),
                    temp_estimation: Matrex.zeros(1, unquote(num_arms)),
                    temp_reward: Matrex.zeros(1, unquote(num_iter)),
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
        def init([agent_sup, {m, _, _} = mfa, state, name]) do
          Process.flag(:trap_exit, true)

          new_state = %{
            state
            | agent_sup: agent_sup,
              mfa: mfa,
              name: name
          }

          # send(self(), :start_composite_supervisor)

          {:ok, new_state}
        end
      end

    control =
      quote bind_quoted: [automaton_config: automaton_config] do
        def update(
              %{
                num_ep: num_ep,
                num_arms: num_arms,
                num_iter: num_iter,
                epsilon: epsilon,
                c_action_tally: c_action_tally,
                c_estimation: c_estimation,
                c_reward: c_reward,
                c_optimal_action: c_optimal_action,
                c_regret_total: c_regret_total,
                temp_expect: temp_expect,
                temp_action_tally: temp_action_tally,
                temp_estimation: temp_estimation,
                temp_reward: temp_reward,
                temp_optimal_action: temp_optimal_action,
                temp_regret: temp_regret
              } = state
            ) do
          {action_prob, optimal_action} = select_optimum(state)

          IO.inspect(['Best Choice: ', optimal_action, Matrex.at(action_prob, 1, optimal_action)])

          # Run Episodes to converge to optimal action
          episodic_state =
            run_episodes(%{
              state
              | action_prob: action_prob,
                optimal_action: optimal_action
            })

          print_result(action_prob, episodic_state)

          {:ok, episodic_state}
        end

        def run_episodes(
              %{
                num_iter: num_iter,
                num_ep: num_ep,
                action_prob: action_prob,
                optimal_action: optimal_action
              } = state
            ) do
          Enum.reduce(
            Range.new(1, num_ep),
            %State{} = state,
            fn episode, state ->
              # Explore Actions of episode
              explorer_state = explore_episode(num_iter, episode, state)
            end
          )
        end

        def explore_episode(num_iter, episode, %{optimal_action: optimal_action} = state) do
          Enum.reduce(Range.new(1, num_iter), %State{} = state, fn iter, action_state ->
            # select action & update action tally
            {curr_action, temp_action_tally, temp_optimal_action} =
              select_action(iter, optimal_action, action_state)

            # update reward & episodic reward estimate
            {temp_estimation, temp_reward, temp_expect} =
              update_reward(iter, curr_action, action_state)

            temp_regret = compute_regret(iter, curr_action, optimal_action, action_state)

            %{
              action_state
              | temp_action_tally: temp_action_tally,
                temp_estimation: temp_estimation,
                temp_reward: temp_reward,
                temp_optimal_action: temp_optimal_action,
                temp_regret: temp_regret,
                temp_expect: temp_expect,
                c_action_tally:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(action_state.c_action_tally),
                      episode,
                      Matrex.transpose(action_state.temp_action_tally)
                    )
                  ),
                c_estimation:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(action_state.c_estimation),
                      episode,
                      Matrex.transpose(action_state.temp_estimation)
                    )
                  ),
                c_reward:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(action_state.c_reward),
                      episode,
                      Matrex.transpose(action_state.temp_reward)
                    )
                  ),
                c_optimal_action:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(action_state.c_optimal_action),
                      episode,
                      Matrex.transpose(action_state.temp_optimal_action)
                    )
                  ),
                c_regret_total:
                  Matrex.transpose(
                    Matrex.set_column(
                      Matrex.transpose(action_state.c_regret_total),
                      episode,
                      Matrex.transpose(action_state.temp_regret)
                    )
                  ),
                status: :mab_running
            }
          end)
        end

        def update_reward(
              iter,
              curr_action,
              %{
                action_prob: action_prob,
                temp_estimation: temp_estimation,
                temp_action_tally: temp_action_tally,
                temp_reward: temp_reward,
                temp_expect: temp_expect
              } = action_state
            ) do
          reward_estimate = Matrex.at(temp_estimation, 1, curr_action)

          curr_reward =
            if(:rand.uniform() < Matrex.at(action_prob, 1, curr_action)) do
              1
            else
              0
            end

          reward_delta = curr_reward - reward_estimate
          hist_action_count = Matrex.at(temp_action_tally, 1, curr_action)
          weight = 1 / (hist_action_count + 1)
          action_value = reward_estimate + weight * reward_delta

          # keeps running average of rewards
          tmp_estimation = Matrex.set(temp_estimation, 1, curr_action, action_value)

          # update reward
          reward =
            if iter == 1 do
              curr_reward
            else
              Matrex.at(temp_reward, 1, iter - 1) + curr_reward
            end

          tmp_reward = Matrex.set(temp_reward, 1, iter, reward)
          tmp_expect = Matrex.add(temp_expect, curr_reward)

          {tmp_estimation, tmp_reward, tmp_expect}
        end

        def select_action(
              iter,
              optimal_action,
              %{
                num_arms: num_arms,
                epsilon: epsilon,
                temp_expect: temp_expect,
                temp_action_tally: temp_action_tally,
                temp_optimal_action: temp_optimal_action
              } = action_state
            ) do
          curr_action =
            if epsilon < :rand.uniform() do
              Matrex.argmax(temp_expect)
            else
              :rand.uniform(num_arms)
            end

          action_count = Matrex.at(temp_action_tally, 1, curr_action)
          tmp_action_count = Matrex.set(temp_action_tally, 1, curr_action, action_count + 1)

          action =
            if curr_action == optimal_action do
              1
            else
              0
            end

          # update optimal choice of action
          tmp_optimal_action = Matrex.set(temp_optimal_action, 1, iter, action)
          {curr_action, tmp_action_count, tmp_optimal_action}
        end

        # The regret of the learner relative to a policy π (not necessarily
        # that followed by the learner) is the difference between the total expected reward
        # using policy π for n rounds and the total expected reward collected by the learner
        # over n rounds. The regret relative to a set of policies Π is the maximum regret
        # relative to any policy π ∈ Π in the set.
        def compute_regret(iter, curr_action, optimal_action, %{
              action_prob: action_prob,
              temp_regret: temp_regret
            }) do
          regret_diff =
            Matrex.at(action_prob, 1, optimal_action) -
              Matrex.at(action_prob, 1, curr_action)

          regret =
            if iter == 1 do
              regret_diff
            else
              Matrex.at(temp_regret, 1, iter - 1) + regret_diff
            end

          Matrex.set(temp_regret, 1, iter, regret)
        end

        def select_optimum(%{action_prob: action_prob, num_arms: num_arms}) do
          action_prob =
            if action_prob do
              Matrex.new(action_prob)
            else
              Matrex.random(1, num_arms)
            end

          {action_prob, Matrex.argmax(action_prob)}
        end

        def print_result(action_prob, %{c_estimation: c_estimation} = episodic_state) do
          IO.puts("Ground Truth")
          IO.inspect(action_prob)

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
