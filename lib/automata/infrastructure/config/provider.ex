defmodule Automata.Infrastructure.Config.Provider do
  @moduledoc """
  Central provider for configuration management across the system.
  
  This module provides functionality for:
  - Loading configurations from different sources
  - Validating configurations against schemas
  - Storing configurations in distributed storage
  - Notifying components about configuration changes
  - Handling version changes and migrations
  """
  
  use GenServer
  require Logger
  
  alias Automata.Infrastructure.State.DistributedBlackboard
  alias Automata.Infrastructure.Config.SystemSchema
  alias Automata.Infrastructure.Config.WorldSchema
  alias Automata.Infrastructure.Config.AgentSchema
  
  # Client API
  
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @doc """
  Loads the system configuration with the provided overrides.
  """
  def load_system_config(overrides \\ %{}) do
    GenServer.call(__MODULE__, {:load_system_config, overrides})
  end
  
  @doc """
  Gets the current system configuration.
  """
  def get_system_config do
    GenServer.call(__MODULE__, :get_system_config)
  end
  
  @doc """
  Updates the system configuration with the provided changes.
  """
  def update_system_config(changes) do
    GenServer.call(__MODULE__, {:update_system_config, changes})
  end
  
  @doc """
  Validates a world configuration.
  """
  def validate_world_config(config) do
    WorldSchema.validate(config)
  end
  
  @doc """
  Validates an agent configuration.
  """
  def validate_agent_config(config) do
    AgentSchema.validate(config)
  end
  
  @doc """
  Creates a new world configuration and stores it.
  """
  def create_world_config(config) do
    GenServer.call(__MODULE__, {:create_world_config, config})
  end
  
  @doc """
  Updates an existing world configuration.
  """
  def update_world_config(world_id, changes) do
    GenServer.call(__MODULE__, {:update_world_config, world_id, changes})
  end
  
  @doc """
  Gets a world configuration by ID.
  """
  def get_world_config(world_id) do
    GenServer.call(__MODULE__, {:get_world_config, world_id})
  end
  
  @doc """
  Gets all world configurations.
  """
  def list_world_configs do
    GenServer.call(__MODULE__, :list_world_configs)
  end
  
  @doc """
  Subscribes to configuration change notifications.
  """
  def subscribe_to_changes do
    Registry.register(Automata.Infrastructure.Config.Registry, :config_changes, [])
    :ok
  end
  
  # Server callbacks
  
  @impl true
  def init(_init_arg) do
    Logger.info("Starting Configuration Provider")
    
    # Create the config change registry
    Registry.start_link(keys: :duplicate, name: Automata.Infrastructure.Config.Registry)
    
    # Load default system config
    {:ok, system_config} = load_default_system_config()
    
    state = %{
      system_config: system_config,
      worlds: %{},
      agents: %{},
      change_history: []
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:load_system_config, overrides}, _from, state) do
    case merge_and_validate_system_config(state.system_config, overrides) do
      {:ok, new_config} ->
        new_state = %{state | system_config: new_config}
        
        # Store in blackboard for distributed access
        store_system_config(new_config)
        
        # Notify subscribers
        notify_config_change(:system, nil, new_config)
        
        {:reply, {:ok, new_config}, new_state}
        
      {:error, _changeset} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:get_system_config, _from, state) do
    {:reply, {:ok, state.system_config}, state}
  end
  
  @impl true
  def handle_call({:update_system_config, changes}, _from, state) do
    case merge_and_validate_system_config(state.system_config, changes) do
      {:ok, new_config} ->
        new_state = %{state | 
          system_config: new_config,
          change_history: [{:system, changes, DateTime.utc_now()} | state.change_history]
        }
        
        # Store in blackboard for distributed access
        store_system_config(new_config)
        
        # Notify subscribers
        notify_config_change(:system, nil, new_config)
        
        {:reply, {:ok, new_config}, new_state}
        
      {:error, _changeset} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:create_world_config, config}, _from, state) do
    case WorldSchema.validate(config) do
      {:ok, valid_config} ->
        world_id = valid_config.id
        
        new_state = %{state | 
          worlds: Map.put(state.worlds, world_id, valid_config),
          change_history: [{:world, {:create, world_id}, DateTime.utc_now()} | state.change_history]
        }
        
        # Store in blackboard for distributed access
        store_world_config(valid_config)
        
        # Notify subscribers
        notify_config_change(:world, {:create, world_id}, valid_config)
        
        {:reply, {:ok, valid_config}, new_state}
        
      {:error, _changeset} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:update_world_config, world_id, changes}, _from, state) do
    case Map.fetch(state.worlds, world_id) do
      {:ok, existing_config} ->
        merged_config = Map.merge(existing_config, changes)
        
        case WorldSchema.validate(merged_config) do
          {:ok, valid_config} ->
            new_state = %{state | 
              worlds: Map.put(state.worlds, world_id, valid_config),
              change_history: [{:world, {:update, world_id}, DateTime.utc_now()} | state.change_history]
            }
            
            # Store in blackboard for distributed access
            store_world_config(valid_config)
            
            # Notify subscribers
            notify_config_change(:world, {:update, world_id}, valid_config)
            
            {:reply, {:ok, valid_config}, new_state}
            
          {:error, _changeset} = error ->
            {:reply, error, state}
        end
        
      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:get_world_config, world_id}, _from, state) do
    case Map.fetch(state.worlds, world_id) do
      {:ok, config} ->
        {:reply, {:ok, config}, state}
        
      :error ->
        # Try to load from blackboard
        case load_world_config_from_blackboard(world_id) do
          {:ok, config} ->
            new_state = %{state | worlds: Map.put(state.worlds, world_id, config)}
            {:reply, {:ok, config}, new_state}
            
          :error ->
            {:reply, {:error, :not_found}, state}
        end
    end
  end
  
  @impl true
  def handle_call(:list_world_configs, _from, state) do
    {:reply, {:ok, Map.values(state.worlds)}, state}
  end
  
  @impl true
  def handle_info({:config_sync, :system, config}, state) do
    # Another node updated the system config, sync it
    new_state = %{state | system_config: config}
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:config_sync, :world, world_id, config}, state) do
    # Another node updated a world config, sync it
    new_state = %{state | worlds: Map.put(state.worlds, world_id, config)}
    {:noreply, new_state}
  end
  
  # Private functions
  
  defp load_default_system_config do
    defaults = %{
      node_name: Atom.to_string(Node.self()),
      environment: get_environment(),
      distribution_mode: :local,
      cluster_strategy: :gossip,
      log_level: :info,
      metrics_enabled: true,
      telemetry_enabled: true
    }
    
    SystemSchema.validate(defaults)
  end
  
  defp get_environment do
    case Mix.env() do
      :dev -> :development
      :test -> :test
      :prod -> :production
      _ -> :development
    end
  end
  
  defp merge_and_validate_system_config(current, changes) do
    merged = Map.merge(current, changes)
    SystemSchema.validate(merged)
  end
  
  defp store_system_config(config) do
    DistributedBlackboard.put({:config, :system}, config)
  end
  
  defp store_world_config(config) do
    DistributedBlackboard.put({:config, :world, config.id}, config)
  end
  
  defp load_world_config_from_blackboard(world_id) do
    case DistributedBlackboard.get({:config, :world, world_id}) do
      nil -> :error
      config -> {:ok, config}
    end
  end
  
  defp notify_config_change(type, operation, config) do
    message = {:config_change, type, operation, config}
    
    # Notify local subscribers
    Registry.dispatch(Automata.Infrastructure.Config.Registry, :config_changes, fn entries ->
      for {pid, _} <- entries, do: send(pid, message)
    end)
    
    # Notify other nodes
    Node.list()
    |> Enum.each(fn node -> 
      sync_message = case type do
        :system -> {:config_sync, :system, config}
        :world -> {:config_sync, :world, config.id, config}
      end
      
      :erpc.cast(node, __MODULE__, :sync_from_remote, [sync_message])
    end)
  end
  
  @doc false
  def sync_from_remote(message) do
    # This is called from other nodes
    send(__MODULE__, message)
  end
end