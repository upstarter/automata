defmodule Automata.Operator do
  @moduledoc """
  Sets the World in motion, meta-manages world operations.

  TODO:
  1. handle world failures with stacktrace, enable tracing/logging
  2. aggregate operational metrics
  """

  alias Automata.EventManager, as: EM

  def run(opts) when is_list(opts) do
    {:ok, manager} = EM.start_link()
    {:ok, stats_pid} = EM.add_handler(manager, Automata.OperatorStats, opts)
    config = configure(opts, manager, self(), stats_pid)

    # :erlang.system_flag(:backtrace_depth, Keyword.fetch!(opts, :stacktrace_depth))

    {_time, result} =
      :timer.tc(fn ->
        EM.world_started(config.manager, opts)
        spawn_world(config)
      end)

    EM.world_finished(config.manager, opts)
    _stats = Automata.OperatorStats.stats(stats_pid)
    EM.stop(config.manager)
    # after_world_callbacks = Application.fetch_env!(:automata, :after_world)
    # Enum.each(after_world_callbacks, fn callback -> callback.(stats) end)
    result
  end

  defp configure(opts, manager, runner_pid, stats_pid) do
    %{
      timeout: opts[:timeout],
      trace: opts[:trace],
      runner_pid: runner_pid,
      stats_pid: stats_pid,
      manager: manager,
      world: config()
    }
  end

  # TODO: handle spawning multi world, for now just singular case
  defp spawn_world(config) do
    EM.world_started(config.manager, config.world)

    _timeout = get_timeout(config, %{})

    {:ok, pid} = Automata.Supervisor.start_link(config.world)

    EM.world_finished(config.manager, config.world)

    send(config.runner_pid, {self(), :automata_finished})
    {:ok, pid}
  end

  defp get_timeout(config, tags) do
    if config.trace() do
      :infinity
    else
      Map.get(tags, :timeout, config.timeout)
    end
  end

  # TODO quick testing hack, fix by autoloading from user-defined modules
  defp config() do
    if Mix.env() == :test do
      %WorldConfig{
        world: [name: "TestMockWorld1", mfa: {TestMockWorld1, :start_link, []}],
        automata: [
          # these lists end up as `automaton_config` from  `Automata.Server` on in
          # the supervision tree (past the `Automata` Control Boundary Layer and
          # into the `Automaton` Control Boundary)
          [name: "TestMockSeq1", mfa: {TestMockSeq1, :start_link, []}]
          # [name: "TestMockSel1", mfa: {TestMockSel1, :start_link, []}]
        ]
      }
    else
      %WorldConfig{
        world: [name: "MockWorld1", mfa: {MockWorld1, :start_link, []}],
        automata: [
          # these lists end up as `automaton_config` from  `Automata.Server` on in
          # the supervision tree (past the `Automata` Control Boundary Layer and
          # into the `Automaton` Control Boundary)
          [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
          # [name: "MockSel1", mfa: {MockSel1, :start_link, []}]
        ]
      }
    end
  end
end
