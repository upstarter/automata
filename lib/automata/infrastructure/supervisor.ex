defmodule Automata.Infrastructure.Supervisor do
  @moduledoc """
  Supervisor for all infrastructure-level components.
  
  The infrastructure layer provides the foundation services that support
  the domain layer, including:
  - Distributed registry and supervision
  - Shared state management
  - Configuration management
  - Event-driven communication
  - Resilience and error handling
  - Logging and telemetry
  - Extensible agent system
  - Performance monitoring and optimization
  """
  
  use Supervisor
  require Logger
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    Logger.info("Starting Infrastructure Layer")
    
    children = [
      # Distribution and registry
      Automata.Infrastructure.Registry.DistributedRegistry,
      Automata.Infrastructure.Supervision.DistributedSupervisor,
      
      # State management
      Automata.Infrastructure.State.DistributedBlackboard,
      
      # Configuration
      Automata.Infrastructure.Config.Provider,
      
      # Event bus and management
      Automata.Infrastructure.Event.EventManager,
      
      # Resilience, logging, and telemetry
      Automata.Infrastructure.Resilience.Supervisor,
      
      # Extensible agent system
      Automata.Infrastructure.AgentSystem.Supervisor,
      
      # Performance monitoring and optimization
      Automata.Infrastructure.Performance.Supervisor
    ]
    
    # Initialize the supervisor
    result = Supervisor.init(children, strategy: :one_for_one)
    
    # Register agent types after startup
    Process.send_after(self(), :register_agent_types, 1000)
    
    result
  end
  
  @impl true
  def handle_info(:register_agent_types, state) do
    # Register built-in agent types
    Automata.Infrastructure.AgentSystem.Supervisor.register_agent_types()
    {:noreply, state}
  end
  
  @doc false
  def handle_info(:system_started, state) do
    # Log system started
    Logger.info("Automata infrastructure layer fully initialized")
    {:noreply, state}
  end
end