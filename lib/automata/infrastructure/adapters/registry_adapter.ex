defmodule Automata.Infrastructure.Adapters.RegistryAdapter do
  @moduledoc """
  Adapter for the process registry that provides distributed registry capabilities.
  
  This adapter uses Horde.Registry for distributed process registration.
  """
  
  use Horde.Registry
  
  @doc """
  Starts the registry.
  """
  def start_link(_) do
    Horde.Registry.start_link(__MODULE__, [keys: :unique], name: __MODULE__)
  end
  
  @doc """
  Initializes the registry.
  """
  def init(init_arg) do
    [members: get_members()]
    |> Keyword.merge(init_arg)
    |> Horde.Registry.init()
  end
  
  @doc """
  Ensures that the registry is started.
  """
  def ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        DynamicSupervisor.start_child(
          Automata.Infrastructure.Supervision.DynamicRootSupervisor,
          {__MODULE__, []}
        )
      
      _ ->
        :ok
    end
  end
  
  @doc """
  Registers a process with the distributed registry.
  """
  def register(name, pid) do
    Horde.Registry.register(__MODULE__, name, pid)
  end
  
  @doc """
  Unregisters a process from the distributed registry.
  """
  def unregister(name) do
    Horde.Registry.unregister(__MODULE__, name)
  end
  
  @doc """
  Looks up a process in the distributed registry.
  """
  def lookup(name) do
    case Horde.Registry.lookup(__MODULE__, name) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end
  
  @doc """
  Performs a reverse lookup to find the name for a given pid.
  """
  def reverse_lookup(pid) do
    case Horde.Registry.keys(__MODULE__, pid) do
      [name | _] -> {:ok, name}
      [] -> {:error, :not_found}
    end
  end
  
  # Private functions
  
  defp get_members do
    # In a distributed environment, this would return all known nodes
    # For this implementation, we'll just use the local node
    [__MODULE__]
  end
end