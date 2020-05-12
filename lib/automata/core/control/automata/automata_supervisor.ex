defmodule Automata.AutomataSupervisor do
  @moduledoc """
  The `Automata.Server` starts the `Automata.AutomatonSupervisor` under this
  Supervisor. The :one_for_one restart strategy causes each
  `Automata.AutomatonSupervisor` to be individally fault tolerant.
  """
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
