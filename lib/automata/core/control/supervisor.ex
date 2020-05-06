defmodule Automata.Supervisor do
  use Supervisor
  @dialyzer {:no_return, init: 1}

  def start_link(nodes_config) do
    Supervisor.start_link(__MODULE__, nodes_config, name: __MODULE__)
  end

  @spec init(any) :: no_return
  def init(nodes_config) do
    children = [
      {Automata.AutomataSupervisor, []},
      {Automata.Server, [nodes_config]}
    ]

    opts = [
      strategy: :one_for_all,
      max_restart: 1,
      max_time: 3600,
      extra_arguments: [nodes_config]
    ]

    Supervisor.init(children, opts)
  end
end
