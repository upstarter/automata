defmodule Automata.Infrastructure.Supervision.Adapters.ServerAdapter do
  @moduledoc """
  Adapter for Automata.Server that bridges the original server with the new distributed
  infrastructure.
  
  This adapter maintains the same interface as the original Automata.Server but delegates
  the actual work to the distributed components.
  """
  use GenServer

  alias Automata.Infrastructure.Supervision.DistributedSupervisor
  alias Automata.Infrastructure.Supervision.Adapters.AutomataSupervisorAdapter
  alias Automata.Types.Typology

  #######
  # API #
  #######

  def start_link(world_config) do
    GenServer.start_link(__MODULE__, [world_config], name: __MODULE__)
  end

  #############
  # Callbacks #
  #############

  @doc """
  Initialize the server adapter with the same world_config parameter.
  """
  def init([world_config]) do
    world_config
    |> configure_automata()
    |> Enum.each(fn automaton_config ->
      send(self(), {:start_automaton_sup, [automaton_config, world_config]})
    end)

    {:ok, world_config}
  end

  @doc """
  Delegate to the original configure_automata implementation for compatibility.
  """
  def configure_automata(world_config) do
    world_config = Typology.call(world_config)
    world_config.automata
  end

  @doc """
  Handle starting automaton supervisors, but using the distributed infrastructure.
  """
  def handle_info({:start_automaton_sup, [automaton_config, world_config]}, state) do
    # Start the automaton supervisor
    {:ok, _tree_sup} =
      DistributedSupervisor.start_child(%{
        id: {Automata.AutomatonSupervisor, automaton_config.name},
        start: {Automata.AutomatonSupervisor, :start_link, [[automaton_config]]},
        restart: :temporary,
        shutdown: 10_000,
        type: :supervisor
      })

    # Start the world server
    {:ok, _world_server} =
      DistributedSupervisor.start_child(%{
        id: {Automata.World.Server, world_config.world.name},
        start: {Automata.World.Server, :start_link, [[world_config.world]]},
        restart: :temporary,
        shutdown: 10_000,
        type: :worker
      })

    {:noreply, state}
  end

  def child_spec([world_config]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [world_config]},
      restart: :temporary,
      shutdown: 10_000,
      type: :worker
    }
  end
end