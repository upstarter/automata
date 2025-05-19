defmodule Automata.Infrastructure.Resilience.Supervisor do
  @moduledoc """
  Supervisor for resilience-related processes in the Automata system.
  
  This supervisor manages:
  - Error tracking system
  - Circuit breaker registry and supervisor
  - Health monitoring system
  - Telemetry reporting system
  """
  
  use Supervisor
  require Logger
  
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Starting Resilience Supervisor")
    
    children = [
      # Circuit breaker registry
      {Registry, keys: :unique, name: Automata.Infrastructure.Resilience.Registry},
      
      # Error tracker
      Automata.Infrastructure.Resilience.ErrorTracker,
      
      # Circuit breaker supervisor
      Automata.Infrastructure.Resilience.CircuitBreakerSupervisor,
      
      # Health monitoring system
      Automata.Infrastructure.Resilience.Health,
      
      # Telemetry reporting system
      {Automata.Infrastructure.Resilience.TelemetryReporter, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end