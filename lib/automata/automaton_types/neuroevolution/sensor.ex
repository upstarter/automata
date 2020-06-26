defmodule Automaton.Types.NE.Sensor do
  @moduledoc """
  A sensor is any process which produces a vector signal that the NN then processes.
  The signal can come from interacting with environ, or the Sensor can be a program that generates
  the signal in any way.


  Sensor's can be defined with the tuple: { id, cortex_id, name, vector_len, fanout_ids}
    • id, a unique id (useful for datastores)
    • cortex_id, id of the cortex for this sensor
    • name, name of function the sensor executes to generate or aquire the sensory data.
    • vector_len, vector length of produces sensory signal
    • fanout_ids, list of neuron ids to which the sensory data will be fanned out
  """

  defstruct id: nil, cx_id: nil, name: nil, vl: nil, fanout_ids: []

  @doc ~S"""
  When `gen/1` is executed it spawns the sensor element and immediately begins
  to wait for its initial state message.
  """
  def gen(exoself_pid) do
    spawn(fn -> loop(exoself_pid) end)
  end

  def loop(exoself_pid) do
    receive do
      {^exoself_pid, {id, cortex_pid, sensor_name, vl, fanout_pids}} ->
        loop(id, cortex_pid, sensor_name, vl, fanout_pids)
    end
  end

  @doc ~S"""
  The sensor process accepts only 2 types of messages, both from the cortex. The
  sensor can either be triggered to begin gathering sensory data based on its
  sensory role, or terminate if the cortex requests so.
  """
  def loop(id, cortex_pid, sensor_name, vl, fanout_pids) do
    receive do
      {^cortex_pid, :sync} ->
        sensory_vector = apply(__MODULE__, sensor_name, [vl])
        for pid <- fanout_pids, do: send(pid, {self(), :forward, sensory_vector})
        loop(id, cortex_pid, sensor_name, vl, fanout_pids)

      {^cortex_pid, :terminate} ->
        :ok
    end
  end

  @doc ~S"""
  `rng` is a simple random number generator that produces a vector of random
  values, each between 0 and 1. The length of the vector is defined by the vl,
  which itself is specified within the sensor record.
  """
  def rng(vl), do: rng(vl, [])
  def rng(0, acc), do: acc
  def rng(vl, acc), do: rng(vl - 1, [:rand.uniform() | acc])
end
