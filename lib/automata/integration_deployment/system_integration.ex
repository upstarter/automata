defmodule Automata.IntegrationDeployment.SystemIntegration do
  @moduledoc """
  System Integration component for integrating Automata with external systems.
  
  This module provides functionality for:
  - Creating API endpoints for external access to Automata
  - Registering external systems for integration
  - Creating data connectors for exchanging data
  - Managing event subscriptions between systems
  
  The System Integration component enables Automata to work seamlessly with
  existing software systems and infrastructures.
  """
  
  use GenServer
  require Logger
  
  alias Automata.IntegrationDeployment.SystemIntegration.APIManager
  alias Automata.IntegrationDeployment.SystemIntegration.SystemRegistry
  alias Automata.IntegrationDeployment.SystemIntegration.ConnectorManager
  alias Automata.IntegrationDeployment.SystemIntegration.EventBridge
  
  @type endpoint_id :: binary()
  @type system_id :: binary()
  @type connector_id :: binary()
  @type subscription_id :: binary()
  
  # Client API
  
  @doc """
  Starts the System Integration server.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
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
  @spec create_api_endpoint(binary(), map()) :: {:ok, endpoint_id()} | {:error, term()}
  def create_api_endpoint(name, config) do
    GenServer.call(__MODULE__, {:create_api_endpoint, name, config})
  end
  
  @doc """
  Lists all API endpoints.
  
  ## Returns
  - `{:ok, endpoints}` list of endpoints
  """
  @spec list_api_endpoints() :: {:ok, list(map())}
  def list_api_endpoints do
    GenServer.call(__MODULE__, :list_api_endpoints)
  end
  
  @doc """
  Registers an external system for integration.
  
  ## Parameters
  - system_name: Name of the external system
  - system_config: Configuration for integration
    - type: Type of system
    - connection: Connection details
    - auth: Authentication configuration
    - capabilities: System capabilities
  
  ## Returns
  - `{:ok, system_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec register_external_system(binary(), map()) :: {:ok, system_id()} | {:error, term()}
  def register_external_system(system_name, system_config) do
    GenServer.call(__MODULE__, {:register_external_system, system_name, system_config})
  end
  
  @doc """
  Lists all registered external systems.
  
  ## Returns
  - `{:ok, systems}` list of systems
  """
  @spec list_external_systems() :: {:ok, list(map())}
  def list_external_systems do
    GenServer.call(__MODULE__, :list_external_systems)
  end
  
  @doc """
  Creates a data connector for exchanging data with external systems.
  
  ## Parameters
  - name: Name of the connector
  - config: Configuration for the connector
    - type: Type of connector (:database, :messaging, :file, :api)
    - source: Source configuration
    - destination: Destination configuration
    - transforms: Data transformations to apply
  
  ## Returns
  - `{:ok, connector_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_connector(binary(), map()) :: {:ok, connector_id()} | {:error, term()}
  def create_connector(name, config) do
    GenServer.call(__MODULE__, {:create_connector, name, config})
  end
  
  @doc """
  Lists all data connectors.
  
  ## Returns
  - `{:ok, connectors}` list of connectors
  """
  @spec list_connectors() :: {:ok, list(map())}
  def list_connectors do
    GenServer.call(__MODULE__, :list_connectors)
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
  @spec subscribe_to_events(system_id(), list(), term()) :: 
    {:ok, subscription_id()} | {:error, term()}
  def subscribe_to_events(system_id, event_types, handler) do
    GenServer.call(__MODULE__, {:subscribe_to_events, system_id, event_types, handler})
  end
  
  @doc """
  Lists all event subscriptions.
  
  ## Parameters
  - system_id: Optional system ID to filter by
  
  ## Returns
  - `{:ok, subscriptions}` list of subscriptions
  """
  @spec list_subscriptions(system_id() | nil) :: {:ok, list(map())}
  def list_subscriptions(system_id \\ nil) do
    GenServer.call(__MODULE__, {:list_subscriptions, system_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting System Integration")
    {:ok, %{initialized: true}}
  end
  
  @impl true
  def handle_call({:create_api_endpoint, name, config}, _from, state) do
    case APIManager.create_endpoint(name, config) do
      {:ok, endpoint_id} = result ->
        Logger.info("Created API endpoint: #{name} (#{endpoint_id})")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:list_api_endpoints, _from, state) do
    result = APIManager.list_endpoints()
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:register_external_system, system_name, system_config}, _from, state) do
    case SystemRegistry.register_system(system_name, system_config) do
      {:ok, system_id} = result ->
        Logger.info("Registered external system: #{system_name} (#{system_id})")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:list_external_systems, _from, state) do
    result = SystemRegistry.list_systems()
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:create_connector, name, config}, _from, state) do
    case ConnectorManager.create_connector(name, config) do
      {:ok, connector_id} = result ->
        Logger.info("Created connector: #{name} (#{connector_id})")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:list_connectors, _from, state) do
    result = ConnectorManager.list_connectors()
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:subscribe_to_events, system_id, event_types, handler}, _from, state) do
    case EventBridge.subscribe(system_id, event_types, handler) do
      {:ok, subscription_id} = result ->
        Logger.info("Created event subscription to system #{system_id}")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:list_subscriptions, system_id}, _from, state) do
    result = EventBridge.list_subscriptions(system_id)
    {:reply, result, state}
  end
end

# Component implementations

defmodule Automata.IntegrationDeployment.SystemIntegration.APIManager do
  @moduledoc """
  Manager for API endpoints in the System Integration component.
  
  Responsible for creating, configuring, and managing API endpoints that allow
  external systems to interact with Automata.
  """
  
  use GenServer
  require Logger
  
  @type endpoint_id :: binary()
  
  # Client API
  
  @doc """
  Starts the API Manager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Creates a new API endpoint.
  
  ## Parameters
  - name: Name of the API endpoint
  - config: Configuration for the endpoint
  
  ## Returns
  - `{:ok, endpoint_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_endpoint(binary(), map()) :: {:ok, endpoint_id()} | {:error, term()}
  def create_endpoint(name, config) do
    GenServer.call(__MODULE__, {:create_endpoint, name, config})
  end
  
  @doc """
  Lists all API endpoints.
  
  ## Returns
  - `{:ok, endpoints}` list of endpoints
  """
  @spec list_endpoints() :: {:ok, list(map())}
  def list_endpoints do
    GenServer.call(__MODULE__, :list_endpoints)
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting API Manager")
    
    # Initialize with empty state
    initial_state = %{
      endpoints: %{},
      next_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:create_endpoint, name, config}, _from, state) do
    # Validate config
    with :ok <- validate_endpoint_config(config) do
      # Generate endpoint ID
      endpoint_id = "endpoint_#{state.next_id}"
      
      # Create endpoint record
      timestamp = DateTime.utc_now()
      endpoint = %{
        id: endpoint_id,
        name: name,
        type: Map.get(config, :type),
        path: Map.get(config, :path),
        auth: Map.get(config, :auth, %{}),
        operations: Map.get(config, :operations, []),
        created_at: timestamp,
        updated_at: timestamp,
        status: :created
      }
      
      # Update state
      updated_state = %{
        state |
        endpoints: Map.put(state.endpoints, endpoint_id, endpoint),
        next_id: state.next_id + 1
      }
      
      # In a real implementation, this would also set up the actual API endpoint
      # based on the specified type (REST, GraphQL, gRPC, etc.)
      
      {:reply, {:ok, endpoint_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create API endpoint: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:list_endpoints, _from, state) do
    endpoints = Map.values(state.endpoints)
    |> Enum.sort_by(& &1.created_at, DateTime)
    
    {:reply, {:ok, endpoints}, state}
  end
  
  # Helper functions
  
  defp validate_endpoint_config(config) do
    # Validate required fields
    required_fields = [:type, :path]
    
    missing_fields = Enum.filter(required_fields, fn field -> 
      !Map.has_key?(config, field) || is_nil(Map.get(config, field))
    end)
    
    if Enum.empty?(missing_fields) do
      # Validate endpoint type
      if config.type in [:rest, :graphql, :grpc, :websocket] do
        :ok
      else
        {:error, "Invalid endpoint type: #{config.type}"}
      end
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
end

defmodule Automata.IntegrationDeployment.SystemIntegration.SystemRegistry do
  @moduledoc """
  Registry for external systems in the System Integration component.
  
  Manages the registration and configuration of external systems that integrate
  with Automata.
  """
  
  use GenServer
  require Logger
  
  @type system_id :: binary()
  
  # Client API
  
  @doc """
  Starts the System Registry.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Registers an external system.
  
  ## Parameters
  - name: Name of the external system
  - config: Configuration for integration
  
  ## Returns
  - `{:ok, system_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec register_system(binary(), map()) :: {:ok, system_id()} | {:error, term()}
  def register_system(name, config) do
    GenServer.call(__MODULE__, {:register_system, name, config})
  end
  
  @doc """
  Lists all registered external systems.
  
  ## Returns
  - `{:ok, systems}` list of systems
  """
  @spec list_systems() :: {:ok, list(map())}
  def list_systems do
    GenServer.call(__MODULE__, :list_systems)
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting System Registry")
    
    # Initialize with empty state
    initial_state = %{
      systems: %{},
      next_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:register_system, name, config}, _from, state) do
    # Validate config
    with :ok <- validate_system_config(config) do
      # Generate system ID
      system_id = "system_#{state.next_id}"
      
      # Create system record
      timestamp = DateTime.utc_now()
      system = %{
        id: system_id,
        name: name,
        type: Map.get(config, :type),
        connection: Map.get(config, :connection, %{}),
        auth: Map.get(config, :auth, %{}),
        capabilities: Map.get(config, :capabilities, []),
        registered_at: timestamp,
        updated_at: timestamp,
        status: :registered
      }
      
      # Update state
      updated_state = %{
        state |
        systems: Map.put(state.systems, system_id, system),
        next_id: state.next_id + 1
      }
      
      {:reply, {:ok, system_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to register external system: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:list_systems, _from, state) do
    systems = Map.values(state.systems)
    |> Enum.sort_by(& &1.registered_at, DateTime)
    
    {:reply, {:ok, systems}, state}
  end
  
  # Helper functions
  
  defp validate_system_config(config) do
    # Validate required fields
    required_fields = [:type]
    
    missing_fields = Enum.filter(required_fields, fn field -> 
      !Map.has_key?(config, field) || is_nil(Map.get(config, field))
    end)
    
    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
end

defmodule Automata.IntegrationDeployment.SystemIntegration.ConnectorManager do
  @moduledoc """
  Manager for data connectors in the System Integration component.
  
  Creates and manages connectors for exchanging data between Automata and
  external systems.
  """
  
  use GenServer
  require Logger
  
  @type connector_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Connector Manager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Creates a new data connector.
  
  ## Parameters
  - name: Name of the connector
  - config: Configuration for the connector
  
  ## Returns
  - `{:ok, connector_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_connector(binary(), map()) :: {:ok, connector_id()} | {:error, term()}
  def create_connector(name, config) do
    GenServer.call(__MODULE__, {:create_connector, name, config})
  end
  
  @doc """
  Lists all data connectors.
  
  ## Returns
  - `{:ok, connectors}` list of connectors
  """
  @spec list_connectors() :: {:ok, list(map())}
  def list_connectors do
    GenServer.call(__MODULE__, :list_connectors)
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Connector Manager")
    
    # Initialize with empty state
    initial_state = %{
      connectors: %{},
      next_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:create_connector, name, config}, _from, state) do
    # Validate config
    with :ok <- validate_connector_config(config) do
      # Generate connector ID
      connector_id = "connector_#{state.next_id}"
      
      # Create connector record
      timestamp = DateTime.utc_now()
      connector = %{
        id: connector_id,
        name: name,
        type: Map.get(config, :type),
        source: Map.get(config, :source, %{}),
        destination: Map.get(config, :destination, %{}),
        transforms: Map.get(config, :transforms, []),
        created_at: timestamp,
        updated_at: timestamp,
        status: :created
      }
      
      # Update state
      updated_state = %{
        state |
        connectors: Map.put(state.connectors, connector_id, connector),
        next_id: state.next_id + 1
      }
      
      # In a real implementation, this would also set up the actual data connector
      # based on the specified type
      
      {:reply, {:ok, connector_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create connector: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:list_connectors, _from, state) do
    connectors = Map.values(state.connectors)
    |> Enum.sort_by(& &1.created_at, DateTime)
    
    {:reply, {:ok, connectors}, state}
  end
  
  # Helper functions
  
  defp validate_connector_config(config) do
    # Validate required fields
    required_fields = [:type, :source, :destination]
    
    missing_fields = Enum.filter(required_fields, fn field -> 
      !Map.has_key?(config, field) || is_nil(Map.get(config, field))
    end)
    
    if Enum.empty?(missing_fields) do
      # Validate connector type
      if config.type in [:database, :messaging, :file, :api] do
        :ok
      else
        {:error, "Invalid connector type: #{config.type}"}
      end
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
end

defmodule Automata.IntegrationDeployment.SystemIntegration.EventBridge do
  @moduledoc """
  Event bridge for the System Integration component.
  
  Manages event subscriptions and handles event routing between Automata and
  external systems.
  """
  
  use GenServer
  require Logger
  
  @type subscription_id :: binary()
  @type system_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Event Bridge.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
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
  @spec subscribe(system_id(), list(), term()) :: 
    {:ok, subscription_id()} | {:error, term()}
  def subscribe(system_id, event_types, handler) do
    GenServer.call(__MODULE__, {:subscribe, system_id, event_types, handler})
  end
  
  @doc """
  Lists all event subscriptions.
  
  ## Parameters
  - system_id: Optional system ID to filter by
  
  ## Returns
  - `{:ok, subscriptions}` list of subscriptions
  """
  @spec list_subscriptions(system_id() | nil) :: {:ok, list(map())}
  def list_subscriptions(system_id \\ nil) do
    GenServer.call(__MODULE__, {:list_subscriptions, system_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Event Bridge")
    
    # Initialize with empty state
    initial_state = %{
      subscriptions: %{},
      next_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:subscribe, system_id, event_types, handler}, _from, state) do
    # Validate input
    with :ok <- validate_subscription_input(system_id, event_types, handler) do
      # Generate subscription ID
      subscription_id = "subscription_#{state.next_id}"
      
      # Create subscription record
      timestamp = DateTime.utc_now()
      subscription = %{
        id: subscription_id,
        system_id: system_id,
        event_types: event_types,
        handler: handler,
        created_at: timestamp,
        active: true
      }
      
      # Update state
      updated_state = %{
        state |
        subscriptions: Map.put(state.subscriptions, subscription_id, subscription),
        next_id: state.next_id + 1
      }
      
      # In a real implementation, this would also set up the actual event subscription
      
      {:reply, {:ok, subscription_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create event subscription: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:list_subscriptions, nil}, _from, state) do
    # Return all subscriptions
    subscriptions = Map.values(state.subscriptions)
    |> Enum.sort_by(& &1.created_at, DateTime)
    
    {:reply, {:ok, subscriptions}, state}
  end
  
  @impl true
  def handle_call({:list_subscriptions, system_id}, _from, state) do
    # Return subscriptions for the specified system
    subscriptions = Map.values(state.subscriptions)
    |> Enum.filter(& &1.system_id == system_id)
    |> Enum.sort_by(& &1.created_at, DateTime)
    
    {:reply, {:ok, subscriptions}, state}
  end
  
  # Helper functions
  
  defp validate_subscription_input(system_id, event_types, handler) do
    cond do
      !is_binary(system_id) ->
        {:error, "System ID must be a string"}
      
      !is_list(event_types) || Enum.empty?(event_types) ->
        {:error, "Event types must be a non-empty list"}
      
      handler == nil ->
        {:error, "Handler cannot be nil"}
      
      true ->
        :ok
    end
  end
end