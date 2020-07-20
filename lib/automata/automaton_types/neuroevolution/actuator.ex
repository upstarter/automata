defmodule Automaton.Types.TWEANN.Actuator do
  @moduledoc """
  An actuator is a process that accepts signals from the neurons in the output
  layer, orders them into a vector, and then uses this vector to control some
  function that acts on the environ or even the NN itself.

  Actuator's are represented with the tuple: { id, cortex_id, name, vector_len, fanin_ids}
    • id, a unique id (useful for datastores)
    • cortex_id, id of the cortex for this sensor
    • name, name of function the sensor executes to act upon the environment, with
      the function parameter being the vector it accumulates from the incoming neural signals.
    • vector_len, vector length of the accumulated actuation vector.
    • fanin_ids, list of neuron ids to which are connected to the actuator.
  """

  require Logger

  defstruct id: nil, cx_id: nil, name: nil, vl: nil, fanin_ids: []

  @doc ~S"""
  When `gen/1` is executed it spawns the actuator element and immediately begins
  to wait for its initial state message.
  """
  def gen(exoself_pid) do
    spawn(fn -> loop(exoself_pid) end)
  end

  def loop(exoself_pid) do
    receive do
      {^exoself_pid, {id, cortex_pid, actuator_name, fanin_pids}} ->
        loop(id, cortex_pid, actuator_name, {fanin_pids, fanin_pids}, [])
    end
  end

  @doc ~S"""
  The actuator process gathers the control signals from the neurons, appending
  them to the accumulator. The order in which the signals are accumulated into
  a vector is in the same order as the neuron ids are stored within NIds. Once
  all the signals have been gathered, the actuator sends cortex the sync signal,
  executes its function, and then again begins to wait for the neural signals
  from the output layer by reseting the fanin_pids from the second copy of the
  list.
  """
  def loop(id, cortex_pid, actuator_name, {[from_pid | fanin_pids], m_fanin_pids}, acc) do
    receive do
      {^from_pid, :forward, input} ->
        loop(
          id,
          cortex_pid,
          actuator_name,
          {fanin_pids, m_fanin_pids},
          List.flatten([input, acc])
        )

      {^cortex_pid, :terminate} ->
        :ok
    end
  end

  def loop(id, cortex_pid, actuator_name, {[], m_fanin_pids}, acc) do
    apply(__MODULE__, actuator_name, [Enum.reverse(acc)])
    send(cortex_pid, {self(), :sync})
    loop(id, cortex_pid, actuator_name, {m_fanin_pids, m_fanin_pids}, [])
  end

  @doc ~S"""
  The pts actuation function simply prints to screen the vector passed to it.
  """
  def pts(result) do
    Logger.debug("actuator:pts(result): #{inspect(result)}")
  end
end
