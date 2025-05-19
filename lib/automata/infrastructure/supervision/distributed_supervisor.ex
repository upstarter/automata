defmodule Automata.Infrastructure.Supervision.DistributedSupervisor do
  @moduledoc """
  Provides a distributed supervisor using Horde.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Horde.DynamicSupervisor, [
        name: Automata.HordeSupervisor,
        strategy: :one_for_one,
        distribution_strategy: Horde.UniformDistribution,
        max_restarts: 100,
        max_seconds: 60,
        shutdown: 30_000,
        members: :auto
      ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Starts a child process under the distributed supervisor.
  """
  def start_child(child_spec) do
    Horde.DynamicSupervisor.start_child(Automata.HordeSupervisor, child_spec)
  end

  @doc """
  Terminates a child process under the distributed supervisor.
  """
  def terminate_child(pid) do
    Horde.DynamicSupervisor.terminate_child(Automata.HordeSupervisor, pid)
  end

  @doc """
  Returns a list of all children in the distributed supervisor.
  """
  def which_children do
    Horde.DynamicSupervisor.which_children(Automata.HordeSupervisor)
  end
end