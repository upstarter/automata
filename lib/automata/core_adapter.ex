defmodule Automata.CoreAdapter do
  @moduledoc """
  Provides a compatibility layer between the original Automata core modules
  and the new distributed architecture.
  
  This module serves as the main entry point for applications using the
  original Automata API, routing calls to the appropriate adapter modules.
  """
  
  alias Automata.Infrastructure.Supervision.Adapters.SupervisorAdapter
  alias Automata.Infrastructure.Supervision.Adapters.ServerAdapter
  alias Automata.Infrastructure.Supervision.Adapters.RegistryAdapter
  
  @doc """
  Starts the Automata system with the given world configuration.
  
  This function replaces the original Automata.Operator.run/1 function.
  """
  def start(world_config) do
    # Ensure that the registry is started
    RegistryAdapter.ensure_started()
    
    # Start the supervision tree
    SupervisorAdapter.start_link(world_config)
  end
  
  @doc """
  Starts an automaton with the given configuration.
  
  This function replaces the original Automata.Server.start_automaton/1 function.
  """
  def start_automaton(automaton_config) do
    ServerAdapter.start_automaton(automaton_config)
  end
  
  @doc """
  Stops an automaton with the given name.
  
  This function replaces the original Automata.Server.stop_automaton/1 function.
  """
  def stop_automaton(name) do
    ServerAdapter.stop_automaton(name)
  end
  
  @doc """
  Lists all automata in the system.
  
  This function replaces the original Automata.Server.list_automata/0 function.
  """
  def list_automata do
    ServerAdapter.list_automata()
  end
  
  @doc """
  Gets information about an automaton.
  
  This function replaces the original Automata.Server.automaton_info/1 function.
  """
  def automaton_info(name) do
    ServerAdapter.automaton_info(name)
  end
  
  @doc """
  Starts an agent in the given automaton with the given configuration.
  
  This function replaces the original Automaton.AgentServer.start_agent/2 function.
  """
  def start_agent(automaton_name, agent_config) do
    server_name = :"#{automaton_name}Server"
    
    case RegistryAdapter.lookup(server_name) do
      [{pid, _}] ->
        # Using the agent server directly since we don't have AgentServerAdapter
        # This would need to be implemented or we'd need to create the adapter
        GenServer.call(pid, {:start_agent, agent_config})
      
      _ ->
        {:error, :automaton_not_found}
    end
  end
  
  @doc """
  Stops an agent in the given automaton.
  
  This function replaces the original Automaton.AgentServer.stop_agent/2 function.
  """
  def stop_agent(automaton_name, agent_name) do
    server_name = :"#{automaton_name}Server"
    
    case RegistryAdapter.lookup(server_name) do
      [{pid, _}] ->
        # Using the agent server directly since we don't have AgentServerAdapter
        GenServer.call(pid, {:stop_agent, agent_name})
      
      _ ->
        {:error, :automaton_not_found}
    end
  end
  
  @doc """
  Lists all agents in the given automaton.
  
  This function replaces the original Automaton.AgentServer.list_agents/1 function.
  """
  def list_agents(automaton_name) do
    server_name = :"#{automaton_name}Server"
    
    case RegistryAdapter.lookup(server_name) do
      [{pid, _}] ->
        # Using the agent server directly since we don't have AgentServerAdapter
        GenServer.call(pid, :list_agents)
      
      _ ->
        {:error, :automaton_not_found}
    end
  end
  
  @doc """
  Gets information about an agent in the given automaton.
  
  This function replaces the original Automaton.AgentServer.agent_info/2 function.
  """
  def agent_info(automaton_name, agent_name) do
    server_name = :"#{automaton_name}Server"
    
    case RegistryAdapter.lookup(server_name) do
      [{pid, _}] ->
        # Using the agent server directly since we don't have AgentServerAdapter
        GenServer.call(pid, {:agent_info, agent_name})
      
      _ ->
        {:error, :automaton_not_found}
    end
  end
end