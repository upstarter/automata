defmodule Automata.Infrastructure.Adapters.AutomatonSupervisorAdapter do
  @moduledoc """
  Adapter for the legacy Automata.AutomatonSupervisor that bridges to the
  distributed supervision system.
  
  This adapter maintains compatibility with existing code while providing
  distributed capabilities.
  """
  
  use Supervisor
  
  alias Automata.Infrastructure.Adapters.AgentServerAdapter
  alias Automata.Infrastructure.Adapters.RegistryAdapter
  
  @doc """
  Starts the automaton supervisor with the given configuration.
  """
  def start_link(automaton_config) do
    name = :"#{automaton_config[:name]}Supervisor"
    Supervisor.start_link(__MODULE__, automaton_config, name: name)
  end
  
  @doc """
  Initializes the supervisor with the children needed for the automaton.
  """
  def init(automaton_config) do
    children = [
      # The agent server manages the lifecycle of the automaton's agents
      {AgentServerAdapter, [self(), automaton_config]}
    ]
    
    # Use one_for_all strategy to ensure that all components restart together
    Supervisor.init(children, strategy: :one_for_all)
  end
  
  @doc """
  Creates a child spec for the automaton supervisor.
  """
  def child_spec(automaton_config) do
    %{
      id: :"#{automaton_config[:name]}Supervisor",
      start: {__MODULE__, :start_link, [automaton_config]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end
end