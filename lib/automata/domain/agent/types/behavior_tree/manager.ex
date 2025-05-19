defmodule Automata.Domain.Agent.Types.BehaviorTree.Manager do
  @moduledoc """
  Manages behavior tree agent implementations.
  """
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Register with the type registry
    Registry.register(Automata.Domain.Agent.TypeRegistry, :behavior_tree, nil)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_implementation, config}, _from, state) do
    # Create a simple implementation based on the config
    implementation = %{
      type: config.type,
      node_type: config.node_type,
      status: :ready,
      handle_tick: fn -> 
        Logger.debug("Behavior tree agent ticked")
        {:ok, %{status: :ready}} 
      end,
      terminate: fn _reason -> :ok end
    }
    
    {:reply, {:ok, implementation}, state}
  end
end