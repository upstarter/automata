defmodule Automata.Operator do
  @moduledoc """
  Sets the World(s) in motion, meta-manages world(s) operations.

  TODO:
  1. handle automata failures with stacktrace, enable tracing/logging
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
        loop(config)
      end)

    EM.world_finished(config.manager, opts)
    _stats = Automata.OperatorStats.stats(stats_pid)
    EM.stop(config.manager)
    # after_automata_callbacks = Application.fetch_env!(:automata, :after_automata)
    # Enum.each(after_automata_callbacks, fn callback -> callback.(stats) end)
    result
  end

  defp configure(opts, manager, runner_pid, stats_pid) do
    %{
      timeout: opts[:timeout],
      trace: opts[:trace],
      capture_log: opts[:capture_log],
      runner_pid: runner_pid,
      stats_pid: stats_pid,
      manager: manager,
      worlds: config()
    }
  end

  defp config() do
    [
      %WorldConfig{
        world: [name: "MockWorld1", mfa: {MockWorld1, :start_link, []}],
        automata_config: [
          # these lists end up as `automaton_config` from  `Automata.Server` on in
          # the supervision tree (past the `Automata` Control Boundary Layer and
          # into the `Automaton` Control Boundary)
          [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
          # [name: "MockSel1", mfa: {MockSel1, :start_link, []}]
        ]
      }
    ]
  end

  defp loop(config) do
    spawn_worlds(config, config.worlds, nil)
  end

  defp spawn_worlds(config, [world | rest], _pid) do
    {:ok, pid} = start_world(config, world)
    spawn_worlds(config, rest, pid)
  end

  defp spawn_worlds(_config, [], pid) do
    {:ok, pid}
  end

  # TODO: handle spawning multi worlds, for now just singular case
  defp start_world(config, world) do
    EM.world_started(config.manager, world)

    _timeout = get_timeout(config, %{})
    {:ok, pid} = Automata.Supervisor.start_link(world.automata_config)

    EM.world_finished(config.manager, world)

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
end
