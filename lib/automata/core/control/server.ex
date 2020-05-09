defmodule Automata.Server do
  use GenServer

  #######
  # API #
  #######

  def start_link(nodes_config) do
    GenServer.start_link(__MODULE__, nodes_config, name: __MODULE__)
  end

  def status(automaton_name) do
    Automata.AutomatonServer.status(automaton_name)
  end

  #############
  # Callbacks #
  #############

  def init(nodes_config) do
    nodes_config
    |> Enum.each(fn node_config ->
      send(self(), {:start_tree, node_config})
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

  def child_spec([nodes_config]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [nodes_config]},
      restart: :temporary,
      shutdown: 10_000,
      type: :worker
    }
  end
end
