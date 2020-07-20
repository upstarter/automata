# <<i1::unsigned-integer-32, i2::unsigned-integer-32, i3::unsigned-integer-32>> =
#   :crypto.strong_rand_bytes(12)
#
# :rand.seed(:exsplus, {i1, i2, i3})

defmodule Automaton.Types.MAB do
  @moduledoc """
  Implements the Multi-Armed Bandit (MAB) state space representation (One State,
  many possible actions). Each bandit is goal-oriented, i.e. associated with a
  distinct, high-level goal which it attempts to achieve.

  MDP - many states, many actions
  Bandit - one state, many actions

  At each stage, an agent takes X actions in parallel and receives:
    • X local observations for decision making
  """

  # alias Automaton.Types.MAB.Config.Parser

  defmacro __using__(opts) do
    automaton_config = opts[:automaton_config]
    num_arms = automaton_config[:num_arms]
    num_ep = automaton_config[:num_ep]
    num_iter = automaton_config[:num_iter]
    tick_freq = automaton_config[:tick_freq]

    prepend =
      quote do
        use GenServer

        defmodule State do
          defstruct name: nil,
                    status: :mab_fresh,
                    agent_sup: nil,
                    control: 0,
                    num_arms: unquote(num_arms) || 12,
                    num_ep: unquote(num_ep) || 20,
                    num_iter: unquote(num_iter) || 1000,
                    tick_freq: unquote(tick_freq) || 50,
                    mfa: nil,
                    c_action_count: Matrex.zeros(unquote(num_ep), unquote(num_arms)),
                    c_estimation: Matrex.zeros(unquote(num_ep), unquote(num_arms)),
                    c_reward: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    c_optimal_action: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    c_regret_total: Matrex.zeros(unquote(num_ep), unquote(num_iter)),
                    epsilon: :rand.uniform(),
                    gt_prob: Matrex.random(1, unquote(num_arms)),
                    temp_expect: Matrex.zeros(1, unquote(num_arms)),
                    temp_action_count: Matrex.zeros(1, unquote(num_arms)),
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
                # ground truth probability
                gt_prob: gt_prob,
                c_action_count: c_action_count,
                c_estimation: c_estimation,
                c_reward: c_reward,
                c_optimal_action: c_optimal_action,
                c_regret_total: c_regret_total,
                temp_expect: temp_expect,
                temp_action_count: temp_action_count,
                temp_estimation: temp_estimation,
                temp_reward: temp_reward,
                temp_optimal_action: temp_optimal_action,
                temp_regret: temp_regret
              } = state
            ) do
          # c.e. greedy
          optimal_choice = Matrex.argmax(gt_prob)

          IO.inspect(['Best Choice: ', optimal_choice, Matrex.at(gt_prob, 1, optimal_choice)])

          epoch_state =
            Enum.reduce(Range.new(1, num_ep), %State{} = state, fn episode, ep_state ->
              explored_state =
                Enum.reduce(Range.new(1, num_iter), %State{} = ep_state, fn iter, arm_state ->
                  # select bandit / get reward / increase count / update reward_estimate
                  curr_arm =
                    if epsilon < :rand.uniform() do
                      Matrex.argmax(arm_state.temp_expect)
                    else
                      :rand.uniform(num_arms)
                    end

                  curr_reward =
                    if(:rand.uniform() < Matrex.at(gt_prob, 1, curr_arm)) do
                      1
                    else
                      0
                    end

                  action_count = Matrex.at(arm_state.temp_action_count, 1, curr_arm)

                  temp_action_count =
                    Matrex.set(arm_state.temp_action_count, 1, curr_arm, action_count + 1)

                  reward_estimate = Matrex.at(arm_state.temp_estimation, 1, curr_arm)
                  reward_delta = curr_reward - reward_estimate

                  weight = 1 / (Matrex.at(arm_state.temp_action_count, 1, curr_arm) + 1)
                  value = reward_estimate + weight * reward_delta

                  temp_estimation = Matrex.set(arm_state.temp_estimation, 1, curr_arm, value)

                  # update reward and optimal choice
                  reward =
                    if iter == 1 do
                      curr_reward
                    else
                      Matrex.at(arm_state.temp_reward, 1, iter - 1) + curr_reward
                    end

                  # IO.inspect([
                  #   "reward",
                  #   iter,
                  #   curr_reward,
                  #   reward_estimate,
                  #   temp_action_count,
                  #   temp_estimation,
                  #   reward_delta,
                  #   value,
                  #   curr_arm,
                  #   reward
                  # ])

                  temp_reward = Matrex.set(arm_state.temp_reward, 1, iter, reward)

                  action =
                    if curr_arm == optimal_choice do
                      1
                    else
                      0
                    end

                  temp_optimal_action = Matrex.set(arm_state.temp_optimal_action, 1, iter, action)

                  regret_diff =
                    Matrex.at(gt_prob, 1, optimal_choice) - Matrex.at(gt_prob, 1, curr_arm)

                  regret =
                    if iter == 1 do
                      regret_diff
                    else
                      Matrex.at(arm_state.temp_regret, 1, iter - 1) + regret_diff
                    end

                  temp_regret = Matrex.set(arm_state.temp_regret, 1, iter, regret)

                  %{
                    arm_state
                    | temp_action_count: temp_action_count,
                      temp_estimation: temp_estimation,
                      temp_reward: temp_reward,
                      temp_optimal_action: temp_optimal_action,
                      temp_regret: temp_regret,
                      temp_expect: Matrex.add(arm_state.temp_expect, curr_reward)
                  }
                end)

              %{
                explored_state
                | c_action_count:
                    Matrex.transpose(
                      Matrex.set_column(
                        Matrex.transpose(explored_state.c_action_count),
                        episode,
                        Matrex.transpose(explored_state.temp_action_count)
                      )
                    ),
                  c_estimation:
                    Matrex.transpose(
                      Matrex.set_column(
                        Matrex.transpose(explored_state.c_estimation),
                        episode,
                        Matrex.transpose(explored_state.temp_estimation)
                      )
                    ),
                  c_reward:
                    Matrex.transpose(
                      Matrex.set_column(
                        Matrex.transpose(explored_state.c_reward),
                        episode,
                        Matrex.transpose(explored_state.temp_reward)
                      )
                    ),
                  c_optimal_action:
                    Matrex.transpose(
                      Matrex.set_column(
                        Matrex.transpose(explored_state.c_optimal_action),
                        episode,
                        Matrex.transpose(explored_state.temp_optimal_action)
                      )
                    ),
                  c_regret_total:
                    Matrex.transpose(
                      Matrex.set_column(
                        Matrex.transpose(explored_state.c_regret_total),
                        episode,
                        Matrex.transpose(explored_state.temp_regret)
                      )
                    ),
                  status: :mab_running
              }
            end)

          IO.puts("Ground Truth")
          IO.inspect(gt_prob)
          IO.puts("Expected")
          c_est = Matrex.to_list_of_lists(Matrex.transpose(epoch_state.c_estimation))

          arr =
            c_est
            |> Stream.with_index()
            |> Enum.reduce([], fn {row, idx}, acc ->
              sum = Enum.sum(row)
              avg = sum / length(row)
              [avg | acc]
            end)

          IO.inspect(Enum.reverse(arr))

          {:ok, epoch_state}
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