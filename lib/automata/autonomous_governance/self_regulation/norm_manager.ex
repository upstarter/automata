defmodule Automata.AutonomousGovernance.SelfRegulation.NormManager do
  @moduledoc """
  Manager for social norms within the self-regulation system.
  
  This module provides functionality for:
  - Defining and storing norms
  - Retrieving norm information
  - Tracking norm contexts
  - Supporting norm emergence
  
  Norms represent social rules and expectations for agent behavior in the system.
  """
  
  use GenServer
  require Logger
  alias Automata.AutonomousGovernance.SelfRegulation.NormManager
  
  @type norm_id :: binary()
  @type context :: binary()
  @type norm_spec :: map()
  
  # Client API
  
  @doc """
  Starts the Norm Manager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Defines a norm within the system.
  
  ## Parameters
  - name: The name of the norm
  - specification: Map containing the norm's specification
    - description: Description of the norm
    - condition: Condition that triggers norm evaluation
    - compliance: Criteria for compliance
    - violation: Criteria for violation
    - sanctions: List of sanction types applicable for violations
  - contexts: List of contexts where this norm applies
  
  ## Returns
  - `{:ok, norm_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec define_norm(binary(), norm_spec(), list(context())) :: 
    {:ok, norm_id()} | {:error, term()}
  def define_norm(name, specification, contexts \\ []) do
    GenServer.call(__MODULE__, {:define_norm, name, specification, contexts})
  end
  
  @doc """
  Lists all norms in the system, optionally filtered by context.
  
  ## Parameters
  - context: Optional context to filter norms
  
  ## Returns
  - `{:ok, norms}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_norms(context() | nil) :: {:ok, list(map())} | {:error, term()}
  def list_norms(context \\ nil) do
    GenServer.call(__MODULE__, {:list_norms, context})
  end
  
  @doc """
  Gets details about a specific norm.
  
  ## Parameters
  - norm_id: ID of the norm
  
  ## Returns
  - `{:ok, norm}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_norm(norm_id()) :: {:ok, map()} | {:error, term()}
  def get_norm(norm_id) do
    GenServer.call(__MODULE__, {:get_norm, norm_id})
  end
  
  @doc """
  Updates an existing norm.
  
  ## Parameters
  - norm_id: ID of the norm to update
  - updates: Map of fields to update
  
  ## Returns
  - `{:ok, norm}` if successful
  - `{:error, reason}` if failed
  """
  @spec update_norm(norm_id(), map()) :: {:ok, map()} | {:error, term()}
  def update_norm(norm_id, updates) do
    GenServer.call(__MODULE__, {:update_norm, norm_id, updates})
  end
  
  @doc """
  Adds a context to a norm.
  
  ## Parameters
  - norm_id: ID of the norm
  - context: Context to add
  
  ## Returns
  - `{:ok, norm}` if successful
  - `{:error, reason}` if failed
  """
  @spec add_context(norm_id(), context()) :: {:ok, map()} | {:error, term()}
  def add_context(norm_id, context) do
    GenServer.call(__MODULE__, {:add_context, norm_id, context})
  end
  
  @doc """
  Removes a context from a norm.
  
  ## Parameters
  - norm_id: ID of the norm
  - context: Context to remove
  
  ## Returns
  - `{:ok, norm}` if successful
  - `{:error, reason}` if failed
  """
  @spec remove_context(norm_id(), context()) :: {:ok, map()} | {:error, term()}
  def remove_context(norm_id, context) do
    GenServer.call(__MODULE__, {:remove_context, norm_id, context})
  end
  
  @doc """
  Proposes a norm emergence based on observed patterns.
  
  ## Parameters
  - pattern: The observed pattern that suggests a new norm
  - context: The context where this pattern was observed
  
  ## Returns
  - `{:ok, norm_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec propose_norm_emergence(map(), context()) :: {:ok, norm_id()} | {:error, term()}
  def propose_norm_emergence(pattern, context) do
    GenServer.call(__MODULE__, {:propose_norm_emergence, pattern, context})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Norm Manager")
    
    # Initialize with empty state
    initial_state = %{
      norms: %{},
      context_index: %{},
      next_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:define_norm, name, specification, contexts}, _from, state) do
    # Validate norm specification
    with :ok <- validate_norm_spec(specification) do
      # Generate a unique ID for the norm
      norm_id = "norm_#{state.next_id}"
      
      # Create the norm record
      norm = %{
        id: norm_id,
        name: name,
        description: Map.get(specification, :description, ""),
        condition: Map.get(specification, :condition, %{}),
        compliance: Map.get(specification, :compliance, %{}),
        violation: Map.get(specification, :violation, %{}),
        sanctions: Map.get(specification, :sanctions, []),
        contexts: contexts,
        auto_sanctions: Map.get(specification, :auto_sanctions, nil),
        compliance_weight: Map.get(specification, :compliance_weight, 1.0),
        violation_weight: Map.get(specification, :violation_weight, 1.0),
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
      
      # Update the context index
      updated_context_index = update_context_index(state.context_index, norm_id, contexts, [])
      
      # Update the state
      updated_state = %{
        state |
        norms: Map.put(state.norms, norm_id, norm),
        context_index: updated_context_index,
        next_id: state.next_id + 1
      }
      
      Logger.info("Defined new norm: #{name} (#{norm_id})")
      {:reply, {:ok, norm_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to define norm: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:list_norms, nil}, _from, state) do
    # Return all norms when no context filter is provided
    norms = state.norms |> Map.values() |> Enum.sort_by(& &1.created_at, DateTime)
    {:reply, {:ok, norms}, state}
  end
  
  @impl true
  def handle_call({:list_norms, context}, _from, state) do
    # Return norms filtered by context
    norm_ids = Map.get(state.context_index, context, MapSet.new())
    
    norms = norm_ids
    |> Enum.map(fn id -> Map.get(state.norms, id) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.created_at, DateTime)
    
    {:reply, {:ok, norms}, state}
  end
  
  @impl true
  def handle_call({:get_norm, norm_id}, _from, state) do
    case Map.fetch(state.norms, norm_id) do
      {:ok, norm} -> {:reply, {:ok, norm}, state}
      :error -> {:reply, {:error, :norm_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:update_norm, norm_id, updates}, _from, state) do
    case Map.fetch(state.norms, norm_id) do
      {:ok, norm} ->
        # Apply updates to the norm
        updated_norm = Map.merge(norm, updates) |> Map.put(:updated_at, DateTime.utc_now())
        
        # Handle context changes if present
        {updated_norm, updated_context_index} = case Map.get(updates, :contexts) do
          nil -> {updated_norm, state.context_index}
          new_contexts -> 
            {
              updated_norm,
              update_context_index(state.context_index, norm_id, new_contexts, norm.contexts)
            }
        end
        
        # Update the state
        updated_state = %{
          state |
          norms: Map.put(state.norms, norm_id, updated_norm),
          context_index: updated_context_index
        }
        
        Logger.info("Updated norm: #{norm.name} (#{norm_id})")
        {:reply, {:ok, updated_norm}, updated_state}
      
      :error ->
        {:reply, {:error, :norm_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:add_context, norm_id, context}, _from, state) do
    case Map.fetch(state.norms, norm_id) do
      {:ok, norm} ->
        if context in norm.contexts do
          # Context already exists, no change needed
          {:reply, {:ok, norm}, state}
        else
          # Add the context
          updated_contexts = [context | norm.contexts]
          updated_norm = %{norm | contexts: updated_contexts, updated_at: DateTime.utc_now()}
          
          # Update the context index
          updated_context_index = 
            state.context_index
            |> Map.update(context, MapSet.new([norm_id]), &MapSet.put(&1, norm_id))
          
          # Update the state
          updated_state = %{
            state |
            norms: Map.put(state.norms, norm_id, updated_norm),
            context_index: updated_context_index
          }
          
          Logger.info("Added context '#{context}' to norm: #{norm.name} (#{norm_id})")
          {:reply, {:ok, updated_norm}, updated_state}
        end
      
      :error ->
        {:reply, {:error, :norm_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:remove_context, norm_id, context}, _from, state) do
    case Map.fetch(state.norms, norm_id) do
      {:ok, norm} ->
        if context in norm.contexts do
          # Remove the context
          updated_contexts = Enum.reject(norm.contexts, &(&1 == context))
          updated_norm = %{norm | contexts: updated_contexts, updated_at: DateTime.utc_now()}
          
          # Update the context index
          updated_context_index = 
            state.context_index
            |> Map.update(context, MapSet.new(), &MapSet.delete(&1, norm_id))
          
          # Update the state
          updated_state = %{
            state |
            norms: Map.put(state.norms, norm_id, updated_norm),
            context_index: updated_context_index
          }
          
          Logger.info("Removed context '#{context}' from norm: #{norm.name} (#{norm_id})")
          {:reply, {:ok, updated_norm}, updated_state}
        else
          # Context wasn't there, no change needed
          {:reply, {:ok, norm}, state}
        end
      
      :error ->
        {:reply, {:error, :norm_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:propose_norm_emergence, pattern, context}, _from, state) do
    # Generate a proposed norm based on the observed pattern
    proposed_norm = generate_norm_from_pattern(pattern, context, state.next_id)
    
    # Define the new norm
    norm_id = "norm_#{state.next_id}"
    
    # Update the context index
    updated_context_index = 
      state.context_index
      |> Map.update(context, MapSet.new([norm_id]), &MapSet.put(&1, norm_id))
    
    # Update the state
    updated_state = %{
      state |
      norms: Map.put(state.norms, norm_id, proposed_norm),
      context_index: updated_context_index,
      next_id: state.next_id + 1
    }
    
    Logger.info("Proposed emergent norm: #{proposed_norm.name} (#{norm_id}) in context '#{context}'")
    {:reply, {:ok, norm_id}, updated_state}
  end
  
  # Helper functions
  
  defp validate_norm_spec(spec) do
    required_fields = [:description, :condition]
    
    missing_fields = Enum.filter(required_fields, fn field -> 
      !Map.has_key?(spec, field) || is_nil(Map.get(spec, field))
    end)
    
    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
  
  defp update_context_index(context_index, norm_id, new_contexts, old_contexts) do
    # Remove from old contexts that are not in new contexts
    contexts_to_remove = old_contexts -- new_contexts
    context_index_after_removals = Enum.reduce(contexts_to_remove, context_index, fn context, acc ->
      Map.update(acc, context, MapSet.new(), &MapSet.delete(&1, norm_id))
    end)
    
    # Add to new contexts that are not in old contexts
    contexts_to_add = new_contexts -- old_contexts
    Enum.reduce(contexts_to_add, context_index_after_removals, fn context, acc ->
      Map.update(acc, context, MapSet.new([norm_id]), &MapSet.put(&1, norm_id))
    end)
  end
  
  defp generate_norm_from_pattern(pattern, context, next_id) do
    # Extract relevant information from the pattern to create a norm
    action_type = Map.get(pattern, :action_type, "unknown_action")
    frequency = Map.get(pattern, :frequency, 0)
    impact = Map.get(pattern, :impact, 0)
    
    # Determine if this should be a positive or negative norm based on impact
    {norm_type, compliance, violation} = if impact >= 0 do
      # Positive impact - encourage this behavior
      {
        "encourage",
        %{action: action_type, conditions: Map.get(pattern, :conditions, %{})},
        %{action: "not_#{action_type}", conditions: Map.get(pattern, :conditions, %{})}
      }
    else
      # Negative impact - discourage this behavior
      {
        "discourage",
        %{action: "not_#{action_type}", conditions: Map.get(pattern, :conditions, %{})},
        %{action: action_type, conditions: Map.get(pattern, :conditions, %{})}
      }
    end
    
    # Create name and description based on pattern
    name = "#{norm_type}_#{action_type}_#{context}_#{next_id}"
    description = "Emergent norm to #{norm_type} #{action_type} in context '#{context}'"
    
    # Define appropriate sanctions based on norm type
    sanctions = if norm_type == "discourage" do
      [
        :reputation_penalty,
        :resource_penalty
      ]
    else
      [
        :reputation_bonus,
        :resource_bonus
      ]
    end
    
    # Create the norm record
    %{
      id: "norm_#{next_id}",
      name: name,
      description: description,
      condition: %{
        context: context,
        action: action_type,
        frequency_threshold: frequency * 0.8 # 80% of observed frequency
      },
      compliance: compliance,
      violation: violation,
      sanctions: sanctions,
      contexts: [context],
      auto_sanctions: nil, # No auto sanctions for emergent norms initially
      compliance_weight: abs(impact) * 0.5,
      violation_weight: abs(impact) * 0.5,
      emergent: true, # Flag this as an emergent norm
      confidence: 0.6, # Initial confidence in emergent norm
      pattern: pattern, # Store the original pattern that generated this norm
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end
end