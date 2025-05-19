defmodule Automata.Infrastructure.Adapters.AgentSupervisorAdapter do
  @moduledoc """
  Adapter for the legacy Automaton.AgentSupervisor that bridges to the distributed system.
  
  This adapter maintains the same interface as the original agent supervisor but uses
  the distributed infrastructure components behind the scenes.
  """
  
  use DynamicSupervisor
  
  alias Automata.Infrastructure.Adapters.RegistryAdapter
  
  @doc """
  Starts the agent supervisor with the given configuration.
  """
  def start_link(automaton_config) do
    name = :"#{automaton_config[:name]}AgentSupervisor"
    DynamicSupervisor.start_link(__MODULE__, automaton_config, name: name)
  end
  
  @doc """
  Initializes the dynamic supervisor with the given configuration.
  """
  def init(automaton_config) do
    # Store the automaton configuration for later access
    Process.put(:automaton_config, automaton_config)
    
    # Initialize the dynamic supervisor with one_for_one strategy
    DynamicSupervisor.init(strategy: :one_for_one)
  end
  
  @doc """
  Starts an agent with the given configuration.
  """
  def start_agent(supervisor, agent_config) do
    # Get agent module from configuration
    agent_module = agent_config[:module]
    
    # Create child spec for the agent
    child_spec = %{
      id: agent_config[:name],
      start: {agent_module, :start_link, [agent_config]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
    
    # Start the agent under the dynamic supervisor
    case DynamicSupervisor.start_child(supervisor, child_spec) do
      {:ok, pid} ->
        # Register the agent in the distributed registry
        RegistryAdapter.register(agent_config[:name], pid)
        {:ok, pid}
      
      error ->
        error
    end
  end
  
  @doc """
  Stops an agent with the given name.
  """
  def stop_agent(supervisor, agent_name) do
    # Look up the agent pid in the distributed registry
    case RegistryAdapter.lookup(agent_name) do
      {:ok, pid} ->
        # Terminate the child and unregister it
        DynamicSupervisor.terminate_child(supervisor, pid)
        RegistryAdapter.unregister(agent_name)
        :ok
      
      _ ->
        {:error, :not_found}
    end
  end
  
  @doc """
  Lists all agents managed by this supervisor.
  """
  def list_agents(supervisor) do
    DynamicSupervisor.which_children(supervisor)
    |> Enum.map(fn {_, pid, type, modules} ->
      # Look up the agent name in the distributed registry
      name = RegistryAdapter.reverse_lookup(pid)
      |> case do
        {:ok, name} -> name
        _ -> :unknown
      end
      
      {name, pid, type, modules}
    end)
  end
end