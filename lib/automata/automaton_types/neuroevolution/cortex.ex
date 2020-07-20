defmodule Automaton.Types.TWEANN.Cortex do
  @moduledoc """
  A NN synchronizing element. It knows the PID of every sensor and
  actuator, so that it will know when all the actuators have received their
  inputs, and that it's time for the sensors to again gather and
  fanout sensory data to the neurons in the input layer.

  Also can act as supervisor to all the neuron, sensor, and actuator elements
  in the NN system.

  Cortex's are represented by the tuple: { id, sensor_ids, actuator_ids, nids}
    • id, a unique id (useful for datastores)
    • sensor_ids, ids of the sensors that produce and pass the sensory signals to the
      neurons in the input layer.
    • actuator_ids, list of acuator ids that the neural output layer is connected to.
    • nids, list of all neuron ids in the NN
  """

  require Logger

  defstruct id: nil, sensor_ids: [], actuator_ids: [], n_ids: []

  @doc """
  The `gen/1` function spawns the cortex element, which immediately starts to wait
  for a the state message from the same process that spawned it, exoself. The
  initial state message contains the sensor, actuator, and neuron PId lists. The
  message also specifies how many total Sense-Think-Act cycles the Cortex
  should execute before terminating the NN system. Once we implement the
  learning algorithm, the termination criteria will depend on the fitness of the
  NN, or some other useful property
  """
  def gen(exoself_pid) do
    spawn(fn -> loop(exoself_pid) end)
  end

  @doc """
  The cortex’s goal is to synchronize the NN system such that when the actuators
  have received all their control signals, the sensors are once again triggered
  to gather new sensory information. Thus the cortex waits for the sync messages
  from the actuator PIds in its system, and once it has received all the sync
  messages, it triggers the sensors and then drops back to waiting for a new set
  of sync messages. The cortex stores 2 copies of the actuator PIds: the a_pids,
  and the Memorya_pids (Ma_pids). Once all the actuators have sent it the sync
  messages, it can restore the a_pids list from the Ma_pids. Finally, there is
  also the Step variable which decrements every time a full cycle of Sense-
  Think-Act completes, once this reaches 0, the NN system begins its termination
  and backup process.
  """
  def loop(exoself_pid) do
    receive do
      {^exoself_pid, {id, s_pids, a_pids, n_pids}, total_steps} ->
        for s_pid <- s_pids, do: send(s_pid, {self(), :sync})
        loop(id, exoself_pid, s_pids, {a_pids, a_pids}, n_pids, total_steps)
    end
  end

  def loop(id, exoself_pid, s_pids, {_a_pids, m_a_pids}, n_pids, 0) do
    Logger.debug("Cortex:#{inspect(id)} finished, now backing up and terminating.")
    neuron_ids_and_weights = get_backup(n_pids, [])
    send(exoself_pid, {self(), :backup, neuron_ids_and_weights})

    for lst <- [s_pids, m_a_pids, n_pids] do
      for pid <- lst, do: send(pid, {self(), :terminate})
    end
  end

  def loop(id, exoself_pid, s_pids, {[a_pid | a_pids], m_a_pids}, n_pids, step) do
    receive do
      {^a_pid, :sync} ->
        loop(id, exoself_pid, s_pids, {a_pids, m_a_pids}, n_pids, step)

      :terminate ->
        Logger.info("Cortex:#{inspect(id)} is terminating.")

        for lst <- [s_pids, m_a_pids, n_pids] do
          for pid <- lst, do: send(pid, {self(), :terminate})
        end
    end
  end

  def loop(id, exoself_pid, s_pids, {[], m_a_pids}, n_pids, step) do
    for s_pid <- s_pids, do: send(s_pid, {self(), :sync})
    loop(id, exoself_pid, s_pids, {m_a_pids, m_a_pids}, n_pids, step - 1)
  end

  @doc """
  During backup, cortex contacts all the neurons in its NN and requests for the
  neuron’s Ids and their Input_IdPs. Once the updated Input_IdPs from all the
  neurons have been accumulated, the list is sent to exoself for the actual
  backup and storage.
  """
  def get_backup([n_pid | n_pids], acc) do
    send(n_pid, {self(), :get_backup})

    receive do
      {^n_pid, n_id, weight_tuples} ->
        get_backup(n_pids, [{n_id, weight_tuples} | acc])
    end
  end

  def get_backup([], acc), do: acc
end
