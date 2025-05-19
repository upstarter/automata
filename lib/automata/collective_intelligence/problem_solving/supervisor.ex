defmodule Automata.CollectiveIntelligence.ProblemSolving.Supervisor do
  @moduledoc """
  Supervisor for the Distributed Problem Solving component.
  
  This supervisor manages the lifecycle of the problem manager and ensures that
  distributed problem solving processes are properly supervised and can recover
  from failures.
  """
  use Supervisor
  
  alias Automata.CollectiveIntelligence.ProblemSolving.ProblemManager
  
  @doc """
  Starts the problem solving supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    problem_manager_name = Keyword.get(opts, :problem_manager_name, ProblemManager)
    
    children = [
      {Registry, keys: :unique, name: Automata.Registry},
      {ProblemManager, name: problem_manager_name}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end