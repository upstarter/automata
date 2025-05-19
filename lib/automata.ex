defmodule Automata do
  @moduledoc """
  Automata is a framework for building distributed autonomous agent systems.
  
  It provides a flexible architecture for creating, managing, and coordinating 
  autonomous agents across distributed nodes with fault tolerance and self-healing
  capabilities.
  """

  @typedoc """
  All automata start with a %State{}.
  """
  @type state :: module()

  @typedoc "The error state returned by `Automata.WorldInfo` and `Automata.AutomatonInfo`"
  @type failed :: [{Exception.kind(), reason :: term, Exception.stacktrace()}]

  @typedoc "A map representing the results of running an agent"
  @type agent_result :: %{
          failures: non_neg_integer,
          total: non_neg_integer
        }

  defmodule TimeoutError do
    defexception [:timeout, :type]

    @impl true
    def message(%{timeout: timeout, type: type}) do
      """
      #{type} timed out after #{timeout}ms. You can change the timeout:
        1. per automaton by setting "timeout: x" on automaton state (accepts :infinity)
        2. per automata by setting "@moduletag timeout: x" (accepts :infinity)
        3. globally ubiquitous timeout via "Automata.start(timeout: x)" configuration
      where "x" is the timeout given as integer in milliseconds (defaults to 60_000).
      """
    end
  end

  defmodule MultiError do
    @moduledoc """
    Raised to signal multiple automata errors which happened in a world.
    """

    defexception errors: []

    @impl true
    def message(%{errors: errors}) do
      "got the following errors:\n\n" <>
        Enum.map_join(errors, "\n\n", fn {kind, error, stack} ->
          Exception.format_banner(kind, error, stack)
        end)
    end
  end

  use Application

  @impl true
  def start(_type, _args) do
    options = persist_defaults(configuration())
    
    Application.ensure_all_started(:logger)
    Application.ensure_all_started(:horde)
    Application.ensure_all_started(:libcluster)
    
    topology = Automata.Infrastructure.Clustering.Topology.get_topology()
    
    children = [
      # Clustering
      {Cluster.Supervisor, [topology, [name: Automata.ClusterSupervisor]]},
      
      # Infrastructure layer
      Automata.Infrastructure.Supervisor,
      
      # Domain layer
      Automata.Domain.Supervisor,
      
      # Service layer
      Automata.Service.Supervisor,
      
      # Autonomous Governance layer
      Automata.AutonomousGovernance.Supervisor,
      
      # Integration & Deployment layer
      Automata.IntegrationDeployment.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Automata.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  # Persists default values in application environment
  defp persist_defaults(config) do
    config |> Keyword.take([:seed, :trace]) |> configure()
    config
  end

  @doc """
  Configures Automata.
  ## Options
  Automata supports the following options:
    * `:trace` - sets Automata into trace mode, this allows agents to print info
  on an episode(s) while running.
  Any arbitrary configuration can also be passed to `configure/1` or `start/1`,
  and these options can then be used in places such as the builtin automaton types
  configurations. These other options will be ignored by the Automata core itself.
  """
  @spec configure(Keyword.t()) :: :ok
  def configure(options) do
    Enum.each(options, fn {k, v} ->
      Application.put_env(:automata, k, v)
    end)
  end

  @doc """
  Returns Automata configuration.
  """
  @spec configuration() :: Keyword.t()
  def configuration do
    Application.get_all_env(:automata)
  end

  @doc """
  Creates a new world with the given configuration.
  """
  @spec create_world(map() | Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def create_world(world_config) do
    case Automata.Domain.World.Supervisor.start_world(world_config) do
      {:ok, pid} -> 
        world_id = :sys.get_state(pid).world_id
        {:ok, world_id}
      
      error -> 
        error
    end
  end

  @doc """
  Stops a world by its ID.
  """
  @spec stop_world(String.t()) :: :ok | {:error, term()}
  def stop_world(world_id) do
    Automata.Domain.World.Supervisor.stop_world(world_id)
  end

  @doc """
  Spawns a new agent in the specified world.
  """
  @spec spawn_agent(String.t(), map() | Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def spawn_agent(world_id, agent_config) do
    Automata.Domain.World.Server.spawn_automaton(world_id, agent_config)
  end

  @doc """
  Gets the current status of a world.
  """
  @spec world_status(String.t()) :: atom() | {:error, term()}
  def world_status(world_id) do
    case Automata.Infrastructure.Registry.DistributedRegistry.lookup({:world, world_id}) do
      [{pid, _}] -> 
        Automata.Domain.World.Server.status(world_id)
      
      [] -> 
        {:error, :world_not_found}
    end
  end

  @doc """
  Gets the current status of an agent.
  """
  @spec agent_status(String.t()) :: atom() | {:error, term()}
  def agent_status(agent_id) do
    case Automata.Infrastructure.Registry.DistributedRegistry.lookup({:agent, agent_id}) do
      [{pid, _}] -> 
        Automata.Domain.Agent.Server.status(agent_id)
      
      [] -> 
        {:error, :agent_not_found}
    end
  end

  @doc """
  Gets system metrics.
  """
  @spec metrics() :: map()
  def metrics do
    Automata.Service.Metrics.get_metrics()
  end

  @doc """
  Gets system health.
  """
  @spec health() :: map()
  def health do
    Automata.Service.Metrics.get_system_health()
  end

  @doc """
  Sends a tick signal to an agent.
  """
  @spec tick_agent(String.t()) :: :ok
  def tick_agent(agent_id) do
    Automata.Domain.Agent.Server.tick(agent_id)
  end
  
  # Autonomous Governance API
  
  @doc """
  Creates a new governance system with integrated components.
  
  ## Parameters
  - name: Name of the governance system
  - config: Configuration for the governance system
    - description: Description of the governance system
    - decision_mechanism: Mechanism for making decisions
    - norms: List of initial norms to apply
    - adaptation_mechanisms: Mechanisms for adaptation
  
  ## Returns
  - `{:ok, system_info}` if successful
  - `{:error, reason}` if failed
  """
  @spec setup_governance_system(binary(), map()) :: {:ok, map()} | {:error, term()}
  def setup_governance_system(name, config) do
    Automata.AutonomousGovernance.setup_governance_system(name, config)
  end
  
  @doc """
  Defines a norm within the self-regulation system.
  
  ## Parameters
  - name: Name of the norm
  - specification: Specification of the norm
  - contexts: List of contexts where the norm applies
  
  ## Returns
  - `{:ok, norm_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec define_norm(binary(), map(), list()) :: {:ok, binary()} | {:error, term()}
  def define_norm(name, specification, contexts \\ []) do
    Automata.AutonomousGovernance.define_norm(name, specification, contexts)
  end
  
  @doc """
  Creates a governance zone.
  
  ## Parameters
  - name: Name of the governance zone
  - config: Configuration for the zone
  
  ## Returns
  - `{:ok, zone_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_governance_zone(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_governance_zone(name, config) do
    Automata.AutonomousGovernance.create_governance_zone(name, config)
  end
  
  @doc """
  Defines an institution.
  
  ## Parameters
  - name: Name of the institution
  - config: Configuration for the institution
  
  ## Returns
  - `{:ok, institution_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec define_institution(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def define_institution(name, config) do
    Automata.AutonomousGovernance.define_institution(name, config)
  end
  
  # Integration & Deployment API
  
  @doc """
  Creates an API endpoint for external system integration.
  
  ## Parameters
  - name: Name of the API endpoint
  - config: Configuration for the endpoint
  
  ## Returns
  - `{:ok, endpoint_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_api_endpoint(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_api_endpoint(name, config) do
    Automata.IntegrationDeployment.create_api_endpoint(name, config)
  end
  
  @doc """
  Creates a deployment configuration.
  
  ## Parameters
  - name: Name of the deployment
  - config: Deployment configuration
  
  ## Returns
  - `{:ok, deployment_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_deployment(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_deployment(name, config) do
    Automata.IntegrationDeployment.create_deployment(name, config)
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
    Automata.IntegrationDeployment.provision_infrastructure(deployment_id, options)
  end
  
  @doc """
  Creates an evaluation benchmark.
  
  ## Parameters
  - name: Name of the benchmark
  - config: Benchmark configuration
  
  ## Returns
  - `{:ok, benchmark_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_benchmark(binary(), map()) :: {:ok, binary()} | {:error, term()}
  def create_benchmark(name, config) do
    Automata.IntegrationDeployment.create_benchmark(name, config)
  end

  @doc """
  For backward compatibility - begins update of Behavior Tree.
  """
  @spec spawn() :: agent_result()
  def spawn do
    if Mix.env() == :test do
      send(TestMockSeq1Server, :update)
    else
      send(MockMAB1Server, :tick)
    end
  end
  
  # Core adapter functionality for backward compatibility
  
  @doc """
  Legacy API compatibility: Starts the Automata system with the core architecture.
  Delegates to the CoreAdapter module to maintain backward compatibility.
  
  ## Parameters
  - world_config: World configuration
  
  ## Returns
  - `{:ok, pid}` if successful
  - `{:error, reason}` if failed
  """
  @spec legacy_start(map() | Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def legacy_start(world_config) do
    Automata.CoreAdapter.start(world_config)
  end
  
  @doc """
  Legacy API compatibility: Starts an automaton with the given configuration.
  Delegates to the CoreAdapter module to maintain backward compatibility.
  
  ## Parameters
  - automaton_config: Automaton configuration
  
  ## Returns
  - `{:ok, pid}` if successful
  - `{:error, reason}` if failed
  """
  @spec legacy_start_automaton(map() | Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def legacy_start_automaton(automaton_config) do
    Automata.CoreAdapter.start_automaton(automaton_config)
  end
  
  @doc """
  Legacy API compatibility: Stops an automaton with the given name.
  Delegates to the CoreAdapter module to maintain backward compatibility.
  
  ## Parameters
  - name: Automaton name
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec legacy_stop_automaton(atom() | String.t()) :: :ok | {:error, term()}
  def legacy_stop_automaton(name) do
    Automata.CoreAdapter.stop_automaton(name)
  end
  
  @doc """
  Legacy API compatibility: Lists all automata in the system.
  Delegates to the CoreAdapter module to maintain backward compatibility.
  
  ## Returns
  - List of automata
  """
  @spec legacy_list_automata() :: [{atom(), pid()}]
  def legacy_list_automata do
    Automata.CoreAdapter.list_automata()
  end
end
