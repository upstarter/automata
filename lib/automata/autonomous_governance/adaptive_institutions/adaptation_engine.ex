defmodule Automata.AutonomousGovernance.AdaptiveInstitutions.AdaptationEngine do
  @moduledoc """
  Engine for managing adaptations to institutional arrangements.
  
  This module provides functionality for:
  - Proposing and implementing institutional adaptations
  - Tracking adaptation history and outcomes
  - Learning from adaptation experiences
  - Supporting evolutionary institutional development
  
  The adaptation engine enables institutions to evolve over time based on
  performance evaluations and changing environmental conditions.
  """
  
  use GenServer
  require Logger
  
  alias Automata.AutonomousGovernance.AdaptiveInstitutions.InstitutionManager
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @type institution_id :: binary()
  @type agent_id :: binary()
  @type adaptation_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Adaptation Engine.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Proposes an adaptation to an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  - agent_id: ID of the agent proposing the adaptation
  - adaptation: Map describing the proposed adaptation
    - type: Type of adaptation (:rule_change, :structure_change, :mechanism_change, etc.)
    - description: Description of the adaptation
    - changes: Map of changes to apply
    - justification: Justification for the adaptation
  
  ## Returns
  - `{:ok, adaptation_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec propose_adaptation(institution_id(), agent_id(), map()) :: 
    {:ok, adaptation_id()} | {:error, term()}
  def propose_adaptation(institution_id, agent_id, adaptation) do
    GenServer.call(__MODULE__, {:propose_adaptation, institution_id, agent_id, adaptation})
  end
  
  @doc """
  Implements an approved adaptation.
  
  ## Parameters
  - institution_id: ID of the institution
  - adaptation_id: ID of the adaptation to implement
  - metadata: Optional metadata about the implementation
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec implement_adaptation(institution_id(), adaptation_id(), map()) :: :ok | {:error, term()}
  def implement_adaptation(institution_id, adaptation_id, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:implement_adaptation, institution_id, adaptation_id, metadata})
  end
  
  @doc """
  Creates and implements a system-generated adaptation.
  
  ## Parameters
  - institution_id: ID of the institution
  - agent_id: ID of the agent or "system" for system-generated adaptations
  - adaptation: Map describing the adaptation
  
  ## Returns
  - `{:ok, adaptation_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec implement_adaptation(institution_id(), agent_id(), map()) :: 
    {:ok, adaptation_id()} | {:error, term()}
  def implement_adaptation(institution_id, agent_id, adaptation) do
    GenServer.call(__MODULE__, {:auto_implement_adaptation, institution_id, agent_id, adaptation})
  end
  
  @doc """
  Gets the adaptation history for an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  
  ## Returns
  - `{:ok, adaptations}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_adaptation_history(institution_id()) :: {:ok, list(map())} | {:error, term()}
  def get_adaptation_history(institution_id) do
    GenServer.call(__MODULE__, {:get_adaptation_history, institution_id})
  end
  
  @doc """
  Gets learning insights derived from institutional adaptation.
  
  ## Parameters
  - institution_id: ID of the institution
  
  ## Returns
  - `{:ok, insights}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_learning_insights(institution_id()) :: {:ok, map()} | {:error, term()}
  def get_learning_insights(institution_id) do
    GenServer.call(__MODULE__, {:get_learning_insights, institution_id})
  end
  
  @doc """
  Gets details about a specific adaptation.
  
  ## Parameters
  - adaptation_id: ID of the adaptation
  
  ## Returns
  - `{:ok, adaptation}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_adaptation(adaptation_id()) :: {:ok, map()} | {:error, term()}
  def get_adaptation(adaptation_id) do
    GenServer.call(__MODULE__, {:get_adaptation, adaptation_id})
  end
  
  @doc """
  Rejects an adaptation proposal.
  
  ## Parameters
  - institution_id: ID of the institution
  - adaptation_id: ID of the adaptation
  - reason: Reason for rejection
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec reject_adaptation(institution_id(), adaptation_id(), binary()) :: 
    :ok | {:error, term()}
  def reject_adaptation(institution_id, adaptation_id, reason) do
    GenServer.call(__MODULE__, {:reject_adaptation, institution_id, adaptation_id, reason})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Adaptation Engine")
    
    # Initialize with empty state
    initial_state = %{
      adaptations: %{},
      institution_adaptations: %{},
      learning_insights: %{},
      next_adaptation_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:propose_adaptation, institution_id, agent_id, adaptation}, _from, state) do
    with {:ok, institution} <- InstitutionManager.get_institution(institution_id),
         {:ok, _membership} <- InstitutionManager.check_membership(institution_id, agent_id),
         :ok <- validate_adaptation(adaptation) do
      
      # Generate adaptation ID
      adaptation_id = "adaptation_#{state.next_adaptation_id}"
      
      # Create adaptation record
      timestamp = DateTime.utc_now()
      adaptation_record = %{
        id: adaptation_id,
        institution_id: institution_id,
        proposer_id: agent_id,
        type: adaptation.type,
        description: adaptation.description,
        changes: adaptation.changes,
        justification: adaptation.justification,
        status: :proposed,
        proposed_at: timestamp,
        updated_at: timestamp,
        implemented_at: nil,
        rejection_reason: nil,
        outcome_data: nil
      }
      
      # Update state
      updated_state = %{
        state |
        adaptations: Map.put(state.adaptations, adaptation_id, adaptation_record),
        institution_adaptations: update_institution_adaptations(
          state.institution_adaptations, 
          institution_id, 
          adaptation_id
        ),
        next_adaptation_id: state.next_adaptation_id + 1
      }
      
      Logger.info("Proposed adaptation #{adaptation_id} for institution #{institution_id}")
      {:reply, {:ok, adaptation_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to propose adaptation: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:implement_adaptation, institution_id, adaptation_id, metadata}, _from, state) do
    with {:ok, _institution} <- InstitutionManager.get_institution(institution_id),
         {:ok, adaptation} <- get_adaptation_from_state(state, adaptation_id),
         :ok <- validate_adaptation_status(adaptation) do
      
      if adaptation.institution_id != institution_id do
        {:reply, {:error, :adaptation_not_for_institution}, state}
      else
        # Update adaptation status
        timestamp = DateTime.utc_now()
        updated_adaptation = %{
          adaptation |
          status: :implemented,
          implemented_at: timestamp,
          updated_at: timestamp,
          metadata: metadata
        }
        
        # Apply the adaptation to the institution
        case apply_adaptation_to_institution(institution_id, updated_adaptation) do
          {:ok, _} ->
            # Update the adaptation record
            updated_state = %{
              state |
              adaptations: Map.put(state.adaptations, adaptation_id, updated_adaptation)
            }
            
            # Update learning insights
            updated_state = update_learning_insights(updated_state, institution_id, updated_adaptation)
            
            Logger.info("Implemented adaptation #{adaptation_id} for institution #{institution_id}")
            {:reply, :ok, updated_state}
          
          {:error, reason} = error ->
            Logger.error("Failed to implement adaptation: #{reason}")
            {:reply, error, state}
        end
      end
    else
      {:error, reason} = error ->
        Logger.error("Failed to implement adaptation: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:auto_implement_adaptation, institution_id, agent_id, adaptation}, _from, state) do
    with {:ok, institution} <- InstitutionManager.get_institution(institution_id),
         :ok <- validate_adaptation(adaptation) do
      
      # Generate adaptation ID
      adaptation_id = "adaptation_#{state.next_adaptation_id}"
      
      # Create adaptation record
      timestamp = DateTime.utc_now()
      adaptation_record = %{
        id: adaptation_id,
        institution_id: institution_id,
        proposer_id: agent_id,
        type: adaptation.type,
        description: adaptation.description,
        changes: adaptation.changes,
        justification: adaptation.justification,
        status: :implemented, # Automatically implemented
        proposed_at: timestamp,
        updated_at: timestamp,
        implemented_at: timestamp,
        metadata: %{auto_implemented: true},
        rejection_reason: nil,
        outcome_data: nil
      }
      
      # Apply the adaptation to the institution
      case apply_adaptation_to_institution(institution_id, adaptation_record) do
        {:ok, _} ->
          # Update state
          updated_state = %{
            state |
            adaptations: Map.put(state.adaptations, adaptation_id, adaptation_record),
            institution_adaptations: update_institution_adaptations(
              state.institution_adaptations, 
              institution_id, 
              adaptation_id
            ),
            next_adaptation_id: state.next_adaptation_id + 1
          }
          
          # Update learning insights
          updated_state = update_learning_insights(updated_state, institution_id, adaptation_record)
          
          # Add to knowledge system
          KnowledgeSystem.add_knowledge_item("institutions", "adaptation", %{
            id: adaptation_id,
            institution_id: institution_id,
            proposer_id: agent_id,
            type: adaptation.type,
            description: adaptation.description,
            changes: adaptation.changes,
            justification: adaptation.justification,
            status: :implemented,
            proposed_at: timestamp,
            implemented_at: timestamp,
            auto_implemented: true
          })
          
          Logger.info("Auto-implemented adaptation #{adaptation_id} for institution #{institution_id}")
          {:reply, {:ok, adaptation_id}, updated_state}
        
        {:error, reason} = error ->
          Logger.error("Failed to auto-implement adaptation: #{reason}")
          {:reply, error, state}
      end
    else
      {:error, reason} = error ->
        Logger.error("Failed to auto-implement adaptation: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_adaptation_history, institution_id}, _from, state) do
    with {:ok, _institution} <- InstitutionManager.get_institution(institution_id) do
      # Get all adaptations for this institution
      adaptation_ids = Map.get(state.institution_adaptations, institution_id, [])
      adaptations = Enum.map(adaptation_ids, &Map.get(state.adaptations, &1))
                   |> Enum.reject(&is_nil/1)
      
      # Sort by timestamp (descending)
      sorted_adaptations = Enum.sort_by(adaptations, & &1.proposed_at, {:desc, DateTime})
      
      {:reply, {:ok, sorted_adaptations}, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_learning_insights, institution_id}, _from, state) do
    with {:ok, _institution} <- InstitutionManager.get_institution(institution_id) do
      insights = Map.get(state.learning_insights, institution_id, %{
        patterns: [],
        effective_adaptations: [],
        ineffective_adaptations: [],
        recommendations: []
      })
      
      {:reply, {:ok, insights}, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_adaptation, adaptation_id}, _from, state) do
    case Map.fetch(state.adaptations, adaptation_id) do
      {:ok, adaptation} -> {:reply, {:ok, adaptation}, state}
      :error -> {:reply, {:error, :adaptation_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:reject_adaptation, institution_id, adaptation_id, reason}, _from, state) do
    with {:ok, _institution} <- InstitutionManager.get_institution(institution_id),
         {:ok, adaptation} <- get_adaptation_from_state(state, adaptation_id),
         :ok <- validate_adaptation_status(adaptation) do
      
      if adaptation.institution_id != institution_id do
        {:reply, {:error, :adaptation_not_for_institution}, state}
      else
        # Update adaptation status
        timestamp = DateTime.utc_now()
        updated_adaptation = %{
          adaptation |
          status: :rejected,
          updated_at: timestamp,
          rejection_reason: reason
        }
        
        # Update state
        updated_state = %{
          state |
          adaptations: Map.put(state.adaptations, adaptation_id, updated_adaptation)
        }
        
        # Update knowledge system
        KnowledgeSystem.update_knowledge_item("institutions", "adaptation", adaptation_id, %{
          status: :rejected,
          rejection_reason: reason
        })
        
        Logger.info("Rejected adaptation #{adaptation_id} for institution #{institution_id}")
        {:reply, :ok, updated_state}
      end
    else
      {:error, reason} = error ->
        Logger.error("Failed to reject adaptation: #{reason}")
        {:reply, error, state}
    end
  end
  
  # Helper functions
  
  defp validate_adaptation(adaptation) do
    required_fields = [:type, :description, :changes]
    
    missing_fields = Enum.filter(required_fields, fn field -> 
      !Map.has_key?(adaptation, field) || is_nil(Map.get(adaptation, field))
    end)
    
    if Enum.empty?(missing_fields) do
      # Validate adaptation type
      if adaptation.type in [:rule_change, :structure_change, :mechanism_change, :role_change] do
        :ok
      else
        {:error, "Invalid adaptation type: #{adaptation.type}"}
      end
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
  
  defp validate_adaptation_status(adaptation) do
    if adaptation.status == :proposed do
      :ok
    else
      {:error, "Adaptation status is #{adaptation.status}, not proposed"}
    end
  end
  
  defp update_institution_adaptations(institution_adaptations, institution_id, adaptation_id) do
    Map.update(institution_adaptations, institution_id, [adaptation_id], fn ids ->
      [adaptation_id | ids]
    end)
  end
  
  defp get_adaptation_from_state(state, adaptation_id) do
    case Map.fetch(state.adaptations, adaptation_id) do
      {:ok, adaptation} -> {:ok, adaptation}
      :error -> {:error, :adaptation_not_found}
    end
  end
  
  defp apply_adaptation_to_institution(institution_id, adaptation) do
    # Get current institution state
    with {:ok, institution} <- InstitutionManager.get_institution(institution_id) do
      # Prepare updates based on adaptation type and changes
      updates = case adaptation.type do
        :rule_change ->
          prepare_rule_changes(institution, adaptation.changes)
        
        :structure_change ->
          prepare_structure_changes(institution, adaptation.changes)
        
        :mechanism_change ->
          prepare_mechanism_changes(institution, adaptation.changes)
        
        :role_change ->
          prepare_role_changes(institution, adaptation.changes)
      end
      
      # Add version description
      updates_with_description = Map.put(updates, :version_description, adaptation.description)
      
      # Update the institution
      InstitutionManager.update_institution(institution_id, updates_with_description, true)
    end
  end
  
  defp prepare_rule_changes(institution, changes) do
    # Prepare updates to the rule system
    current_rules = institution.rule_system
    
    # Apply changes - add, update, or remove rules
    updated_rules = if Map.has_key?(changes, :rules) do
      Enum.reduce(changes.rules, current_rules, fn {action, rules}, acc ->
        case action do
          :add ->
            Map.merge(acc, rules)
          
          :update ->
            Map.merge(acc, rules)
          
          :remove ->
            case rules do
              rule_ids when is_list(rule_ids) ->
                Map.drop(acc, rule_ids)
              
              _ ->
                acc
            end
        end
      end)
    else
      current_rules
    end
    
    %{rule_system: updated_rules}
  end
  
  defp prepare_structure_changes(institution, changes) do
    # Updates to the institution's structure
    structure_updates = %{}
    
    # Apply structural changes
    if Map.has_key?(changes, :governance_zone) do
      structure_updates = Map.put(structure_updates, :governance_zone, changes.governance_zone)
    end
    
    structure_updates
  end
  
  defp prepare_mechanism_changes(institution, changes) do
    # Updates to the adaptation mechanisms
    current_mechanisms = institution.adaptation_mechanisms
    
    # Apply changes to adaptation mechanisms
    updated_mechanisms = if Map.has_key?(changes, :adaptation_mechanisms) do
      Map.merge(current_mechanisms, changes.adaptation_mechanisms)
    else
      current_mechanisms
    end
    
    %{adaptation_mechanisms: updated_mechanisms}
  end
  
  defp prepare_role_changes(_institution, changes) do
    # Updates related to roles
    # In a real implementation, this would update role definitions
    # and potentially update agent roles
    %{}
  end
  
  defp update_learning_insights(state, institution_id, adaptation) do
    # Get current insights or initialize
    current_insights = Map.get(state.learning_insights, institution_id, %{
      patterns: [],
      effective_adaptations: [],
      ineffective_adaptations: [],
      recommendations: []
    })
    
    # Extract patterns from adaptations
    updated_insights = extract_adaptation_patterns(institution_id, adaptation, current_insights, state)
    
    # Update state with new insights
    %{state | learning_insights: Map.put(state.learning_insights, institution_id, updated_insights)}
  end
  
  defp extract_adaptation_patterns(institution_id, adaptation, current_insights, state) do
    # Get all adaptations for this institution
    adaptation_ids = Map.get(state.institution_adaptations, institution_id, [])
    adaptations = Enum.map(adaptation_ids, &Map.get(state.adaptations, &1))
                  |> Enum.reject(&is_nil/1)
    
    # Find patterns in adaptations
    type_patterns = Enum.frequencies_by(adaptations, & &1.type)
    
    # Identify most common adaptation types
    common_types = type_patterns
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {type, count} -> %{type: type, count: count} end)
    
    # Extract patterns from rule changes
    rule_patterns = extract_rule_patterns(adaptations)
    
    # Generate recommendations
    recommendations = generate_recommendations(
      adaptation, 
      common_types, 
      rule_patterns
    )
    
    # Update insights
    %{
      patterns: [
        %{name: "Adaptation Types", data: common_types},
        %{name: "Rule Patterns", data: rule_patterns}
      ],
      effective_adaptations: current_insights.effective_adaptations,
      ineffective_adaptations: current_insights.ineffective_adaptations,
      recommendations: recommendations
    }
  end
  
  defp extract_rule_patterns(adaptations) do
    # Extract patterns from rule changes
    rule_adaptations = Enum.filter(adaptations, & &1.type == :rule_change)
    
    rule_changes = Enum.flat_map(rule_adaptations, fn adaptation ->
      changes = adaptation.changes
      
      if Map.has_key?(changes, :rules) do
        Enum.flat_map(changes.rules, fn {action, rules} ->
          case action do
            :add ->
              Map.keys(rules) |> Enum.map(fn key -> {:add, key} end)
            
            :update ->
              Map.keys(rules) |> Enum.map(fn key -> {:update, key} end)
            
            :remove when is_list(rules) ->
              Enum.map(rules, fn key -> {:remove, key} end)
            
            _ ->
              []
          end
        end)
      else
        []
      end
    end)
    
    # Count frequencies
    rule_frequencies = Enum.frequencies(rule_changes)
    
    # Convert to list of patterns
    rule_frequencies
    |> Enum.sort_by(fn {_pattern, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {{action, rule}, count} -> 
      %{action: action, rule: rule, count: count}
    end)
  end
  
  defp generate_recommendations(adaptation, common_types, rule_patterns) do
    # Generate recommendations based on patterns
    
    # Recommendations based on adaptation type
    type_recommendations = case adaptation.type do
      :rule_change ->
        ["Consider evaluating the effectiveness of rule changes after implementation"]
      
      :structure_change ->
        ["Structural changes should be followed by communication to all members"]
      
      :mechanism_change ->
        ["Monitor adaptation mechanisms to ensure they're producing desired outcomes"]
      
      :role_change ->
        ["Ensure role changes are communicated to affected agents"]
    end
    
    # Recommendations based on common types
    trend_recommendations = if Enum.any?(common_types, fn %{type: type} -> type == adaptation.type end) do
      ["This type of adaptation is common in this institution. Consider a more comprehensive review."]
    else
      []
    end
    
    # Recommendations based on rule patterns
    rule_recommendations = if adaptation.type == :rule_change && !Enum.empty?(rule_patterns) do
      ["Several rules have been frequently modified. Consider a more stable rule formulation."]
    else
      []
    end
    
    # Combine recommendations
    type_recommendations ++ trend_recommendations ++ rule_recommendations
  end
end