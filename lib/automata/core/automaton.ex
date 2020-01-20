defmodule Automata.Automaton do
  @moduledoc """

  """
  # NOTE: Restart temporary means that we don't let the
  #       supervisor restart the worker. Instead, we let the
  #       AutomatonServer handle it instead.
  use GenServer, restart: :temporary, shutdown: 5000

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def work_for(pid, duration) do
    GenServer.cast(pid, {:work_for, duration})
  end

  def init(arg) do
    IO.inspect(["UserNode", arg], label: __MODULE__)

    {:ok, arg}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_cast({:work_for, duration}, state) do
    :timer.sleep(duration)
    {:stop, :normal, state}
  end

  def child_spec do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }
  end
end
