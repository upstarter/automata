defmodule Automata.Server do
  @moduledoc """
  Handles lifecycle of `Automata.AutomataSupervisor` as a delegate to keep the
  supervisor lean and mean, since it handles each `Automata.AutomatonSupervisor`,
  passing the user config, which flows through the entire tree. This
  data flow is a key abstraction for the agents.
  """
  use GenServer

  #######
  # API #
  #######

  def start_link(agents_config) do
    GenServer.start_link(__MODULE__, agents_config, name: __MODULE__)
  end

  def status(agent_name) do
    Automata.AgentServer.status(agent_name)
  end

  #############
  # Callbacks #
  #############

  def init(agents_config) do
    agents_config
    |> Enum.each(fn agent_config ->
      send(self(), {:start_tree, agent_config})
    end)

    {:ok, agents_config}
  end

  def handle_info({:start_tree, agent_config}, state) do
    {:ok, _tree_sup} =
      DynamicSupervisor.start_child(
        Automata.AutomataSupervisor,
        {Automata.AutomatonSupervisor, [agent_config]}
      )

    {:noreply, state}
  end

  def child_spec([agents_config]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [agents_config]},
      restart: :temporary,
      shutdown: 10_000,
      type: :worker
    }
  end
end
