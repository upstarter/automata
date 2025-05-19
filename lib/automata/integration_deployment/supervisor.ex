defmodule Automata.IntegrationDeployment.Supervisor do
  @moduledoc """
  Supervisor for the Integration & Deployment components.
  
  This supervisor manages:
  - System Integration components
  - Deployment Infrastructure components
  - Evaluation Framework components
  
  It provides fault tolerance and proper startup/shutdown sequence for these components.
  """
  
  use Supervisor
  
  alias Automata.IntegrationDeployment.SystemIntegration
  alias Automata.IntegrationDeployment.DeploymentInfrastructure
  alias Automata.IntegrationDeployment.EvaluationFramework
  
  @doc """
  Starts the Integration & Deployment supervisor.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # System Integration components
      {SystemIntegration, []},
      {SystemIntegration.APIManager, []},
      {SystemIntegration.SystemRegistry, []},
      {SystemIntegration.ConnectorManager, []},
      {SystemIntegration.EventBridge, []},
      
      # Deployment Infrastructure components
      {DeploymentInfrastructure, []},
      {DeploymentInfrastructure.DeploymentManager, []},
      {DeploymentInfrastructure.ResourceProvisioner, []},
      {DeploymentInfrastructure.ConfigManager, []},
      {DeploymentInfrastructure.MonitoringAgent, []},
      
      # Evaluation Framework components
      {EvaluationFramework, []},
      {EvaluationFramework.BenchmarkManager, []},
      {EvaluationFramework.MetricsCollector, []},
      {EvaluationFramework.AnalyticsEngine, []},
      {EvaluationFramework.MonitoringManager, []}
    ]
    
    # Use :one_for_one strategy so that if one component fails, only it is restarted
    Supervisor.init(children, strategy: :one_for_one)
  end
end