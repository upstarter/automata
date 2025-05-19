defmodule Automata.Domain.Agent.Supervisor do
  @moduledoc """
  Manages agent types registration and supervision.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Registry for agent types
      {Registry, keys: :unique, name: Automata.Domain.Agent.TypeRegistry},
      
      # Agent type managers
      Automata.Domain.Agent.Types.BehaviorTree.Manager
      # Future implementations:
      # Automata.Domain.Agent.Types.NeuroEvolution.Manager,
      # Automata.Domain.Agent.Types.ReinforcementLearning.Manager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Retrieves an agent type manager for the specified type.
  """
  def get_manager(type) do
    case Registry.lookup(Automata.Domain.Agent.TypeRegistry, type) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :type_not_found}
    end
  end
end