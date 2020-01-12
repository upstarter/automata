defmodule Automaton.SampleWorker do
  use GenServer

  def start_link(init_arg, foo) do
    IO.inspect("START_LINK", label: __MODULE__)
    IO.inspect([foo], label: __MODULE__)

    GenServer.start_link(__MODULE__, :ok, [])
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def work_for(pid, duration) do
    GenServer.cast(pid, {:work_for, duration})
  end

  def init(arg) do
    IO.inspect("INIT", label: __MODULE__)
    {:ok, arg}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_cast({:work_for, duration}, state) do
    :timer.sleep(duration)
    {:stop, :normal, state}
  end
end
