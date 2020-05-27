defmodule Automata.OperatorStats do
  @moduledoc false

  use GenServer

  alias Automata.FailuresManifest

  @typep counter :: non_neg_integer

  @spec stats(pid) :: %{
          failures: counter,
          total: counter
        }

  def stats(pid) when is_pid(pid) do
    GenServer.call(pid, :stats, :infinity)
  end

  @spec get_failure_counter(pid) :: counter
  def get_failure_counter(sup) when is_pid(sup) do
    GenServer.call(sup, :get_failure_counter)
  end

  @spec increment_failure_counter(pid) :: pos_integer
  def increment_failure_counter(sup, increment \\ 1)
      when is_pid(sup) and is_integer(increment) and increment >= 1 do
    GenServer.call(sup, {:increment_failure_counter, increment})
  end

  # Callbacks

  def init(opts) do
    state = %{
      total: 0,
      failures: 0,
      failures_manifest_file: opts[:failures_manifest_file],
      failures_manifest: FailuresManifest.new(),
      failure_counter: 0,
      pids: []
    }

    {:ok, state}
  end

  def handle_call(:stats, _from, state) do
    stats = Map.take(state, [:total, :failures])
    {:reply, stats, state}
  end

  def handle_call(:get_failure_counter, _from, state) do
    {:reply, state.failure_counter, state}
  end

  def handle_call({:increment_failure_counter, increment}, _from, state) do
    %{failure_counter: failure_counter} = state
    {:reply, failure_counter, %{state | failure_counter: failure_counter + increment}}
  end

  def handle_cast({:automaton_finished, Automaton = automaton}, state) do
    state =
      state
      |> Map.update!(:failures_manifest, &FailuresManifest.put_automaton(&1, automaton))
      |> Map.update!(:total, &(&1 + 1))
      |> increment_status_counter(automaton.state)

    {:noreply, state}
  end

  def handle_cast({:world_started, _opts}, %{failures_manifest_file: file} = state)
      when is_binary(file) do
    state = %{state | failures_manifest: FailuresManifest.read(file)}
    {:noreply, state}
  end

  def handle_cast({:world_finished, _, _}, %{failures_manifest_file: file} = state)
      when is_binary(file) do
    FailuresManifest.write!(state.failures_manifest, file)
    {:noreply, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  defp increment_status_counter(state, {tag, _}) when tag in [:aborted] do
    Map.update!(state, :failures, &(&1 + 1))
  end

  defp increment_status_counter(state, _), do: state
end
