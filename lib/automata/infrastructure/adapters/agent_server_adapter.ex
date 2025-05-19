defmodule Automata.Infrastructure.Adapters.AgentServerAdapter do
  @moduledoc """
  Adapter for the legacy Automaton.AgentServer that bridges to the distributed system.
  
  This adapter maintains the same interface as the original agent server but uses
  the distributed infrastructure components behind the scenes.
  """
  
  use GenServer
  
  alias Automata.Infrastructure.Adapters.AgentSupervisorAdapter
  alias Automata.Infrastructure.Adapters.RegistryAdapter
  alias Automata.Infrastructure.Event.EventBus
  
  @doc """
  Starts the agent server with the given supervisor and configuration.
  """
  def start_link([supervisor_pid, automaton_config]) do
    name = :"#{automaton_config[:name]}Server"
    GenServer.start_link(__MODULE__, [supervisor_pid, automaton_config], name: name)
  end
  
  @doc """
  Initializes the agent server with the supervisor and configuration.
  """
  def init([supervisor_pid, automaton_config]) do
    # Start the agent supervisor
    {:ok, agent_sup_pid} = AgentSupervisorAdapter.start_link(automaton_config)
    
    # Register the agent server and supervisor in the distributed registry
    name = automaton_config[:name]
    RegistryAdapter.register(:"#{name}Server", self())
    RegistryAdapter.register(:"#{name}AgentSupervisor", agent_sup_pid)
    
    # Initialize the state
    state = %{
      supervisor_pid: supervisor_pid,
      automaton_config: automaton_config,
      agent_supervisor_pid: agent_sup_pid,
      agents: %{},
      started_at: System.system_time(:second)
    }
    
    # Publish event for agent server started
    EventBus.publish({:agent_server_started, name, self()})
    
    {:ok, state}
  end
  
  @doc """
  Starts an agent with the given configuration.
  """
  def start_agent(server, agent_config) do
    GenServer.call(server, {:start_agent, agent_config})
  end
  
  @doc """
  Stops an agent with the given name.
  """
  def stop_agent(server, agent_name) do
    GenServer.call(server, {:stop_agent, agent_name})
  end
  
  @doc """
  Lists all agents managed by this server.
  """
  def list_agents(server) do
    GenServer.call(server, :list_agents)
  end
  
  @doc """
  Gets information about an agent.
  """
  def agent_info(server, agent_name) do
    GenServer.call(server, {:agent_info, agent_name})
  end
  
  # GenServer callbacks
  
  def handle_call({:start_agent, agent_config}, _from, state) do
    # Extract name from agent config
    agent_name = agent_config[:name]
    
    # Check if the agent already exists
    case Map.has_key?(state.agents, agent_name) do
      true ->
        {:reply, {:error, :already_exists}, state}
      
      false ->
        # Start the agent under the agent supervisor
        case AgentSupervisorAdapter.start_agent(state.agent_supervisor_pid, agent_config) do
          {:ok, pid} ->
            # Publish event for agent started
            automaton_name = state.automaton_config[:name]
            EventBus.publish({:agent_started, automaton_name, agent_name, pid})
            
            # Update the agents map
            new_agents = Map.put(state.agents, agent_name, %{
              pid: pid,
              config: agent_config,
              started_at: System.system_time(:second)
            })
            
            {:reply, {:ok, pid}, %{state | agents: new_agents}}
          
          error ->
            {:reply, error, state}
        end
    end
  end
  
  def handle_call({:stop_agent, agent_name}, _from, state) do
    # Check if the agent exists
    case Map.has_key?(state.agents, agent_name) do
      false ->
        {:reply, {:error, :not_found}, state}
      
      true ->
        # Stop the agent
        case AgentSupervisorAdapter.stop_agent(state.agent_supervisor_pid, agent_name) do
          :ok ->
            # Publish event for agent stopped
            automaton_name = state.automaton_config[:name]
            EventBus.publish({:agent_stopped, automaton_name, agent_name})
            
            # Update the agents map
            new_agents = Map.delete(state.agents, agent_name)
            
            {:reply, :ok, %{state | agents: new_agents}}
          
          error ->
            {:reply, error, state}
        end
    end
  end
  
  def handle_call(:list_agents, _from, state) do
    # Return the list of agents
    {:reply, {:ok, state.agents}, state}
  end
  
  def handle_call({:agent_info, agent_name}, _from, state) do
    # Check if the agent exists
    case Map.get(state.agents, agent_name) do
      nil ->
        {:reply, {:error, :not_found}, state}
      
      info ->
        {:reply, {:ok, info}, state}
    end
  end
end