defmodule Automata.AutomataSupervisor do
  use DynamicSupervisor

  def start_link([]) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    opts = [
      strategy: :one_for_one
    ]

    DynamicSupervisor.init(opts)
  end

  def child_spec do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end
end
