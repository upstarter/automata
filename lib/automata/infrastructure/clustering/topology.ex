defmodule Automata.Infrastructure.Clustering.Topology do
  @moduledoc """
  Configures the clustering topology for the Automata system.
  """

  @doc """
  Returns the clustering topology configuration based on the environment.
  """
  def get_topology do
    case Mix.env() do
      :dev -> development_topology()
      :test -> test_topology()
      :prod -> production_topology()
    end
  end

  defp development_topology do
    [
      automata: [
        strategy: Cluster.Strategy.Gossip,
        config: [
          port: 45892,
          if_addr: {0, 0, 0, 0},
          multicast_addr: {230, 1, 1, 251},
          multicast_ttl: 1
        ]
      ]
    ]
  end

  defp test_topology do
    [
      automata: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: [:"a@127.0.0.1", :"b@127.0.0.1"]]
      ]
    ]
  end

  defp production_topology do
    [
      automata: [
        strategy: Cluster.Strategy.Kubernetes,
        config: [
          kubernetes_selector: System.get_env("K8S_SELECTOR", "app=automata"),
          kubernetes_node_basename: System.get_env("K8S_NODE_BASENAME", "automata")
        ]
      ]
    ]
  end
end