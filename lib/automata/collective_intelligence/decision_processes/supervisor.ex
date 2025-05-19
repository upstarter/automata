defmodule Automata.CollectiveIntelligence.DecisionProcesses.Supervisor do
  @moduledoc """
  Supervisor for the Collaborative Decision Processes component.
  
  This supervisor manages the lifecycle of the process manager and ensures that
  decision processes are properly supervised and can recover from failures.
  """
  use Supervisor
  
  alias Automata.CollectiveIntelligence.DecisionProcesses.ProcessManager
  
  @doc """
  Starts the decision processes supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    process_manager_name = Keyword.get(opts, :process_manager_name, ProcessManager)
    
    children = [
      {Registry, keys: :unique, name: Automata.Registry},
      {ProcessManager, name: process_manager_name}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end