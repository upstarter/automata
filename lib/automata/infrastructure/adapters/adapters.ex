defmodule Automata.Infrastructure.Adapters do
  @moduledoc """
  Entry point module for adapters that bridge between legacy supervision tree 
  and new distributed infrastructure.
  
  These adapters maintain compatibility with existing code while enabling
  the use of distributed components under the hood.
  """
  
  alias Automata.Infrastructure.Adapters.SupervisorAdapter
  alias Automata.Infrastructure.Adapters.AutomataSupervisorAdapter
  alias Automata.Infrastructure.Adapters.ServerAdapter
  alias Automata.Infrastructure.Adapters.AutomatonSupervisorAdapter
  alias Automata.Infrastructure.Adapters.RegistryAdapter
  
  @doc """
  Starts the adapter supervision tree with the given configuration.
  
  This is the main entry point for starting the adapted system.
  """
  def start(world_config) do
    SupervisorAdapter.start_link(world_config)
  end
  
  @doc """
  Registers a process with the distributed registry.
  """
  def register(name, pid) do
    RegistryAdapter.register(name, pid)
  end
  
  @doc """
  Looks up a process in the distributed registry.
  """
  def lookup(name) do
    RegistryAdapter.lookup(name)
  end
  
  @doc """
  Creates an adapter-compatible child spec for a given module and args.
  """
  def child_spec(module, args) do
    %{
      id: module,
      start: {module, :start_link, [args]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end
end