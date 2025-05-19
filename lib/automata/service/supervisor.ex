defmodule Automata.Service.Supervisor do
  @moduledoc """
  Supervisor for service-level components.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Event Manager Service
      Automata.Service.EventManager,
      
      # Metrics Service
      Automata.Service.Metrics
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end