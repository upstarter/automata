defmodule Automata.AutonomousGovernance.DistributedGovernance.ZoneManager do
  @moduledoc """
  Manager for governance zones in the distributed governance system.
  
  This module provides functionality for:
  - Creating and configuring governance zones
  - Managing agent registrations within zones
  - Tracking zone membership and permissions
  - Zone configuration and lifecycle management
  
  Governance zones represent bounded contexts where specific governance rules apply.
  """
  
  use GenServer
  require Logger
  
  @type zone_id :: binary()
  @type agent_id :: binary()
  @type registration_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Zone Manager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Creates a new governance zone.
  
  ## Parameters
  - name: Name of the governance zone
  - config: Configuration for the zone
    - description: Description of the zone
    - decision_mechanism: Mechanism for making decisions (:majority, :consensus, :weighted, etc.)
    - agent_requirements: Requirements for agents to join
    - scope: Scope of decisions that can be made
  
  ## Returns
  - `{:ok, zone_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec create_zone(binary(), map()) :: {:ok, zone_id()} | {:error, term()}
  def create_zone(name, config) do
    GenServer.call(__MODULE__, {:create_zone, name, config})
  end
  
  @doc """
  Registers an agent in a governance zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - agent_id: ID of the agent to register
  - roles: Map of roles the agent will have in the zone
  
  ## Returns
  - `{:ok, registration_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec register_agent(zone_id(), agent_id(), map()) :: {:ok, registration_id()} | {:error, term()}
  def register_agent(zone_id, agent_id, roles \\ %{}) do
    GenServer.call(__MODULE__, {:register_agent, zone_id, agent_id, roles})
  end
  
  @doc """
  Removes an agent from a governance zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - agent_id: ID of the agent to remove
  - reason: Reason for removal
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec remove_agent(zone_id(), agent_id(), map()) :: :ok | {:error, term()}
  def remove_agent(zone_id, agent_id, reason \\ %{}) do
    GenServer.call(__MODULE__, {:remove_agent, zone_id, agent_id, reason})
  end
  
  @doc """
  Gets details about a governance zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  
  ## Returns
  - `{:ok, zone}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_zone(zone_id()) :: {:ok, map()} | {:error, term()}
  def get_zone(zone_id) do
    GenServer.call(__MODULE__, {:get_zone, zone_id})
  end
  
  @doc """
  Lists all governance zones, optionally filtered by criteria.
  
  ## Parameters
  - filters: Map of filters to apply
  
  ## Returns
  - `{:ok, zones}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_zones(map()) :: {:ok, list(map())} | {:error, term()}
  def list_zones(filters \\ %{}) do
    GenServer.call(__MODULE__, {:list_zones, filters})
  end
  
  @doc """
  Checks if an agent is registered in a zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - agent_id: ID of the agent
  
  ## Returns
  - `{:ok, registration}` if agent is registered
  - `{:error, :not_registered}` if agent is not registered
  - `{:error, reason}` for other errors
  """
  @spec check_agent_registration(zone_id(), agent_id()) :: 
    {:ok, map()} | {:error, :not_registered} | {:error, term()}
  def check_agent_registration(zone_id, agent_id) do
    GenServer.call(__MODULE__, {:check_agent_registration, zone_id, agent_id})
  end
  
  @doc """
  Updates an agent's roles in a zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - agent_id: ID of the agent
  - roles: New roles for the agent
  
  ## Returns
  - `{:ok, registration}` if successful
  - `{:error, reason}` if failed
  """
  @spec update_agent_roles(zone_id(), agent_id(), map()) :: {:ok, map()} | {:error, term()}
  def update_agent_roles(zone_id, agent_id, roles) do
    GenServer.call(__MODULE__, {:update_agent_roles, zone_id, agent_id, roles})
  end
  
  @doc """
  Lists all agents in a zone.
  
  ## Parameters
  - zone_id: ID of the governance zone
  
  ## Returns
  - `{:ok, agents}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_agents_in_zone(zone_id()) :: {:ok, list(map())} | {:error, term()}
  def list_agents_in_zone(zone_id) do
    GenServer.call(__MODULE__, {:list_agents_in_zone, zone_id})
  end
  
  @doc """
  Updates zone configuration.
  
  ## Parameters
  - zone_id: ID of the governance zone
  - config_changes: Map of configuration changes
  
  ## Returns
  - `{:ok, zone}` if successful
  - `{:error, reason}` if failed
  """
  @spec update_zone_config(zone_id(), map()) :: {:ok, map()} | {:error, term()}
  def update_zone_config(zone_id, config_changes) do
    GenServer.call(__MODULE__, {:update_zone_config, zone_id, config_changes})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Zone Manager")
    
    # Initialize with empty state
    initial_state = %{
      zones: %{},
      registrations: %{},
      zone_agents: %{},
      agent_zones: %{},
      next_zone_id: 1,
      next_registration_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:create_zone, name, config}, _from, state) do
    # Validate config
    with :ok <- validate_zone_config(config) do
      # Generate zone ID
      zone_id = "zone_#{state.next_zone_id}"
      
      # Create zone record
      timestamp = DateTime.utc_now()
      zone = %{
        id: zone_id,
        name: name,
        description: Map.get(config, :description, ""),
        decision_mechanism: Map.get(config, :decision_mechanism, :majority),
        agent_requirements: Map.get(config, :agent_requirements, %{}),
        scope: Map.get(config, :scope, []),
        threshold: Map.get(config, :threshold),
        created_at: timestamp,
        updated_at: timestamp,
        status: :active,
        agent_count: 0
      }
      
      # Update state
      updated_state = %{
        state |
        zones: Map.put(state.zones, zone_id, zone),
        zone_agents: Map.put(state.zone_agents, zone_id, MapSet.new()),
        next_zone_id: state.next_zone_id + 1
      }
      
      Logger.info("Created governance zone: #{name} (#{zone_id})")
      {:reply, {:ok, zone_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create zone: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:register_agent, zone_id, agent_id, roles}, _from, state) do
    # Verify the zone exists
    with {:ok, zone} <- get_zone_from_state(state, zone_id),
         :ok <- check_agent_not_registered(state, zone_id, agent_id),
         :ok <- validate_agent_requirements(zone, agent_id) do
      
      # Generate registration ID
      registration_id = "registration_#{state.next_registration_id}"
      
      # Create registration record
      timestamp = DateTime.utc_now()
      registration = %{
        id: registration_id,
        zone_id: zone_id,
        agent_id: agent_id,
        roles: roles,
        joined_at: timestamp,
        status: :active
      }
      
      # Update zone agent count
      updated_zone = Map.update!(zone, :agent_count, &(&1 + 1))
      
      # Update state
      updated_state = %{
        state |
        zones: Map.put(state.zones, zone_id, updated_zone),
        registrations: Map.put(state.registrations, registration_id, registration),
        zone_agents: Map.update!(state.zone_agents, zone_id, &MapSet.put(&1, agent_id)),
        agent_zones: update_agent_zones(state.agent_zones, agent_id, zone_id),
        next_registration_id: state.next_registration_id + 1
      }
      
      Logger.info("Registered agent #{agent_id} in zone #{zone_id}")
      {:reply, {:ok, registration_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to register agent: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:remove_agent, zone_id, agent_id, reason}, _from, state) do
    # Verify the zone and registration exist
    with {:ok, zone} <- get_zone_from_state(state, zone_id),
         {:ok, registration_id} <- find_registration(state, zone_id, agent_id) do
      
      # Get the registration
      registration = Map.get(state.registrations, registration_id)
      
      # Update registration status
      updated_registration = %{
        registration |
        status: :removed,
        removal_reason: reason,
        removed_at: DateTime.utc_now()
      }
      
      # Update zone agent count
      updated_zone = Map.update!(zone, :agent_count, &(&1 - 1))
      
      # Update state
      updated_state = %{
        state |
        zones: Map.put(state.zones, zone_id, updated_zone),
        registrations: Map.put(state.registrations, registration_id, updated_registration),
        zone_agents: Map.update!(state.zone_agents, zone_id, &MapSet.delete(&1, agent_id)),
        agent_zones: update_agent_zones_removal(state.agent_zones, agent_id, zone_id)
      }
      
      Logger.info("Removed agent #{agent_id} from zone #{zone_id}")
      {:reply, :ok, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to remove agent: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_zone, zone_id}, _from, state) do
    case Map.fetch(state.zones, zone_id) do
      {:ok, zone} -> {:reply, {:ok, zone}, state}
      :error -> {:reply, {:error, :zone_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:list_zones, filters}, _from, state) do
    # Apply filters
    filtered_zones = state.zones
    |> Map.values()
    |> Enum.filter(fn zone ->
      Enum.all?(filters, fn {key, value} ->
        Map.get(zone, key) == value
      end)
    end)
    |> Enum.sort_by(& &1.created_at, DateTime)
    
    {:reply, {:ok, filtered_zones}, state}
  end
  
  @impl true
  def handle_call({:check_agent_registration, zone_id, agent_id}, _from, state) do
    with {:ok, _zone} <- get_zone_from_state(state, zone_id) do
      case find_registration(state, zone_id, agent_id) do
        {:ok, registration_id} ->
          registration = Map.get(state.registrations, registration_id)
          
          if registration.status == :active do
            {:reply, {:ok, registration}, state}
          else
            {:reply, {:error, :not_registered}, state}
          end
        
        {:error, _reason} ->
          {:reply, {:error, :not_registered}, state}
      end
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:update_agent_roles, zone_id, agent_id, roles}, _from, state) do
    with {:ok, _zone} <- get_zone_from_state(state, zone_id),
         {:ok, registration_id} <- find_registration(state, zone_id, agent_id) do
      
      # Get the registration
      registration = Map.get(state.registrations, registration_id)
      
      # Update roles
      updated_registration = %{registration | roles: roles, updated_at: DateTime.utc_now()}
      
      # Update state
      updated_state = %{
        state |
        registrations: Map.put(state.registrations, registration_id, updated_registration)
      }
      
      Logger.info("Updated roles for agent #{agent_id} in zone #{zone_id}")
      {:reply, {:ok, updated_registration}, updated_state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:list_agents_in_zone, zone_id}, _from, state) do
    with {:ok, _zone} <- get_zone_from_state(state, zone_id) do
      agent_ids = Map.get(state.zone_agents, zone_id, MapSet.new())
      
      # Get active registrations for these agents
      agents = agent_ids
      |> Enum.map(fn agent_id ->
        case find_registration(state, zone_id, agent_id) do
          {:ok, registration_id} ->
            Map.get(state.registrations, registration_id)
          
          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(& &1.status == :active)
      
      {:reply, {:ok, agents}, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:update_zone_config, zone_id, config_changes}, _from, state) do
    with {:ok, zone} <- get_zone_from_state(state, zone_id) do
      # Apply changes
      updated_zone = Map.merge(zone, config_changes)
      |> Map.put(:updated_at, DateTime.utc_now())
      
      # Update state
      updated_state = %{
        state |
        zones: Map.put(state.zones, zone_id, updated_zone)
      }
      
      Logger.info("Updated configuration for zone #{zone_id}")
      {:reply, {:ok, updated_zone}, updated_state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  # Helper functions
  
  defp validate_zone_config(config) do
    # Basic validation of zone configuration
    if !is_map(config) do
      {:error, "Configuration must be a map"}
    else
      # Check decision mechanism is valid
      decision_mechanism = Map.get(config, :decision_mechanism, :majority)
      
      if decision_mechanism not in [:majority, :consensus, :weighted, :threshold] do
        {:error, "Invalid decision mechanism: #{decision_mechanism}"}
      else
        :ok
      end
    end
  end
  
  defp get_zone_from_state(state, zone_id) do
    case Map.fetch(state.zones, zone_id) do
      {:ok, zone} -> 
        if zone.status == :active do
          {:ok, zone}
        else
          {:error, :zone_inactive}
        end
      
      :error -> 
        {:error, :zone_not_found}
    end
  end
  
  defp check_agent_not_registered(state, zone_id, agent_id) do
    agent_ids = Map.get(state.zone_agents, zone_id, MapSet.new())
    
    if MapSet.member?(agent_ids, agent_id) do
      # Check if current registration is active
      case find_registration(state, zone_id, agent_id) do
        {:ok, registration_id} ->
          registration = Map.get(state.registrations, registration_id)
          
          if registration.status == :active do
            {:error, :already_registered}
          else
            # Previous registration was removed, so okay to register again
            :ok
          end
        
        {:error, _} ->
          # No registration found despite being in zone_agents (shouldn't happen)
          :ok
      end
    else
      :ok
    end
  end
  
  defp update_agent_zones(agent_zones, agent_id, zone_id) do
    Map.update(agent_zones, agent_id, MapSet.new([zone_id]), fn zones ->
      MapSet.put(zones, zone_id)
    end)
  end
  
  defp update_agent_zones_removal(agent_zones, agent_id, zone_id) do
    case Map.fetch(agent_zones, agent_id) do
      {:ok, zones} ->
        updated_zones = MapSet.delete(zones, zone_id)
        
        if MapSet.size(updated_zones) == 0 do
          Map.delete(agent_zones, agent_id)
        else
          Map.put(agent_zones, agent_id, updated_zones)
        end
      
      :error ->
        agent_zones
    end
  end
  
  defp find_registration(state, zone_id, agent_id) do
    # Find registration by zone_id and agent_id
    registration = Enum.find_value(state.registrations, fn {id, reg} ->
      if reg.zone_id == zone_id && reg.agent_id == agent_id do
        {id, reg}
      end
    end)
    
    case registration do
      {id, _reg} -> {:ok, id}
      nil -> {:error, :registration_not_found}
    end
  end
  
  defp validate_agent_requirements(_zone, _agent_id) do
    # In a real implementation, this would check if agent meets zone requirements
    # For now, we'll assume all agents meet requirements
    :ok
  end
end