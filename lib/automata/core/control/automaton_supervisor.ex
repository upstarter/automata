defmodule Automata.AutomatonSupervisor do
  use Supervisor

  def start_link(node_config) do
    Supervisor.start_link(__MODULE__, node_config, name: :"#{node_config[:name]}Supervisor")
  end

  def init(node_config) do
    # No DynamicSupervisor since only one_for_one supported
    opts = [
      strategy: :one_for_all
    ]

    children = [
      {Automata.AutomatonServer, [self, node_config]}
    ]

    Supervisor.init(children, opts)
  end

  def child_spec(node_config) do
    %{
      id: :"#{node_config[:name]}Supervisor",
      start: {__MODULE__, :start_link, node_config},
      type: :supervisor
    }
  end
end
