defmodule Automata.AutonomousGovernance.AdaptiveInstitutions do
  @moduledoc """
  Adaptive Institutions for multi-agent systems.
  
  This module provides functionality for:
  - Creating and evolving institutional arrangements
  - Evaluating institution performance
  - Adapting rules and structures based on outcomes
  - Supporting institutional learning
  
  Adaptive Institutions represent evolving rule sets that govern agent interactions
  and adapt over time based on experience and outcomes.
  """
  
  use GenServer
  require Logger
  
  alias Automata.AutonomousGovernance.AdaptiveInstitutions.InstitutionManager
  alias Automata.AutonomousGovernance.AdaptiveInstitutions.PerformanceEvaluator
  alias Automata.AutonomousGovernance.AdaptiveInstitutions.AdaptationEngine
  alias Automata.AutonomousGovernance.DistributedGovernance
  alias Automata.AutonomousGovernance.SelfRegulation
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @type institution_id :: binary()
  @type agent_id :: binary()
  @type adaptation_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Adaptive Institutions system.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Defines an institution with specified rules and adaptation mechanisms.
  
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
  - `{:ok, registration_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec join_institution(institution_id(), agent_id(), map()) :: 
    {:ok, binary()} | {:error, term()}
  def join_institution(institution_id, agent_id, parameters \\ %{}) do
    GenServer.call(__MODULE__, {:join_institution, institution_id, agent_id, parameters})
  end
  
  @doc """
  Evaluates the performance of an institution based on various metrics.
  
  ## Parameters
  - institution_id: ID of the institution
  - metrics: List of metrics to evaluate
  
  ## Returns
  - `{:ok, evaluation}` if successful
  - `{:error, reason}` if failed
  """
  @spec evaluate_institution(institution_id(), list()) :: {:ok, map()} | {:error, term()}
  def evaluate_institution(institution_id, metrics \\ []) do
    GenServer.call(__MODULE__, {:evaluate_institution, institution_id, metrics})
  end
  
  @doc """
  Proposes an adaptation to an institution's rules or structure.
  
  ## Parameters
  - institution_id: ID of the institution
  - agent_id: ID of the agent proposing the adaptation
  - adaptation: Map describing the proposed adaptation
  
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
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Adaptive Institutions system")
    
    # Register with knowledge system
    KnowledgeSystem.register_knowledge_domain("institutions", %{
      description: "Institutional arrangements and adaptations in multi-agent systems",
      schema: %{
        institution: [:id, :name, :description, :purpose, :rule_system, :adaptation_mechanisms, 
                     :governance_zone, :created_at, :version],
        agent_membership: [:id, :institution_id, :agent_id, :roles, :joined_at, :status],
        adaptation: [:id, :institution_id, :proposer_id, :type, :description, :changes, 
                    :justification, :status, :proposed_at, :implemented_at],
        evaluation: [:id, :institution_id, :timestamp, :metrics, :scores, :insights]
      }
    })
    
    # Schedule periodic institution evaluation
    schedule_institution_evaluation()
    
    {:ok, %{initialized: true}}
  end
  
  @impl true
  def handle_call({:define_institution, name, config}, _from, state) do
    case InstitutionManager.define_institution(name, config) do
      {:ok, institution_id} = result ->
        # Add institution to knowledge system
        KnowledgeSystem.add_knowledge_item("institutions", "institution", %{
          id: institution_id,
          name: name,
          description: config[:description],
          purpose: config[:purpose],
          rule_system: config[:rule_system],
          adaptation_mechanisms: config[:adaptation_mechanisms],
          governance_zone: config[:governance_zone],
          created_at: DateTime.utc_now(),
          version: 1
        })
        
        # If a governance zone is specified, link the institution to it
        if config[:governance_zone] do
          # In a real implementation, this would establish a formal link
          # between the institution and the governance zone
          :ok
        end
        
        Logger.info("Created institution: #{name} (#{institution_id})")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:join_institution, institution_id, agent_id, parameters}, _from, state) do
    case InstitutionManager.join_institution(institution_id, agent_id, parameters) do
      {:ok, membership_id} = result ->
        # Add membership to knowledge system
        KnowledgeSystem.add_knowledge_item("institutions", "agent_membership", %{
          id: membership_id,
          institution_id: institution_id,
          agent_id: agent_id,
          roles: parameters[:roles] || %{},
          joined_at: DateTime.utc_now(),
          status: :active
        })
        
        # If institution has a governance zone, also register agent there
        {:ok, institution} = InstitutionManager.get_institution(institution_id)
        if institution.governance_zone do
          DistributedGovernance.register_in_zone(
            institution.governance_zone, 
            agent_id, 
            parameters[:roles] || %{}
          )
        end
        
        Logger.info("Agent #{agent_id} joined institution #{institution_id}")
        {:reply, result, state}
      
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:evaluate_institution, institution_id, metrics}, _from, state) do
    with {:ok, institution} <- InstitutionManager.get_institution(institution_id) do
      # Perform the evaluation
      case PerformanceEvaluator.evaluate_institution(institution_id, metrics) do
        {:ok, evaluation} = result ->
          # Add evaluation to knowledge system
          KnowledgeSystem.add_knowledge_item("institutions", "evaluation", %{
            id: evaluation.id,
            institution_id: institution_id,
            timestamp: evaluation.timestamp,
            metrics: evaluation.metrics,
            scores: evaluation.scores,
            insights: evaluation.insights
          })
          
          # Check if adaptation is needed based on evaluation
          check_adaptation_triggers(institution, evaluation)
          
          Logger.info("Evaluated institution #{institution_id}")
          {:reply, result, state}
        
        {:error, _reason} = error ->
          {:reply, error, state}
      end
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:propose_adaptation, institution_id, agent_id, adaptation}, _from, state) do
    with {:ok, institution} <- InstitutionManager.get_institution(institution_id),
         :ok <- validate_adaptation_proposal(adaptation) do
      
      # Submit the adaptation proposal
      case AdaptationEngine.propose_adaptation(institution_id, agent_id, adaptation) do
        {:ok, adaptation_id} = result ->
          # Add adaptation to knowledge system
          KnowledgeSystem.add_knowledge_item("institutions", "adaptation", %{
            id: adaptation_id,
            institution_id: institution_id,
            proposer_id: agent_id,
            type: adaptation.type,
            description: adaptation.description,
            changes: adaptation.changes,
            justification: adaptation.justification,
            status: :proposed,
            proposed_at: DateTime.utc_now(),
            implemented_at: nil
          })
          
          # If institution has a governance zone, create a decision proposal
          if institution.governance_zone do
            DistributedGovernance.propose_decision(
              institution.governance_zone,
              agent_id,
              %{
                type: :institution_adaptation,
                description: "Adaptation proposal for institution #{institution.name}",
                details: %{
                  institution_id: institution_id,
                  adaptation_id: adaptation_id,
                  adaptation_type: adaptation.type,
                  changes: adaptation.changes
                },
                justification: adaptation.justification
              }
            )
          end
          
          Logger.info("Agent #{agent_id} proposed adaptation for institution #{institution_id}")
          {:reply, result, state}
        
        {:error, _reason} = error ->
          {:reply, error, state}
      end
    else
      {:error, reason} = error ->
        Logger.error("Failed to propose adaptation: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_institution, institution_id}, _from, state) do
    {:reply, InstitutionManager.get_institution(institution_id), state}
  end
  
  @impl true
  def handle_call({:list_institutions, filters}, _from, state) do
    {:reply, InstitutionManager.list_institutions(filters), state}
  end
  
  @impl true
  def handle_call({:get_adaptation_history, institution_id}, _from, state) do
    {:reply, AdaptationEngine.get_adaptation_history(institution_id), state}
  end
  
  @impl true
  def handle_call({:get_learning_insights, institution_id}, _from, state) do
    {:reply, AdaptationEngine.get_learning_insights(institution_id), state}
  end
  
  @impl true
  def handle_info(:evaluate_institutions, state) do
    # Periodically evaluate all active institutions
    {:ok, institutions} = InstitutionManager.list_institutions(%{status: :active})
    
    Enum.each(institutions, fn institution ->
      # Evaluate each institution
      evaluate_institution(institution.id)
    end)
    
    # Schedule next evaluation
    schedule_institution_evaluation()
    
    {:noreply, state}
  end
  
  # Helper functions
  
  defp validate_adaptation_proposal(adaptation) do
    # Validate required fields
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
  
  defp check_adaptation_triggers(institution, evaluation) do
    # Check if any metrics trigger automatic adaptation
    if institution.adaptation_mechanisms[:auto_adapt] do
      triggers = institution.adaptation_mechanisms[:triggers] || []
      
      # Check each trigger against evaluation metrics
      Enum.each(triggers, fn trigger ->
        metric = trigger.metric
        threshold = trigger.threshold
        adaptation_type = trigger.adaptation_type
        
        if Map.has_key?(evaluation.scores, metric) do
          score = evaluation.scores[metric]
          
          cond do
            trigger.condition == :below && score < threshold ->
              # Trigger adaptation
              auto_adapt(institution.id, metric, score, adaptation_type, trigger.adaptation_template)
            
            trigger.condition == :above && score > threshold ->
              # Trigger adaptation
              auto_adapt(institution.id, metric, score, adaptation_type, trigger.adaptation_template)
            
            true ->
              # No adaptation needed
              :ok
          end
        end
      end)
    end
  end
  
  defp auto_adapt(institution_id, metric, score, adaptation_type, template) do
    # Generate an adaptation based on the template
    adaptation = %{
      type: adaptation_type,
      description: "Auto-generated adaptation based on #{metric} score of #{score}",
      changes: template.changes,
      justification: %{
        metric: metric,
        score: score,
        threshold: template.threshold,
        auto_generated: true
      }
    }
    
    # System-initiated adaptation
    AdaptationEngine.implement_adaptation(institution_id, "system", adaptation)
  end
  
  defp schedule_institution_evaluation do
    # Evaluate institutions daily
    Process.send_after(self(), :evaluate_institutions, 24 * 60 * 60 * 1000)
  end
end