defmodule Automaton.AgentServer do
  @moduledoc """
  Parses each individual agent config from the user and starts it under the `AgentSupervisor`.
  """
  use GenServer

  defmodule State do
    defstruct automaton_sup: nil,
              agent_sup: nil,
              monitors: nil,
              automaton: nil,
              name: nil,
              mfa: nil
  end

  def start_link([automaton_sup, automaton_config]) do
    GenServer.start_link(__MODULE__, [automaton_sup, automaton_config],
      name: name(automaton_config[:name])
    )
  end

  def status(tree_name) do
    GenServer.call(name(tree_name), :status)
  end

  #############
  # Callbacks #
  #############

  def init([automaton_sup, automaton_config]) when is_pid(automaton_sup) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])
    state = %State{automaton_sup: automaton_sup, monitors: monitors}

    init(automaton_config, state)
  end

  def init([{:name, name} | rest], state) do
    init(rest, %{state | name: name})
  end

  def init([{:mfa, mfa} | rest], state) do
    init(rest, %{state | mfa: mfa})
  end

  def init([], state) do
    send(self(), :start_agent_supervisor)
    {:ok, state}
  end

  def init([_ | rest], state) do
    init(rest, state)
  end

  def handle_call(:status, _from, %{automaton: automaton, monitors: _monitors} = state) do
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
        :start_agent_supervisor,
        state = %{automaton_sup: automaton_sup, name: name, mfa: mfa}
      ) do
    spec = {Automaton.AgentSupervisor, [[self(), mfa, name]]}

    {:ok, agent_sup} = Supervisor.start_child(automaton_sup, spec)

    automaton = spawn_automaton(agent_sup, mfa, name)

    {:noreply, %{state | agent_sup: agent_sup, automaton: automaton}}
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

  def handle_info({:EXIT, agent_sup, reason}, state = %{agent_sup: agent_sup}) do
    {:stop, reason, state}
  end

  def handle_info(
        {:EXIT, pid, _reason},
        state = %{
          monitors: monitors,
          automaton: automaton,
          agent_sup: agent_sup,
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
              | automaton: [spawn_automaton(agent_sup, mfa, name) | remaining_automaton]
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
    :"#{tree_name}AgentServer"
  end

  defp spawn_automaton(agent_sup, {m, _f, _a} = mfa, _name) do
    spec = {m, [[agent_sup, mfa, m]]}
    {:ok, automaton} = DynamicSupervisor.start_child(agent_sup, spec)

    true = Process.link(automaton)
    automaton
  end

  #
  # defp dismiss_automaton(sup, pid) do
  #   true = Process.unlink(pid)
  #   DynamicSupervisor.terminate_child(sup, pid)
  # end
  #
  defp handle_automaton_exit(_pid, state) do
    %{
      agent_sup: _agent_sup,
      automaton: _automaton
    } = state

    state
  end

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]}
    }
  end
end
