defmodule Automata.Infrastructure.AgentSystem.Registry do
  @moduledoc """
  Registry for agent types in the Automata system.
  
  This module provides functions for registering, discovering, and managing
  agent types. It acts as the central point of coordination for agent type
  implementations, allowing for dynamic extension of the system with new agent types.
  """
  
  use GenServer
  require Logger
  alias Automata.Infrastructure.AgentSystem.AgentType
  
  # Client API
  
  @doc """
  Starts the agent type registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Registers an agent type implementation with the registry.
  
  Returns `:ok` if registration is successful, or `{:error, reason}` if it fails.
  """
  def register(module) do
    GenServer.call(__MODULE__, {:register, module})
  end
  
  @doc """
  Returns a list of all registered agent types.
  """
  def list_types do
    GenServer.call(__MODULE__, :list_types)
  end
  
  @doc """
  Returns detailed information about a specific agent type.
  """
  def get_type_info(type) do
    GenServer.call(__MODULE__, {:get_type_info, type})
  end
  
  @doc """
  Creates a new agent implementation of the specified type.
  
  Returns `{:ok, implementation}` if creation is successful,
  or `{:error, reason}` if it fails.
  """
  def create_implementation(agent_id, world_id, config) do
    GenServer.call(__MODULE__, {:create_implementation, agent_id, world_id, config})
  end
  
  @doc """
  Validates a configuration for the specified agent type.
  
  Returns `{:ok, validated_config}` if the configuration is valid,
  or `{:error, reason}` if it is invalid.
  """
  def validate_config(config) do
    GenServer.call(__MODULE__, {:validate_config, config})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("Starting Agent Type Registry")
    
    state = %{
      types: %{},  # Map of type -> module
      modules: %{} # Map of module -> type_info
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:register, module}, _from, state) do
    # Verify the module implements the AgentType behavior
    case AgentType.verify_implementation(module) do
      :ok ->
        # Get the type identifier from the module
        type = module.type()
        
        # Check if the type is already registered
        case Map.has_key?(state.types, type) do
          true ->
            {:reply, {:error, :already_registered}, state}
            
          false ->
            # Create type information
            type_info = %{
              module: module,
              type: type,
              description: get_description(module),
              schema: module.schema(),
              features: get_features(module)
            }
            
            # Update state
            new_state = %{
              state |
              types: Map.put(state.types, type, module),
              modules: Map.put(state.modules, module, type_info)
            }
            
            Logger.info("Registered agent type #{inspect(type)} implemented by #{inspect(module)}")
            {:reply, :ok, new_state}
        end
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:list_types, _from, state) do
    type_list = Enum.map(state.modules, fn {_module, type_info} ->
      %{
        type: type_info.type,
        description: type_info.description,
        features: type_info.features
      }
    end)
    
    {:reply, type_list, state}
  end
  
  @impl true
  def handle_call({:get_type_info, type}, _from, state) do
    case Map.fetch(state.types, type) do
      {:ok, module} ->
        type_info = Map.fetch!(state.modules, module)
        {:reply, {:ok, type_info}, state}
        
      :error ->
        {:reply, {:error, :unknown_type}, state}
    end
  end
  
  @impl true
  def handle_call({:create_implementation, agent_id, world_id, config}, _from, state) do
    with {:ok, type} <- extract_type(config),
         {:ok, module} <- get_module(state, type),
         {:ok, validated_config} <- module.validate_config(config),
         {:ok, implementation} <- module.init(agent_id, world_id, validated_config) do
      # Implementation created successfully
      {:reply, {:ok, implementation}, state}
    else
      {:error, reason} ->
        # Something went wrong
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:validate_config, config}, _from, state) do
    with {:ok, type} <- extract_type(config),
         {:ok, module} <- get_module(state, type),
         {:ok, validated_config} <- module.validate_config(config) do
      # Config validated successfully
      {:reply, {:ok, validated_config}, state}
    else
      {:error, reason} ->
        # Something went wrong
        {:reply, {:error, reason}, state}
    end
  end
  
  # Private helpers
  
  defp extract_type(config) do
    case Map.fetch(config, :type) do
      {:ok, type} when is_atom(type) ->
        {:ok, type}
        
      {:ok, type_str} when is_binary(type_str) ->
        # Try to convert string to atom
        try do
          {:ok, String.to_existing_atom(type_str)}
        rescue
          ArgumentError ->
            {:error, {:invalid_type, "Unknown agent type: #{type_str}"}}
        end
        
      :error ->
        {:error, {:missing_field, "Missing required field: type"}}
    end
  end
  
  defp get_module(state, type) do
    case Map.fetch(state.types, type) do
      {:ok, module} ->
        {:ok, module}
        
      :error ->
        {:error, {:unknown_type, "Unknown agent type: #{inspect(type)}"}}
    end
  end
  
  defp get_description(module) do
    if function_exported?(module, :description, 0) do
      module.description()
    else
      "#{inspect(module.type())} agent type"
    end
  end
  
  defp get_features(module) do
    if function_exported?(module, :features, 0) do
      module.features()
    else
      []
    end
  end
end