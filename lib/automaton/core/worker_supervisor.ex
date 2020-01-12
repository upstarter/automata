defmodule Automaton.WorkerSupervisor do
  @moduledoc """
    Monitors the user-defined workers (behavior tree actions)
  """
  use DynamicSupervisor

  # API
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  # CALLBACKS
  def start_child(foo, bar, baz) do
    # If MyWorker is not using the new child specs, we need to pass a map:
    # spec = %{id: MyWorker, start: {MyWorker, :start_link, [foo, bar, baz]}}
    spec = {Automaton.SampleWorker, foo: foo, bar: bar, baz: baz}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl true
  def init(init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [init_arg]
    )
  end
end
