defmodule Automata.Infrastructure.AgentSystem.Supervisor do
  @moduledoc """
  Supervisor for the agent system.
  
  This module supervises all components of the agent system, including
  the agent type registry, agent servers, and type-specific services.
  """
  
  use Supervisor
  require Logger
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    Logger.info("Starting Agent System Supervisor")
    
    children = [
      # Registry for agent instances
      {Registry, keys: :unique, name: Automata.Infrastructure.AgentSystem.AgentRegistry},
      
      # Agent Type Registry
      Automata.Infrastructure.AgentSystem.Registry,
      
      # Dynamic supervisor for agent servers
      {DynamicSupervisor, 
        name: Automata.Infrastructure.AgentSystem.AgentSupervisor,
        strategy: :one_for_one
      }
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Registers agent types with the registry.
  
  This function is called during application startup to register
  the built-in agent types.
  """
  def register_agent_types do
    # Register built-in agent types
    
    # Behavior Tree agent type
    Automata.Infrastructure.AgentSystem.Registry.register(
      Automata.Infrastructure.AgentSystem.Types.BehaviorTree.AgentType
    )
    
    # Add additional agent types as they are implemented
    # Automata.Infrastructure.AgentSystem.Registry.register(
    #   Automata.Infrastructure.AgentSystem.Types.NeuroEvolution.AgentType
    # )
    # 
    # Automata.Infrastructure.AgentSystem.Registry.register(
    #   Automata.Infrastructure.AgentSystem.Types.ReinforcementLearning.AgentType
    # )
    
    :ok
  end
end