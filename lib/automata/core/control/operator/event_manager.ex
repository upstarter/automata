defmodule Automata.EventManager do
  @moduledoc false
  @timeout :infinity

  @typep manager :: {supervisor_manager :: pid, event_manager :: pid}

  @doc """
  Starts an event manager that publishes events during automata episodes.
  Powers the internal statistics server for Automata.
  """
  @spec start_link() :: {:ok, manager}
  def start_link() do
    {:ok, sup} = DynamicSupervisor.start_link(strategy: :one_for_one)
    {:ok, event} = :gen_event.start_link()
    {:ok, {sup, event}}
  end

  def stop({sup, event}) do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(sup) do
      GenServer.stop(pid, :normal, @timeout)
    end

    DynamicSupervisor.stop(sup)
    :gen_event.stop(event)
  end

  def add_handler({sup, event}, handler, opts) do
    if Code.ensure_loaded?(handler) and function_exported?(handler, :handle_call, 2) do
      :gen_event.add_handler(event, handler, opts)
    else
      DynamicSupervisor.start_child(sup, %{
        id: GenServer,
        start: {GenServer, :start_link, [handler, opts]},
        restart: :temporary
      })
    end
  end

  def world_started(manager, world) do
    notify(manager, {:world_started, world})
  end

  def world_finished(manager, world) do
    notify(manager, {:world_finished, world})
  end

  def automata_started(manager, opts) do
    notify(manager, {:automata_started, opts})
  end

  def automata_finished(manager, automata) do
    notify(manager, {:automata_finished, automata})
  end

  def automaton_started(manager, automaton) do
    notify(manager, {:automaton_started, automaton})
  end

  def automaton_finished(manager, automaton) do
    notify(manager, {:automaton_finished, automaton})
  end

  def update_started(manager, test) do
    notify(manager, {:update_started, test})
  end

  def update_finished(manager, test) do
    notify(manager, {:update_finished, test})
  end

  defp notify({sup, event}, msg) do
    :gen_event.notify(event, msg)

    for {_, pid, _, _} <- Supervisor.which_children(sup) do
      GenServer.cast(pid, msg)
    end

    :ok
  end
end
