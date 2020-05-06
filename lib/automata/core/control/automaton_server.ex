defmodule Automata.AutomatonServer do
  use GenServer

  defmodule State do
    defstruct automaton_sup: nil,
              node_sup: nil,
              monitors: nil,
              automaton: nil,
              name: nil,
              mfa: nil
  end

  def start_link([automaton_sup, node_config]) do
    GenServer.start_link(__MODULE__, [automaton_sup, node_config], name: name(node_config[:name]))
  end

  def status(tree_name) do
    GenServer.call(name(tree_name), :status)
  end

  #############
  # Callbacks #
  #############

  def init([automaton_sup, node_config]) when is_pid(automaton_sup) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])
    state = %State{automaton_sup: automaton_sup, monitors: monitors}

    init(node_config, state)
  end

  def init([{:name, name} | rest], state) do
    init(rest, %{state | name: name})
  end

  def init([{:mfa, mfa} | rest], state) do
    init(rest, %{state | mfa: mfa})
  end

  def init([], state) do
    send(self(), :start_node_supervisor)
    {:ok, state}
  end

  def init([_ | rest], state) do
    init(rest, state)
  end

  def handle_call(:status, _from, %{automaton: automaton, monitors: monitors} = state) do
    {:reply, {state, length(automaton)}, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, {:error, :invalid_message}, :ok, state}
  end

  def handle_cast({:failed, automaton}, %{monitors: monitors} = state) do
    case :ets.lookup(monitors, automaton) do
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
        state = %{automaton_sup: automaton_sup, name: name, mfa: mfa}
      ) do
    spec = {Automaton.NodeSupervisor, [[self(), mfa, name]]}
    {:ok, node_sup} = Supervisor.start_child(automaton_sup, spec)

    automaton = new_automaton(node_sup, mfa, name)
    {:noreply, %{state | node_sup: node_sup, automaton: automaton}}
  end

  def handle_info({:DOWN, ref, _, _, _}, state = %{monitors: monitors, automaton: automaton}) do
    case :ets.match(monitors, {:"$1", ref}) do
      [[pid]] ->
        true = :ets.delete(monitors, pid)
        new_state = %{state | automaton: [pid | automaton]}
        {:noreply, new_state}

      [[]] ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, node_sup, reason}, state = %{node_sup: node_sup}) do
    {:stop, reason, state}
  end

  def handle_info(
        {:EXIT, pid, _reason},
        state = %{
          monitors: monitors,
          automaton: automaton,
          node_sup: node_sup,
          mfa: mfa,
          name: name
        }
      ) do
    case :ets.lookup(monitors, pid) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = handle_automaton_exit(pid, state)
        {:noreply, new_state}

      [] ->
        # NOTE: Worker crashed, no monitor
        case Enum.member?(automaton, pid) do
          true ->
            remaining_automaton = automaton |> Enum.reject(fn p -> p == pid end)

            new_state = %{
              state
              | automaton: [new_automaton(node_sup, mfa, name) | remaining_automaton]
            }

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

  defp new_automaton(node_sup, {m, _f, a} = mfa, name) do
    spec = {m, [[node_sup, mfa, m]]}
    {:ok, automaton} = DynamicSupervisor.start_child(node_sup, spec)
    true = Process.link(automaton)
    automaton
  end

  defp dismiss_automaton(sup, pid) do
    true = Process.unlink(pid)
    DynamicSupervisor.terminate_child(sup, pid)
  end

  defp handle_automaton_exit(pid, state) do
    %{
      node_sup: node_sup,
      automaton: automaton,
      monitors: monitors
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
