defmodule Automata.Domain.Supervisor do
  @moduledoc """
  Supervisor for the domain layer components.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # World Supervisor
      Automata.Domain.World.Supervisor,
      
      # Agent Supervisor (for agent types management)
      Automata.Domain.Agent.Supervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end