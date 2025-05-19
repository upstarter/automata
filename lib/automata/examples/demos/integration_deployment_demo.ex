defmodule Automata.IntegrationDeploymentDemo do
  @moduledoc """
  Demonstration of the Integration & Deployment capabilities.
  
  This module provides a simple demonstration of:
  - System Integration with API endpoints and external systems
  - Deployment Infrastructure for provisioning and deployment
  - Evaluation Framework for benchmarking and monitoring
  """
  
  alias Automata.IntegrationDeployment
  alias Automata.IntegrationDeployment.SystemIntegration
  alias Automata.IntegrationDeployment.DeploymentInfrastructure
  alias Automata.IntegrationDeployment.EvaluationFramework
  
  @doc """
  Run the demo.
  """
  def run do
    IO.puts("\n=== Integration & Deployment Demo ===\n")
    
    # Step 1: Create API endpoints for external integration
    IO.puts("Step 1: Creating API endpoints...")
    {:ok, rest_endpoint_id} = create_api_endpoints()
    IO.puts("  Created REST API endpoint: #{rest_endpoint_id}")
    
    # Step 2: Register external systems
    IO.puts("\nStep 2: Registering external systems...")
    {:ok, system_id} = register_external_systems()
    IO.puts("  Registered external system: #{system_id}")
    
    # Step 3: Create data connectors
    IO.puts("\nStep 3: Creating data connectors...")
    {:ok, connector_id} = create_connectors(system_id)
    IO.puts("  Created data connector: #{connector_id}")
    
    # Step 4: Create deployment configuration
    IO.puts("\nStep 4: Creating deployment configuration...")
    {:ok, deployment_id} = create_deployment()
    IO.puts("  Created deployment: #{deployment_id}")
    
    # Step 5: Provision infrastructure
    IO.puts("\nStep 5: Provisioning infrastructure...")
    {:ok, resources} = IntegrationDeployment.provision_infrastructure(deployment_id)
    IO.puts("  Provisioned infrastructure with #{resources.nodes} nodes")
    
    # Step 6: Deploy the system
    IO.puts("\nStep 6: Deploying the system...")
    {:ok, deployment_info} = IntegrationDeployment.deploy_system(deployment_id)
    IO.puts("  Deployed system with status: #{deployment_info.status}")
    
    # Step 7: Create benchmarks
    IO.puts("\nStep 7: Creating benchmarks...")
    {:ok, benchmark_id} = create_benchmarks()
    IO.puts("  Created performance benchmark: #{benchmark_id}")
    
    # Step 8: Run benchmark
    IO.puts("\nStep 8: Running benchmark...")
    {:ok, run_id} = IntegrationDeployment.run_benchmark(benchmark_id, deployment_id)
    IO.puts("  Started benchmark run: #{run_id}")
    
    # Wait for benchmark to complete
    Process.sleep(2000)
    
    # Step 9: Get benchmark results
    IO.puts("\nStep 9: Getting benchmark results...")
    {:ok, results} = IntegrationDeployment.get_benchmark_results(run_id)
    IO.puts("  Benchmark passed: #{results.overall_passed}")
    print_metrics(results.aggregated_metrics)
    
    # Step 10: Setup monitoring
    IO.puts("\nStep 10: Setting up monitoring...")
    {:ok, monitoring_id} = create_monitoring(deployment_id)
    IO.puts("  Created monitoring configuration: #{monitoring_id}")
    
    # Wait for monitoring data to be collected
    Process.sleep(1000)
    
    # Step 11: Get monitoring data
    IO.puts("\nStep 11: Getting monitoring data...")
    {:ok, monitoring_data} = IntegrationDeployment.get_monitoring_data(monitoring_id)
    IO.puts("  Collected #{length(monitoring_data)} monitoring data points")
    
    IO.puts("\n=== Demo Complete ===")
    
    :ok
  end
  
  # Helper functions
  
  defp create_api_endpoints do
    # Create a REST API endpoint
    rest_config = %{
      type: :rest,
      path: "/api/v1",
      auth: %{
        type: :jwt,
        required: true
      },
      operations: [
        %{method: :get, path: "/agents", description: "List agents"},
        %{method: :post, path: "/agents", description: "Create agent"},
        %{method: :get, path: "/agents/:id", description: "Get agent details"},
        %{method: :put, path: "/agents/:id", description: "Update agent"},
        %{method: :delete, path: "/agents/:id", description: "Delete agent"}
      ]
    }
    
    IntegrationDeployment.create_api_endpoint("Agents REST API", rest_config)
  end
  
  defp register_external_systems do
    # Register an external database system
    system_config = %{
      type: :database,
      connection: %{
        type: :postgresql,
        host: "db.example.com",
        port: 5432,
        database: "automata_data"
      },
      auth: %{
        type: :username_password,
        username: "automata_user"
      },
      capabilities: [
        :data_storage,
        :data_query,
        :transactions
      ]
    }
    
    IntegrationDeployment.register_external_system("Primary Database", system_config)
  end
  
  defp create_connectors(system_id) do
    # Create a database connector
    connector_config = %{
      type: :database,
      source: %{
        type: :internal,
        component: :agent_state
      },
      destination: %{
        type: :external,
        system_id: system_id,
        target: "agent_state_table"
      },
      transforms: [
        %{type: :filter, field: "internal_data", action: :exclude},
        %{type: :rename, from: "agent_id", to: "id"},
        %{type: :timestamp, field: "last_updated"}
      ]
    }
    
    IntegrationDeployment.create_connector("Agent State Connector", connector_config)
  end
  
  defp create_deployment do
    # Create a deployment configuration
    deployment_config = %{
      environment: :staging,
      infrastructure: %{
        provider: :kubernetes,
        cluster: "automata-staging",
        namespace: "automata-system"
      },
      scale: %{
        nodes: 3,
        replicas: 2,
        auto_scale: true,
        min_nodes: 2,
        max_nodes: 5
      },
      resources: %{
        cpu: "2",
        memory: "4Gi",
        storage: "20Gi"
      }
    }
    
    IntegrationDeployment.create_deployment("Staging Deployment", deployment_config)
  end
  
  defp create_benchmarks do
    # Create a performance benchmark
    benchmark_config = %{
      type: :performance,
      scenarios: [
        %{name: "agent_creation", operations: 100, concurrency: 10},
        %{name: "agent_update", operations: 500, concurrency: 20},
        %{name: "agent_query", operations: 1000, concurrency: 50}
      ],
      metrics: [
        :latency,
        :throughput,
        :error_rate,
        :memory_usage,
        :cpu_usage
      ],
      thresholds: %{
        latency: %{max: 100}, # ms
        throughput: %{min: 500}, # req/s
        error_rate: %{max: 0.02}, # 2%
        memory_usage: %{max: 600}, # MB
        cpu_usage: %{max: 80} # %
      }
    }
    
    IntegrationDeployment.create_benchmark("Performance Benchmark", benchmark_config)
  end
  
  defp create_monitoring(deployment_id) do
    # Create a monitoring configuration
    monitoring_config = %{
      target_id: deployment_id,
      metrics: [
        :latency,
        :throughput,
        :error_rate,
        :memory_usage,
        :cpu_usage
      ],
      frequency: 30, # seconds
      alerts: [
        %{metric: :error_rate, threshold: 0.05, type: :threshold, action: :notify},
        %{metric: :memory_usage, threshold: 800, type: :threshold, action: :notify},
        %{metric: :cpu_usage, threshold: 90, type: :threshold, action: [:notify, :scale]}
      ]
    }
    
    IntegrationDeployment.create_monitoring("Production Monitoring", monitoring_config)
  end
  
  defp print_metrics(metrics) do
    # Print aggregated metrics
    Enum.each(metrics, fn {metric, data} ->
      IO.puts("    #{metric}: avg=#{Float.round(data.avg, 2)}, min=#{Float.round(data.min, 2)}, max=#{Float.round(data.max, 2)}")
    end)
  end
end

# Run the demo when executed directly
if System.get_env("RUN_DEMO") == "true" do
  Automata.IntegrationDeploymentDemo.run()
end