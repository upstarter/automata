defmodule Automata.Infrastructure.Supervision.Adapters.RegistryAdapter do
  @moduledoc """
  Provides a distributed registry adapter using Horde.Registry.
  
  This module initializes and configures a Horde.Registry instance to work with
  the distributed supervisor infrastructure.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Horde.Registry, [
        name: Automata.HordeRegistry,
        keys: :unique,
        members: :auto,
        delta_crdt_options: [
          sync_interval: 3000,
          max_sync_size: 50
        ]
      ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Registers a process with the distributed registry.
  """
  def register(key, value \\ nil) do
    Horde.Registry.register(Automata.HordeRegistry, key, value)
  end
  
  @doc """
  Looks up a process in the distributed registry.
  """
  def lookup(key) do
    Horde.Registry.lookup(Automata.HordeRegistry, key)
  end
  
  @doc """
  Unregisters a process from the distributed registry.
  """
  def unregister(key) do
    Horde.Registry.unregister(Automata.HordeRegistry, key)
  end
end