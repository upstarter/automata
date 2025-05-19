defmodule Automata.Infrastructure.Registry.DistributedRegistry do
  @moduledoc """
  Provides a distributed process registry using Horde.
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
        members: :auto
      ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Registers a process with the distributed registry.
  """
  def register(name, pid \\ self()) do
    Horde.Registry.register(Automata.HordeRegistry, name, pid)
  end

  @doc """
  Looks up a process in the distributed registry.
  """
  def lookup(name) do
    Horde.Registry.lookup(Automata.HordeRegistry, name)
  end

  @doc """
  Returns all processes registered under a given name pattern.
  """
  def match(pattern) do
    Horde.Registry.match(Automata.HordeRegistry, pattern, :_)
  end
end