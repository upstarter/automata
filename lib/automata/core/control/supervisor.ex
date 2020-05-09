defmodule Automata.Supervisor do
  use Supervisor
  @dialyzer {:no_return, init: 1}

  def start_link(agents_config) do
    Supervisor.start_link(__MODULE__, agents_config, name: __MODULE__)
  end

  @spec init(any) :: no_return
  def init(agents_config) do
    children = [
      {Automata.AutomataSupervisor, []},
      {Automata.Server, [agents_config]}
    ]

    opts = [
      strategy: :one_for_all,
      max_restart: 1,
      max_time: 3600,
      extra_arguments: [agents_config]
    ]

    Supervisor.init(children, opts)
  end
end
