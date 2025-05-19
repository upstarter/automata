defmodule Automata.IntegrationDeployment do
  @moduledoc """
  Main entry point for the Integration & Deployment system.
  
  This module provides a unified API for three main components:
  - System Integration: Tools for integrating Automata with external systems
  - Deployment Infrastructure: Infrastructure for deploying Automata in production
  - Evaluation Framework: Tools for evaluating and benchmarking Automata systems
  
  These components enable seamless integration with existing applications,
  reliable deployment in production environments, and comprehensive evaluation
  of system performance and effectiveness.
  """
  
  alias Automata.IntegrationDeployment.SystemIntegration
  alias Automata.IntegrationDeployment.DeploymentInfrastructure
  alias Automata.IntegrationDeployment.EvaluationFramework
  alias Automata.IntegrationDeployment.Supervisor
  
  # System Integration API
  
  @doc """
  Creates a new API endpoint for external system integration.
  
  ## Parameters
  - name: Name of the API endpoint
  - config: Configuration for the endpoint
    - type: Type of endpoint (:rest, :graphql, :grpc, :websocket)
    - path: Base path for the endpoint
    - auth: Authentication configuration
    - operations: Allowed operations
  
  ## Returns
  - `{:ok, endpoint_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_api_endpoint(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_api_endpoint(name, config) do
    SystemIntegration.create_api_endpoint(name, config)
  end
  
  @doc """
  Registers an external system for integration.
  
  ## Parameters
  - system_name: Name of the external system
  - system_config: Configuration for integration
  
  ## Returns
  - `{:ok, system_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec register_external_system(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def register_external_system(system_name, system_config) do
    SystemIntegration.register_external_system(system_name, system_config)
  end
  
  @doc """
  Creates a data connector for exchanging data with external systems.
  
  ## Parameters
  - name: Name of the connector
  - config: Configuration for the connector
  
  ## Returns
  - `{:ok, connector_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_connector(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_connector(name, config) do
    SystemIntegration.create_connector(name, config)
  end
  
  @doc """
  Subscribes to events from an external system.
  
  ## Parameters
  - system_id: ID of the external system
  - event_types: List of event types to subscribe to
  - handler: Function or module to handle events
  
  ## Returns
  - `{:ok, subscription_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec subscribe_to_events(binary(), list(), term()) :: {:ok, binary()} | {:error, term()}
  def subscribe_to_events(system_id, event_types, handler) do
    SystemIntegration.subscribe_to_events(system_id, event_types, handler)
  end
  
  # Deployment Infrastructure API
  
  @doc """
  Creates a deployment configuration for an Automata system.
  
  ## Parameters
  - name: Name of the deployment
  - config: Deployment configuration
  
  ## Returns
  - `{:ok, deployment_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_deployment(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_deployment(name, config) do
    DeploymentInfrastructure.create_deployment(name, config)
  end
  
  @doc """
  Provisions infrastructure for a deployment.
  
  ## Parameters
  - deployment_id: ID of the deployment
  - options: Provisioning options
  
  ## Returns
  - `{:ok, resources}` if successful
  - `{:error, reason}` if failed
  """
  @spec provision_infrastructure(binary(), map()) :: {:ok, map()} | {:error, term()}
  def provision_infrastructure(deployment_id, options \\ %{}) do
    DeploymentInfrastructure.provision_infrastructure(deployment_id, options)
  end
  
  @doc """
  Deploys an Automata system to the provisioned infrastructure.
  
  ## Parameters
  - deployment_id: ID of the deployment
  - options: Deployment options
  
  ## Returns
  - `{:ok, deployment_info}` if successful
  - `{:error, reason}` if failed
  """
  @spec deploy_system(binary(), map()) :: {:ok, map()} | {:error, term()}
  def deploy_system(deployment_id, options \\ %{}) do
    DeploymentInfrastructure.deploy_system(deployment_id, options)
  end
  
  @doc """
  Gets the status of a deployment.
  
  ## Parameters
  - deployment_id: ID of the deployment
  
  ## Returns
  - `{:ok, status}` if successful
  - `{:error, reason}` if failed
  """
  @spec deployment_status(binary()) :: {:ok, map()} | {:error, term()}
  def deployment_status(deployment_id) do
    DeploymentInfrastructure.deployment_status(deployment_id)
  end
  
  @doc """
  Scales a deployment up or down.
  
  ## Parameters
  - deployment_id: ID of the deployment
  - scaling_config: Configuration for scaling
  
  ## Returns
  - `{:ok, new_status}` if successful
  - `{:error, reason}` if failed
  """
  @spec scale_deployment(binary(), map()) :: {:ok, map()} | {:error, term()}
  def scale_deployment(deployment_id, scaling_config) do
    DeploymentInfrastructure.scale_deployment(deployment_id, scaling_config)
  end
  
  # Evaluation Framework API
  
  @doc """
  Creates a new evaluation benchmark.
  
  ## Parameters
  - name: Name of the benchmark
  - config: Benchmark configuration
  
  ## Returns
  - `{:ok, benchmark_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_benchmark(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_benchmark(name, config) do
    EvaluationFramework.create_benchmark(name, config)
  end
  
  @doc """
  Runs a benchmark against a system.
  
  ## Parameters
  - benchmark_id: ID of the benchmark
  - target_id: ID of the system to benchmark
  - options: Options for the benchmark run
  
  ## Returns
  - `{:ok, benchmark_run_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec run_benchmark(binary(), binary(), map()) :: {:ok, binary()} | {:error, term()}
  def run_benchmark(benchmark_id, target_id, options \\ %{}) do
    EvaluationFramework.run_benchmark(benchmark_id, target_id, options)
  end
  
  @doc """
  Gets results from a benchmark run.
  
  ## Parameters
  - benchmark_run_id: ID of the benchmark run
  
  ## Returns
  - `{:ok, results}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_benchmark_results(binary()) :: {:ok, map()} | {:error, term()}
  def get_benchmark_results(benchmark_run_id) do
    EvaluationFramework.get_benchmark_results(benchmark_run_id)
  end
  
  @doc """
  Compares multiple benchmark results.
  
  ## Parameters
  - run_ids: List of benchmark run IDs to compare
  - metrics: List of metrics to compare
  
  ## Returns
  - `{:ok, comparison}` if successful
  - `{:error, reason}` if failed
  """
  @spec compare_benchmark_results(list(), list()) :: {:ok, map()} | {:error, term()}
  def compare_benchmark_results(run_ids, metrics \\ []) do
    EvaluationFramework.compare_benchmark_results(run_ids, metrics)
  end
  
  @doc """
  Creates a new monitoring configuration.
  
  ## Parameters
  - name: Name of the monitoring configuration
  - config: Monitoring configuration
  
  ## Returns
  - `{:ok, monitoring_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_monitoring(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_monitoring(name, config) do
    EvaluationFramework.create_monitoring(name, config)
  end
  
  @doc """
  Gets monitoring data for a system.
  
  ## Parameters
  - monitoring_id: ID of the monitoring configuration
  - timeframe: Optional timeframe for the data
  
  ## Returns
  - `{:ok, monitoring_data}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_monitoring_data(binary(), map()) :: {:ok, map()} | {:error, term()}
  def get_monitoring_data(monitoring_id, timeframe \\ %{}) do
    EvaluationFramework.get_monitoring_data(monitoring_id, timeframe)
  end
end