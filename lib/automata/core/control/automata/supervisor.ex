defmodule Automata.Supervisor do
  @moduledoc """
  On application start, this supervisor process starts the
  `Automata.AutomataSupervisor` and it's corresponding `Server`. It is started
  with strategy `:one_for_one` to ensure that each `Automata.AutomataSupervisor`
  is independently self-healing, thus providing fault tolerance.
  """
  use Supervisor

  def start_link(automata_config) do
    Supervisor.start_link(__MODULE__, automata_config, name: __MODULE__)
  end

  @spec init(any) :: no_return
  def init(automata_config) do
    children = [
      {Automata.AutomataSupervisor, []},
      {Automata.Server, [automata_config]}
    ]

    opts = [
      strategy: :one_for_all,
      max_restart: 1,
      max_time: 3600,
      extra_arguments: [automata_config]
    ]

    Supervisor.init(children, opts)
  end
end
