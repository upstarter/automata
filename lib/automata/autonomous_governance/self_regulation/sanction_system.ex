defmodule Automata.AutonomousGovernance.SelfRegulation.SanctionSystem do
  @moduledoc """
  System for applying sanctions to agents that violate norms.
  
  This module provides functionality for:
  - Defining sanction types
  - Applying sanctions to agents
  - Tracking sanction history
  - Managing sanction effectiveness
  
  Sanctions serve as consequences for norm violations and incentivize compliance.
  """
  
  use GenServer
  require Logger
  
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  alias Automata.AutonomousGovernance.SelfRegulation.NormManager
  
  @type agent_id :: binary()
  @type norm_id :: binary()
  @type sanction_id :: binary()
  @type sanction_type :: atom()
  
  # Built-in sanction types
  @default_sanction_types %{
    # Reputation-based sanctions
    reputation_penalty: %{
      description: "Reduces agent's reputation score",
      resource_impact: :none,
      capability_impact: :none,
      reversible: true,
      duration: nil # Permanent until reversed
    },
    
    reputation_timeout: %{
      description: "Temporarily reduces agent's reputation score",
      resource_impact: :none,
      capability_impact: :none,
      reversible: true,
      duration: 3600 # 1 hour by default
    },
    
    # Resource-based sanctions
    resource_penalty: %{
      description: "Reduces agent's resources",
      resource_impact: :negative,
      capability_impact: :none,
      reversible: false,
      duration: nil
    },
    
    resource_freeze: %{
      description: "Temporarily freezes agent's resource access",
      resource_impact: :block,
      capability_impact: :none,
      reversible: true,
      duration: 3600
    },
    
    # Capability-based sanctions
    capability_restriction: %{
      description: "Restricts specific agent capabilities",
      resource_impact: :none,
      capability_impact: :restrict,
      reversible: true,
      duration: nil
    },
    
    capability_timeout: %{
      description: "Temporarily restricts agent capabilities",
      resource_impact: :none,
      capability_impact: :restrict,
      reversible: true,
      duration: 3600
    },
    
    # Combined sanctions
    zone_exclusion: %{
      description: "Excludes agent from a governance zone",
      resource_impact: :block,
      capability_impact: :block,
      reversible: true,
      duration: nil
    },
    
    probation: %{
      description: "Places agent on probation with increased monitoring",
      resource_impact: :none,
      capability_impact: :none,
      reversible: true,
      duration: 86400, # 24 hours
      additional: [
        monitor_level: :high,
        compliance_threshold: 0.9
      ]
    },
    
    # Positive sanctions (rewards)
    reputation_bonus: %{
      description: "Increases agent's reputation score",
      resource_impact: :none,
      capability_impact: :none,
      reversible: true,
      positive: true,
      duration: nil
    },
    
    resource_bonus: %{
      description: "Increases agent's resources",
      resource_impact: :positive,
      capability_impact: :none,
      reversible: false,
      positive: true,
      duration: nil
    }
  }
  
  # Client API
  
  @doc """
  Starts the Sanction System.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Applies a sanction to an agent based on norm violations.
  
  ## Parameters
  - agent_id: ID of the agent to sanction
  - norm_id: ID of the violated norm
  - sanction_type: Type of sanction to apply
  - parameters: Parameters specific to the sanction type
  
  ## Returns
  - `{:ok, sanction_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec apply_sanction(agent_id(), norm_id(), sanction_type(), map()) :: 
    {:ok, sanction_id()} | {:error, term()}
  def apply_sanction(agent_id, norm_id, sanction_type, parameters) do
    GenServer.call(__MODULE__, {:apply_sanction, agent_id, norm_id, sanction_type, parameters})
  end
  
  @doc """
  Defines a new sanction type.
  
  ## Parameters
  - name: Name of the sanction type (atom)
  - definition: Definition of the sanction type
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec define_sanction_type(atom(), map()) :: :ok | {:error, term()}
  def define_sanction_type(name, definition) do
    GenServer.call(__MODULE__, {:define_sanction_type, name, definition})
  end
  
  @doc """
  Lists all available sanction types.
  
  ## Returns
  - `{:ok, sanction_types}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_sanction_types() :: {:ok, map()} | {:error, term()}
  def list_sanction_types do
    GenServer.call(__MODULE__, :list_sanction_types)
  end
  
  @doc """
  Lists all sanctions for a specific agent.
  
  ## Parameters
  - agent_id: ID of the agent
  
  ## Returns
  - `{:ok, sanctions}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_agent_sanctions(agent_id()) :: {:ok, list(map())} | {:error, term()}
  def list_agent_sanctions(agent_id) do
    GenServer.call(__MODULE__, {:list_agent_sanctions, agent_id})
  end
  
  @doc """
  Removes a sanction.
  
  ## Parameters
  - sanction_id: ID of the sanction to remove
  - reason: Reason for removal
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec remove_sanction(sanction_id(), binary()) :: :ok | {:error, term()}
  def remove_sanction(sanction_id, reason) do
    GenServer.call(__MODULE__, {:remove_sanction, sanction_id, reason})
  end
  
  @doc """
  Checks if a sanction is active.
  
  ## Parameters
  - sanction_id: ID of the sanction
  
  ## Returns
  - `{:ok, boolean()}` if successful
  - `{:error, reason}` if failed
  """
  @spec is_sanction_active(sanction_id()) :: {:ok, boolean()} | {:error, term()}
  def is_sanction_active(sanction_id) do
    GenServer.call(__MODULE__, {:is_sanction_active, sanction_id})
  end
  
  @doc """
  Gets sanctions applicable to a specific norm.
  
  ## Parameters
  - norm_id: ID of the norm
  
  ## Returns
  - `{:ok, sanctions}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_norm_sanctions(norm_id()) :: {:ok, list(atom())} | {:error, term()}
  def get_norm_sanctions(norm_id) do
    GenServer.call(__MODULE__, {:get_norm_sanctions, norm_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Sanction System")
    
    # Schedule periodic cleanup of expired sanctions
    schedule_sanction_cleanup()
    
    # Initialize with default sanction types
    initial_state = %{
      sanctions: %{},
      agent_sanctions: %{},
      norm_sanctions: %{},
      sanction_types: @default_sanction_types,
      next_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:apply_sanction, agent_id, norm_id, sanction_type, parameters}, _from, state) do
    # Validate the norm exists
    with {:ok, norm} <- NormManager.get_norm(norm_id),
         {:ok, sanction_def} <- get_sanction_type(state, sanction_type) do
      
      # Generate sanction ID
      sanction_id = "sanction_#{state.next_id}"
      
      # Determine expiration
      expiration = case sanction_def.duration do
        nil -> nil
        duration -> 
          now = DateTime.utc_now()
          DateTime.add(now, duration, :second)
      end
      
      # Create sanction record
      timestamp = DateTime.utc_now()
      sanction = %{
        id: sanction_id,
        agent_id: agent_id,
        norm_id: norm_id,
        type: sanction_type,
        parameters: parameters,
        created_at: timestamp,
        expires_at: expiration,
        active: true,
        sanction_def: sanction_def,
        removed: false,
        removal_reason: nil,
        removal_timestamp: nil
      }
      
      # Update state
      updated_state = %{
        state |
        sanctions: Map.put(state.sanctions, sanction_id, sanction),
        agent_sanctions: update_agent_sanctions(state.agent_sanctions, agent_id, sanction_id),
        norm_sanctions: update_norm_sanctions(state.norm_sanctions, norm_id, sanction_id),
        next_id: state.next_id + 1
      }
      
      # Execute the sanction
      execute_sanction(sanction)
      
      Logger.info("Applied sanction #{sanction_type} to agent #{agent_id} for norm #{norm_id}")
      {:reply, {:ok, sanction_id}, updated_state}
    else
      {:error, :norm_not_found} = error ->
        Logger.error("Failed to apply sanction: norm not found")
        {:reply, error, state}
      
      {:error, :invalid_sanction_type} = error ->
        Logger.error("Failed to apply sanction: invalid sanction type #{sanction_type}")
        {:reply, error, state}
      
      {:error, reason} = error ->
        Logger.error("Failed to apply sanction: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:define_sanction_type, name, definition}, _from, state) do
    if Map.has_key?(state.sanction_types, name) do
      {:reply, {:error, :sanction_type_already_exists}, state}
    else
      # Validate the definition
      with :ok <- validate_sanction_definition(definition) do
        # Add the new sanction type
        updated_state = %{
          state |
          sanction_types: Map.put(state.sanction_types, name, definition)
        }
        
        Logger.info("Defined new sanction type: #{name}")
        {:reply, :ok, updated_state}
      else
        {:error, reason} = error ->
          Logger.error("Failed to define sanction type: #{reason}")
          {:reply, error, state}
      end
    end
  end
  
  @impl true
  def handle_call(:list_sanction_types, _from, state) do
    {:reply, {:ok, state.sanction_types}, state}
  end
  
  @impl true
  def handle_call({:list_agent_sanctions, agent_id}, _from, state) do
    # Get all sanctions for this agent
    sanction_ids = Map.get(state.agent_sanctions, agent_id, MapSet.new())
    sanctions = Enum.map(sanction_ids, &Map.get(state.sanctions, &1)) |> Enum.reject(&is_nil/1)
    
    # Sort by creation time
    sorted_sanctions = Enum.sort_by(sanctions, & &1.created_at, DateTime)
    
    {:reply, {:ok, sorted_sanctions}, state}
  end
  
  @impl true
  def handle_call({:remove_sanction, sanction_id, reason}, _from, state) do
    case Map.fetch(state.sanctions, sanction_id) do
      {:ok, sanction} ->
        if sanction.removed do
          # Sanction already removed
          {:reply, {:error, :sanction_already_removed}, state}
        else
          # Update the sanction record
          timestamp = DateTime.utc_now()
          updated_sanction = %{
            sanction |
            active: false,
            removed: true,
            removal_reason: reason,
            removal_timestamp: timestamp
          }
          
          # Update state
          updated_state = %{
            state |
            sanctions: Map.put(state.sanctions, sanction_id, updated_sanction)
          }
          
          # Reverse the sanction effect if needed
          if updated_sanction.sanction_def.reversible do
            reverse_sanction(updated_sanction)
          end
          
          Logger.info("Removed sanction #{sanction_id} for reason: #{reason}")
          {:reply, :ok, updated_state}
        end
      
      :error ->
        {:reply, {:error, :sanction_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:is_sanction_active, sanction_id}, _from, state) do
    case Map.fetch(state.sanctions, sanction_id) do
      {:ok, sanction} ->
        is_active = sanction.active && !sanction.removed && !is_expired(sanction)
        {:reply, {:ok, is_active}, state}
      
      :error ->
        {:reply, {:error, :sanction_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:get_norm_sanctions, norm_id}, _from, state) do
    case NormManager.get_norm(norm_id) do
      {:ok, norm} ->
        {:reply, {:ok, norm.sanctions}, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_info(:cleanup_expired_sanctions, state) do
    # Get current time
    now = DateTime.utc_now()
    
    # Find expired sanctions that are still active
    {expired_sanctions, updated_sanctions} = Enum.reduce(state.sanctions, {[], state.sanctions}, 
      fn {id, sanction}, {expired, sanctions_acc} ->
        if sanction.active && !sanction.removed && is_expired_at(sanction, now) do
          # Mark as expired
          updated_sanction = %{sanction | active: false}
          {[updated_sanction | expired], Map.put(sanctions_acc, id, updated_sanction)}
        else
          {expired, sanctions_acc}
        end
      end)
    
    # Handle the expired sanctions
    Enum.each(expired_sanctions, fn sanction ->
      Logger.info("Sanction #{sanction.id} expired")
      
      # If the sanction is reversible, reverse its effect
      if sanction.sanction_def.reversible do
        reverse_sanction(sanction)
      end
    end)
    
    # Schedule next cleanup
    schedule_sanction_cleanup()
    
    {:noreply, %{state | sanctions: updated_sanctions}}
  end
  
  # Helper functions
  
  defp get_sanction_type(state, sanction_type) do
    case Map.fetch(state.sanction_types, sanction_type) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :invalid_sanction_type}
    end
  end
  
  defp update_agent_sanctions(agent_sanctions, agent_id, sanction_id) do
    Map.update(agent_sanctions, agent_id, MapSet.new([sanction_id]), fn ids ->
      MapSet.put(ids, sanction_id)
    end)
  end
  
  defp update_norm_sanctions(norm_sanctions, norm_id, sanction_id) do
    Map.update(norm_sanctions, norm_id, MapSet.new([sanction_id]), fn ids ->
      MapSet.put(ids, sanction_id)
    end)
  end
  
  defp validate_sanction_definition(definition) do
    required_fields = [:description, :resource_impact, :capability_impact, :reversible, :duration]
    
    missing_fields = Enum.filter(required_fields, fn field -> 
      !Map.has_key?(definition, field)
    end)
    
    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
  
  defp is_expired(sanction) do
    case sanction.expires_at do
      nil -> false
      expiration -> DateTime.compare(DateTime.utc_now(), expiration) in [:gt, :eq]
    end
  end
  
  defp is_expired_at(sanction, now) do
    case sanction.expires_at do
      nil -> false
      expiration -> DateTime.compare(now, expiration) in [:gt, :eq]
    end
  end
  
  defp schedule_sanction_cleanup do
    # Run cleanup every 5 minutes
    Process.send_after(self(), :cleanup_expired_sanctions, 5 * 60 * 1000)
  end
  
  defp execute_sanction(sanction) do
    # Store the sanction in the knowledge system
    KnowledgeSystem.add_knowledge_item("sanctions", "applied_sanction", %{
      id: sanction.id,
      agent_id: sanction.agent_id,
      norm_id: sanction.norm_id,
      type: sanction.type,
      timestamp: sanction.created_at,
      expires_at: sanction.expires_at,
      parameters: sanction.parameters
    })
    
    # Execute the actual sanctions - in a real system this would interact with
    # the agent management system to apply constraints
    case sanction.type do
      type when type in [:reputation_penalty, :reputation_timeout] ->
        # Handled by ReputationSystem, nothing to do here
        :ok
      
      type when type in [:resource_penalty, :resource_freeze] ->
        # Would interact with resource management system
        :ok
      
      type when type in [:capability_restriction, :capability_timeout] ->
        # Would interact with agent capability management
        :ok
      
      :zone_exclusion ->
        # Would interact with governance zone management
        :ok
      
      :probation ->
        # Would set up enhanced monitoring for the agent
        :ok
      
      type when type in [:reputation_bonus, :resource_bonus] ->
        # Positive sanctions - would apply benefits
        :ok
      
      _ ->
        # Unknown sanction type
        Logger.warning("No implementation for sanction type: #{sanction.type}")
    end
  end
  
  defp reverse_sanction(sanction) do
    # This would undo the effects of the sanction
    case sanction.type do
      type when type in [:reputation_penalty, :reputation_timeout] ->
        # Would restore reputation
        :ok
      
      :resource_freeze ->
        # Would unfreeze resources
        :ok
      
      type when type in [:capability_restriction, :capability_timeout] ->
        # Would restore capabilities
        :ok
      
      :zone_exclusion ->
        # Would restore zone access
        :ok
      
      :probation ->
        # Would end enhanced monitoring
        :ok
      
      :reputation_bonus ->
        # Would remove bonus
        :ok
      
      _ ->
        # Either not reversible or unknown sanction type
        :ok
    end
  end
end