defmodule Automata.AutonomousGovernance.AdaptiveInstitutions.InstitutionManager do
  @moduledoc """
  Manager for institutions within the adaptive institutions system.
  
  This module provides functionality for:
  - Creating and configuring institutions
  - Managing institution lifecycle
  - Tracking agent membership
  - Versioning institution rule systems
  
  Institutions represent structured rule systems that govern agent interactions.
  """
  
  use GenServer
  require Logger
  
  @type institution_id :: binary()
  @type agent_id :: binary()
  @type membership_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Institution Manager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Defines a new institution.
  
  ## Parameters
  - name: Name of the institution
  - config: Configuration for the institution
    - description: Description of the institution
    - purpose: Purpose of the institution
    - rule_system: Initial rule system
    - adaptation_mechanisms: Mechanisms for adaptation
    - governance_zone: Optional linked governance zone
  
  ## Returns
  - `{:ok, institution_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec define_institution(binary(), map()) :: {:ok, institution_id()} | {:error, term()}
  def define_institution(name, config) do
    GenServer.call(__MODULE__, {:define_institution, name, config})
  end
  
  @doc """
  Registers an agent to participate in an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  - agent_id: ID of the agent to register
  - parameters: Parameters for the registration
  
  ## Returns
  - `{:ok, membership_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec join_institution(institution_id(), agent_id(), map()) :: 
    {:ok, membership_id()} | {:error, term()}
  def join_institution(institution_id, agent_id, parameters \\ %{}) do
    GenServer.call(__MODULE__, {:join_institution, institution_id, agent_id, parameters})
  end
  
  @doc """
  Gets details about an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  
  ## Returns
  - `{:ok, institution}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_institution(institution_id()) :: {:ok, map()} | {:error, term()}
  def get_institution(institution_id) do
    GenServer.call(__MODULE__, {:get_institution, institution_id})
  end
  
  @doc """
  Lists all institutions, optionally filtered by criteria.
  
  ## Parameters
  - filters: Map of filters to apply
  
  ## Returns
  - `{:ok, institutions}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_institutions(map()) :: {:ok, list(map())} | {:error, term()}
  def list_institutions(filters \\ %{}) do
    GenServer.call(__MODULE__, {:list_institutions, filters})
  end
  
  @doc """
  Updates an institution's configuration.
  
  ## Parameters
  - institution_id: ID of the institution
  - updates: Map of updates to apply
  - version_increment: Whether to increment the version
  
  ## Returns
  - `{:ok, institution}` if successful
  - `{:error, reason}` if failed
  """
  @spec update_institution(institution_id(), map(), boolean()) :: 
    {:ok, map()} | {:error, term()}
  def update_institution(institution_id, updates, version_increment \\ true) do
    GenServer.call(__MODULE__, {:update_institution, institution_id, updates, version_increment})
  end
  
  @doc """
  Checks an agent's membership in an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  - agent_id: ID of the agent
  
  ## Returns
  - `{:ok, membership}` if agent is a member
  - `{:error, :not_a_member}` if agent is not a member
  - `{:error, reason}` for other errors
  """
  @spec check_membership(institution_id(), agent_id()) :: 
    {:ok, map()} | {:error, :not_a_member} | {:error, term()}
  def check_membership(institution_id, agent_id) do
    GenServer.call(__MODULE__, {:check_membership, institution_id, agent_id})
  end
  
  @doc """
  Updates an agent's roles in an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  - agent_id: ID of the agent
  - roles: New roles for the agent
  
  ## Returns
  - `{:ok, membership}` if successful
  - `{:error, reason}` if failed
  """
  @spec update_agent_roles(institution_id(), agent_id(), map()) :: 
    {:ok, map()} | {:error, term()}
  def update_agent_roles(institution_id, agent_id, roles) do
    GenServer.call(__MODULE__, {:update_agent_roles, institution_id, agent_id, roles})
  end
  
  @doc """
  Lists all members of an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  
  ## Returns
  - `{:ok, members}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_members(institution_id()) :: {:ok, list(map())} | {:error, term()}
  def list_members(institution_id) do
    GenServer.call(__MODULE__, {:list_members, institution_id})
  end
  
  @doc """
  Gets version history of an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  
  ## Returns
  - `{:ok, versions}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_version_history(institution_id()) :: {:ok, list(map())} | {:error, term()}
  def get_version_history(institution_id) do
    GenServer.call(__MODULE__, {:get_version_history, institution_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Institution Manager")
    
    # Initialize with empty state
    initial_state = %{
      institutions: %{},
      memberships: %{},
      institution_members: %{},
      agent_institutions: %{},
      version_history: %{},
      next_institution_id: 1,
      next_membership_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:define_institution, name, config}, _from, state) do
    # Validate configuration
    with :ok <- validate_institution_config(config) do
      # Generate institution ID
      institution_id = "institution_#{state.next_institution_id}"
      
      # Create institution record
      timestamp = DateTime.utc_now()
      institution = %{
        id: institution_id,
        name: name,
        description: Map.get(config, :description, ""),
        purpose: Map.get(config, :purpose, ""),
        rule_system: Map.get(config, :rule_system, %{}),
        adaptation_mechanisms: Map.get(config, :adaptation_mechanisms, %{}),
        governance_zone: Map.get(config, :governance_zone),
        created_at: timestamp,
        updated_at: timestamp,
        status: :active,
        version: 1,
        member_count: 0
      }
      
      # Create initial version history entry
      version_entry = %{
        institution_id: institution_id,
        version: 1,
        timestamp: timestamp,
        rule_system: institution.rule_system,
        description: "Initial version"
      }
      
      # Update state
      updated_state = %{
        state |
        institutions: Map.put(state.institutions, institution_id, institution),
        institution_members: Map.put(state.institution_members, institution_id, MapSet.new()),
        version_history: Map.update(
          state.version_history, 
          institution_id, 
          [version_entry], 
          &[version_entry | &1]
        ),
        next_institution_id: state.next_institution_id + 1
      }
      
      Logger.info("Created institution: #{name} (#{institution_id})")
      {:reply, {:ok, institution_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create institution: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:join_institution, institution_id, agent_id, parameters}, _from, state) do
    # Verify the institution exists
    with {:ok, institution} <- get_institution_from_state(state, institution_id),
         :ok <- check_agent_not_member(state, institution_id, agent_id) do
      
      # Generate membership ID
      membership_id = "membership_#{state.next_membership_id}"
      
      # Create membership record
      timestamp = DateTime.utc_now()
      membership = %{
        id: membership_id,
        institution_id: institution_id,
        agent_id: agent_id,
        roles: Map.get(parameters, :roles, %{}),
        joined_at: timestamp,
        updated_at: timestamp,
        status: :active
      }
      
      # Update institution member count
      updated_institution = Map.update!(institution, :member_count, &(&1 + 1))
      
      # Update state
      updated_state = %{
        state |
        institutions: Map.put(state.institutions, institution_id, updated_institution),
        memberships: Map.put(state.memberships, membership_id, membership),
        institution_members: Map.update!(state.institution_members, institution_id, &MapSet.put(&1, agent_id)),
        agent_institutions: update_agent_institutions(state.agent_institutions, agent_id, institution_id),
        next_membership_id: state.next_membership_id + 1
      }
      
      Logger.info("Agent #{agent_id} joined institution #{institution_id}")
      {:reply, {:ok, membership_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to join institution: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_institution, institution_id}, _from, state) do
    result = get_institution_from_state(state, institution_id)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:list_institutions, filters}, _from, state) do
    # Apply filters
    filtered_institutions = state.institutions
    |> Map.values()
    |> Enum.filter(fn institution ->
      Enum.all?(filters, fn {key, value} ->
        Map.get(institution, key) == value
      end)
    end)
    |> Enum.sort_by(& &1.created_at, DateTime)
    
    {:reply, {:ok, filtered_institutions}, state}
  end
  
  @impl true
  def handle_call({:update_institution, institution_id, updates, version_increment}, _from, state) do
    with {:ok, institution} <- get_institution_from_state(state, institution_id) do
      # Calculate new version if needed
      new_version = if version_increment, do: institution.version + 1, else: institution.version
      
      # Apply updates
      timestamp = DateTime.utc_now()
      updated_institution = Map.merge(institution, updates)
      |> Map.put(:updated_at, timestamp)
      |> Map.put(:version, new_version)
      
      # Create version history entry if version incremented
      updated_version_history = if version_increment do
        version_entry = %{
          institution_id: institution_id,
          version: new_version,
          timestamp: timestamp,
          rule_system: updated_institution.rule_system,
          description: Map.get(updates, :version_description, "Updated version")
        }
        
        Map.update(
          state.version_history, 
          institution_id, 
          [version_entry], 
          &[version_entry | &1]
        )
      else
        state.version_history
      end
      
      # Update state
      updated_state = %{
        state |
        institutions: Map.put(state.institutions, institution_id, updated_institution),
        version_history: updated_version_history
      }
      
      Logger.info("Updated institution #{institution_id}" <> 
                  if version_increment, do: " to version #{new_version}", else: "")
      {:reply, {:ok, updated_institution}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to update institution: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:check_membership, institution_id, agent_id}, _from, state) do
    with {:ok, _institution} <- get_institution_from_state(state, institution_id) do
      case find_membership(state, institution_id, agent_id) do
        {:ok, membership_id} ->
          membership = Map.get(state.memberships, membership_id)
          
          if membership.status == :active do
            {:reply, {:ok, membership}, state}
          else
            {:reply, {:error, :not_a_member}, state}
          end
        
        {:error, _reason} ->
          {:reply, {:error, :not_a_member}, state}
      end
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:update_agent_roles, institution_id, agent_id, roles}, _from, state) do
    with {:ok, _institution} <- get_institution_from_state(state, institution_id),
         {:ok, membership_id} <- find_membership(state, institution_id, agent_id) do
      
      # Get the membership
      membership = Map.get(state.memberships, membership_id)
      
      # Update roles
      updated_membership = %{membership | roles: roles, updated_at: DateTime.utc_now()}
      
      # Update state
      updated_state = %{
        state |
        memberships: Map.put(state.memberships, membership_id, updated_membership)
      }
      
      Logger.info("Updated roles for agent #{agent_id} in institution #{institution_id}")
      {:reply, {:ok, updated_membership}, updated_state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:list_members, institution_id}, _from, state) do
    with {:ok, _institution} <- get_institution_from_state(state, institution_id) do
      agent_ids = Map.get(state.institution_members, institution_id, MapSet.new())
      
      # Get active memberships for these agents
      members = agent_ids
      |> Enum.map(fn agent_id ->
        case find_membership(state, institution_id, agent_id) do
          {:ok, membership_id} ->
            Map.get(state.memberships, membership_id)
          
          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(& &1.status == :active)
      
      {:reply, {:ok, members}, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_version_history, institution_id}, _from, state) do
    with {:ok, _institution} <- get_institution_from_state(state, institution_id) do
      # Get version history and sort by version (descending)
      versions = Map.get(state.version_history, institution_id, [])
      |> Enum.sort_by(& &1.version, :desc)
      
      {:reply, {:ok, versions}, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  # Helper functions
  
  defp validate_institution_config(config) do
    # Basic validation
    if !is_map(config) do
      {:error, "Configuration must be a map"}
    else
      :ok
    end
  end
  
  defp get_institution_from_state(state, institution_id) do
    case Map.fetch(state.institutions, institution_id) do
      {:ok, institution} -> 
        if institution.status == :active do
          {:ok, institution}
        else
          {:error, :institution_inactive}
        end
      
      :error -> 
        {:error, :institution_not_found}
    end
  end
  
  defp check_agent_not_member(state, institution_id, agent_id) do
    agent_ids = Map.get(state.institution_members, institution_id, MapSet.new())
    
    if MapSet.member?(agent_ids, agent_id) do
      # Check if current membership is active
      case find_membership(state, institution_id, agent_id) do
        {:ok, membership_id} ->
          membership = Map.get(state.memberships, membership_id)
          
          if membership.status == :active do
            {:error, :already_a_member}
          else
            # Previous membership was removed, so okay to join again
            :ok
          end
        
        {:error, _} ->
          # No membership found despite being in institution_members (shouldn't happen)
          :ok
      end
    else
      :ok
    end
  end
  
  defp update_agent_institutions(agent_institutions, agent_id, institution_id) do
    Map.update(agent_institutions, agent_id, MapSet.new([institution_id]), fn institutions ->
      MapSet.put(institutions, institution_id)
    end)
  end
  
  defp find_membership(state, institution_id, agent_id) do
    # Find membership by institution_id and agent_id
    membership = Enum.find_value(state.memberships, fn {id, mem} ->
      if mem.institution_id == institution_id && mem.agent_id == agent_id do
        {id, mem}
      end
    end)
    
    case membership do
      {id, _mem} -> {:ok, id}
      nil -> {:error, :membership_not_found}
    end
  end
end