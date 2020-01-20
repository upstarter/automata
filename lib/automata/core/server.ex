defmodule Automata.Server do
  use GenServer
  use DynamicSupervisor

  #######
  # API #
  #######

  def start_link(nodes_config) do
    GenServer.start_link(__MODULE__, nodes_config, name: __MODULE__)
  end

  def status(tree_name) do
    Automata.AutomatonServer.status(tree_name)
  end

  #############
  # Callbacks #
  #############

  def init(nodes_config) do
    nodes_config
    |> Enum.each(fn node_config ->
      send(self, {:start_tree, node_config})
    end)

    {:ok, nodes_config}
  end

  def handle_info({:start_tree, node_config}, state) do
    {:ok, _tree_sup} =
      DynamicSupervisor.start_child(
        Automata.AutomataSupervisor,
        {Automata.AutomatonSupervisor, [node_config]}
      )

    {:noreply, state}
  end

  #####################
  # Private Functions #
  #####################

  def child_spec([nodes_config]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [nodes_config]},
      restart: :temporary,
      shutdown: 10000,
      type: :worker
    }
  end
end
