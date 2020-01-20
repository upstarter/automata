defmodule Automata.AutomatonServer do
  use GenServer
  use DynamicSupervisor

  defmodule State do
    defstruct node_sup: nil,
              worker_sup: nil,
              monitors: nil,
              size: nil,
              workers: nil,
              name: nil,
              mfa: nil
  end

  def start_link([node_sup, node_config]) do
    GenServer.start_link(__MODULE__, [node_sup, node_config], name: name(node_config[:name]))
  end

  def status(tree_name) do
    GenServer.call(name(tree_name), :status)
  end

  #############
  # Callbacks #
  ############ j

  def init([node_sup, node_config]) when is_pid(node_sup) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])
    state = %State{node_sup: node_sup, monitors: monitors}

    init(node_config, state)
  end

  def init([{:name, name} | rest], state) do
    init(rest, %{state | name: name})
  end

  def init([{:mfa, mfa} | rest], state) do
    init(rest, %{state | mfa: mfa})
  end

  def init([{:size, size} | rest], state) do
    init(rest, %{state | size: size})
  end

  def init([], state) do
    send(self(), :start_node_supervisor)
    {:ok, state}
  end

  def init([_ | rest], state) do
    init(rest, state)
  end

  def handle_call(:status, _from, %{workers: workers, monitors: monitors} = state) do
    {:reply, {state, length(workers), :ets.info(monitors, :size)}, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, {:error, :invalid_message}, :ok, state}
  end

  def handle_cast({:failed, worker}, %{monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        {:noreply, state}

      [] ->
        {:noreply, state}
    end
  end

  def handle_info(
        :start_node_supervisor,
        state = %{node_sup: node_sup, name: name, mfa: mfa, size: size}
      ) do
    spec = {Automata.NodeSupervisor, [[self(), mfa, name]]}
    {:ok, worker_sup} = Supervisor.start_child(node_sup, spec)

    workers = prepopulate(size, worker_sup)
    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  def handle_info({:DOWN, ref, _, _, _}, state = %{monitors: monitors, workers: workers}) do
    case :ets.match(monitors, {:"$1", ref}) do
      [[pid]] ->
        true = :ets.delete(monitors, pid)
        new_state = %{state | workers: [pid | workers]}
        {:noreply, new_state}

      [[]] ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, worker_sup, reason}, state = %{worker_sup: worker_sup}) do
    {:stop, reason, state}
  end

  def handle_info(
        {:EXIT, pid, _reason},
        state = %{monitors: monitors, workers: workers, worker_sup: worker_sup}
      ) do
    case :ets.lookup(monitors, pid) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = handle_worker_exit(pid, state)
        {:noreply, new_state}

      [] ->
        # NOTE: Worker crashed, no monitor
        case Enum.member?(workers, pid) do
          true ->
            remaining_workers = workers |> Enum.reject(fn p -> p == pid end)
            new_state = %{state | workers: [new_worker(worker_sup) | remaining_workers]}
            {:noreply, new_state}

          false ->
            {:noreply, state}
        end
    end
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  #####################
  # Private Functions #
  #####################

  defp name(tree_name) do
    :"#{tree_name}Server"
  end

  defp prepopulate(size, sup) do
    prepopulate(size, sup, [])
  end

  defp prepopulate(size, _sup, workers) when size < 1 do
    workers
  end

  defp prepopulate(size, sup, workers) do
    prepopulate(size - 1, sup, [new_worker(sup) | workers])
  end

  defp new_worker(sup) do
    spec = {Automata.Automaton, []}
    {:ok, worker} = DynamicSupervisor.start_child(sup, spec)
    true = Process.link(worker)
    worker
  end

  # NOTE: We use this when we have to queue up the consumer
  defp new_worker(sup, from_pid) do
    pid = new_worker(sup)
    ref = Process.monitor(from_pid)
    {pid, ref}
  end

  defp dismiss_worker(sup, pid) do
    true = Process.unlink(pid)
    DynamicSupervisor.terminate_child(sup, pid)
  end

  defp handle_worker_exit(pid, state) do
    %{
      worker_sup: worker_sup,
      workers: workers,
      monitors: monitors,
      overflow: overflow
    } = state

    # TODO
  end

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]}
    }
  end
end
