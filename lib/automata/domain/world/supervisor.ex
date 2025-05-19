defmodule Automata.Domain.World.Supervisor do
  @moduledoc """
  Supervises world instances in the system.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new world with the given configuration.
  """
  def start_world(world_config) do
    # Validate world config
    case Automata.Domain.World.Config.validate(world_config) do
      {:ok, config} ->
        child_spec = {Automata.Domain.World.Server, config}
        DynamicSupervisor.start_child(__MODULE__, child_spec)
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Stops a world by its ID.
  """
  def stop_world(world_id) do
    case Automata.Infrastructure.Registry.DistributedRegistry.lookup({:world, world_id}) do
      [{pid, _}] -> 
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      
      [] -> 
        {:error, :not_found}
    end
  end
end