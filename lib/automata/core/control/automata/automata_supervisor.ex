defmodule Automata.AutomataSupervisor do
  @moduledoc """
  The `Automata.Server` starts the individual `Automata.AutomatonSupervisor`'s
  under this Supervisor, which handles their lifecycle management.

  The :one_for_one restart strategy causes each `Automata.AutomatonSupervisor`
  to have their lifecycles individally managed (by the `Automata.Server`) in a
  decentralized way with no central point of failure.
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
