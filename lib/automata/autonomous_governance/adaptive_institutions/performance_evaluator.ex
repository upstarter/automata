defmodule Automata.AutonomousGovernance.AdaptiveInstitutions.PerformanceEvaluator do
  @moduledoc """
  Evaluates the performance of institutions based on various metrics.
  
  This module provides functionality for:
  - Defining and calculating evaluation metrics
  - Analyzing institutional performance
  - Generating insights from evaluations
  - Identifying improvement opportunities
  
  The performance evaluator supports evidence-based institutional adaptation.
  """
  
  use GenServer
  require Logger
  
  alias Automata.AutonomousGovernance.AdaptiveInstitutions.InstitutionManager
  alias Automata.AutonomousGovernance.DistributedGovernance
  alias Automata.AutonomousGovernance.SelfRegulation
  
  @type institution_id :: binary()
  @type evaluation_id :: binary()
  
  # Standard evaluation metrics
  @default_metrics [
    :governance_effectiveness,
    :compliance_rate,
    :participation_rate,
    :decision_quality,
    :adaptation_responsiveness,
    :conflict_resolution,
    :resource_efficiency
  ]
  
  # Client API
  
  @doc """
  Starts the Performance Evaluator.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Evaluates the performance of an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  - metrics: List of metrics to evaluate (defaults to standard metrics)
  
  ## Returns
  - `{:ok, evaluation}` if successful
  - `{:error, reason}` if failed
  """
  @spec evaluate_institution(institution_id(), list()) :: {:ok, map()} | {:error, term()}
  def evaluate_institution(institution_id, metrics \\ []) do
    GenServer.call(__MODULE__, {:evaluate_institution, institution_id, metrics})
  end
  
  @doc """
  Gets historical evaluation data for an institution.
  
  ## Parameters
  - institution_id: ID of the institution
  - timeframe: Optional timeframe to consider
  
  ## Returns
  - `{:ok, evaluations}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_evaluation_history(institution_id(), map()) :: 
    {:ok, list(map())} | {:error, term()}
  def get_evaluation_history(institution_id, timeframe \\ %{}) do
    GenServer.call(__MODULE__, {:get_evaluation_history, institution_id, timeframe})
  end
  
  @doc """
  Compares performance across multiple institutions.
  
  ## Parameters
  - institution_ids: List of institution IDs to compare
  - metrics: List of metrics to compare
  
  ## Returns
  - `{:ok, comparison}` if successful
  - `{:error, reason}` if failed
  """
  @spec compare_institutions(list(institution_id()), list()) :: 
    {:ok, map()} | {:error, term()}
  def compare_institutions(institution_ids, metrics \\ []) do
    GenServer.call(__MODULE__, {:compare_institutions, institution_ids, metrics})
  end
  
  @doc """
  Gets detailed insights from an evaluation.
  
  ## Parameters
  - evaluation_id: ID of the evaluation
  
  ## Returns
  - `{:ok, insights}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_evaluation_insights(evaluation_id()) :: {:ok, map()} | {:error, term()}
  def get_evaluation_insights(evaluation_id) do
    GenServer.call(__MODULE__, {:get_evaluation_insights, evaluation_id})
  end
  
  @doc """
  Gets available evaluation metrics.
  
  ## Returns
  - `{:ok, metrics}` with available metrics and descriptions
  """
  @spec get_available_metrics() :: {:ok, map()}
  def get_available_metrics do
    GenServer.call(__MODULE__, :get_available_metrics)
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Performance Evaluator")
    
    # Initialize evaluations storage
    initial_state = %{
      evaluations: %{},
      institution_evaluations: %{},
      metrics: initialize_metrics(),
      next_evaluation_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:evaluate_institution, institution_id, metrics}, _from, state) do
    with {:ok, institution} <- InstitutionManager.get_institution(institution_id) do
      # Determine which metrics to evaluate
      metrics_to_evaluate = if Enum.empty?(metrics) do
        @default_metrics
      else
        metrics
      end
      
      # Perform evaluation for each metric
      evaluation_results = Enum.reduce(metrics_to_evaluate, %{}, fn metric, acc ->
        case evaluate_metric(metric, institution) do
          {:ok, score} -> Map.put(acc, metric, score)
          {:error, _reason} -> acc
        end
      end)
      
      # Generate insights from evaluation
      insights = generate_insights(institution, evaluation_results)
      
      # Generate evaluation ID
      evaluation_id = "evaluation_#{state.next_evaluation_id}"
      
      # Create evaluation record
      timestamp = DateTime.utc_now()
      evaluation = %{
        id: evaluation_id,
        institution_id: institution_id,
        timestamp: timestamp,
        metrics: metrics_to_evaluate,
        scores: evaluation_results,
        insights: insights,
        overall_score: calculate_overall_score(evaluation_results)
      }
      
      # Update state
      updated_state = %{
        state |
        evaluations: Map.put(state.evaluations, evaluation_id, evaluation),
        institution_evaluations: update_institution_evaluations(
          state.institution_evaluations, 
          institution_id, 
          evaluation_id
        ),
        next_evaluation_id: state.next_evaluation_id + 1
      }
      
      Logger.info("Evaluated institution #{institution_id} with overall score #{evaluation.overall_score}")
      {:reply, {:ok, evaluation}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to evaluate institution: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_evaluation_history, institution_id, timeframe}, _from, state) do
    with {:ok, _institution} <- InstitutionManager.get_institution(institution_id) do
      # Get all evaluations for this institution
      evaluation_ids = Map.get(state.institution_evaluations, institution_id, [])
      evaluations = Enum.map(evaluation_ids, &Map.get(state.evaluations, &1))
                   |> Enum.reject(&is_nil/1)
      
      # Apply timeframe filter if provided
      filtered_evaluations = apply_timeframe_filter(evaluations, timeframe)
      
      # Sort by timestamp (descending)
      sorted_evaluations = Enum.sort_by(filtered_evaluations, & &1.timestamp, {:desc, DateTime})
      
      {:reply, {:ok, sorted_evaluations}, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:compare_institutions, institution_ids, metrics}, _from, state) do
    # Validate institutions
    valid_institutions = Enum.filter(institution_ids, fn id ->
      case InstitutionManager.get_institution(id) do
        {:ok, _} -> true
        {:error, _} -> false
      end
    end)
    
    if Enum.empty?(valid_institutions) do
      {:reply, {:error, :no_valid_institutions}, state}
    else
      # Determine which metrics to compare
      metrics_to_compare = if Enum.empty?(metrics) do
        @default_metrics
      else
        metrics
      end
      
      # Get latest evaluation for each institution
      comparison_data = Enum.map(valid_institutions, fn institution_id ->
        # Get the latest evaluation
        evaluation_ids = Map.get(state.institution_evaluations, institution_id, [])
        evaluations = Enum.map(evaluation_ids, &Map.get(state.evaluations, &1))
                     |> Enum.reject(&is_nil/1)
                     |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
        
        latest_evaluation = List.first(evaluations)
        
        if latest_evaluation do
          # Extract relevant metrics
          metric_scores = Map.take(latest_evaluation.scores, metrics_to_compare)
          
          # Get institution name
          {:ok, institution} = InstitutionManager.get_institution(institution_id)
          
          %{
            institution_id: institution_id,
            institution_name: institution.name,
            evaluation_id: latest_evaluation.id,
            timestamp: latest_evaluation.timestamp,
            scores: metric_scores,
            overall_score: latest_evaluation.overall_score
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      
      # Calculate comparative metrics
      comparison = %{
        institutions: comparison_data,
        metrics: metrics_to_compare,
        timestamp: DateTime.utc_now(),
        rankings: calculate_rankings(comparison_data),
        average_scores: calculate_average_scores(comparison_data, metrics_to_compare)
      }
      
      {:reply, {:ok, comparison}, state}
    end
  end
  
  @impl true
  def handle_call({:get_evaluation_insights, evaluation_id}, _from, state) do
    case Map.fetch(state.evaluations, evaluation_id) do
      {:ok, evaluation} ->
        # Return existing insights and generate any additional insights
        {:reply, {:ok, evaluation.insights}, state}
      
      :error ->
        {:reply, {:error, :evaluation_not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:get_available_metrics, _from, state) do
    {:reply, {:ok, state.metrics}, state}
  end
  
  # Helper functions
  
  defp initialize_metrics do
    %{
      governance_effectiveness: %{
        description: "Measures how effectively the institution's governance structures operate",
        components: [:decision_speed, :decision_quality, :implementation_rate]
      },
      compliance_rate: %{
        description: "Rate at which agents comply with institutional rules",
        components: [:norm_compliance, :rule_violations, :sanction_effectiveness]
      },
      participation_rate: %{
        description: "Level of agent participation in institutional processes",
        components: [:voting_rate, :proposal_activity, :discussion_engagement]
      },
      decision_quality: %{
        description: "Quality of decisions made by the institution",
        components: [:outcome_effectiveness, :stakeholder_satisfaction, :decision_stability]
      },
      adaptation_responsiveness: %{
        description: "How well the institution adapts to changing conditions",
        components: [:adaptation_speed, :change_implementation, :learning_integration]
      },
      conflict_resolution: %{
        description: "Effectiveness of conflict resolution mechanisms",
        components: [:dispute_resolution_time, :resolution_acceptance, :repeated_conflicts]
      },
      resource_efficiency: %{
        description: "Efficiency of resource allocation and utilization",
        components: [:resource_utilization, :allocation_fairness, :overhead_costs]
      }
    }
  end
  
  defp evaluate_metric(metric, institution) do
    case metric do
      :governance_effectiveness ->
        evaluate_governance_effectiveness(institution)
      
      :compliance_rate ->
        evaluate_compliance_rate(institution)
      
      :participation_rate ->
        evaluate_participation_rate(institution)
      
      :decision_quality ->
        evaluate_decision_quality(institution)
      
      :adaptation_responsiveness ->
        evaluate_adaptation_responsiveness(institution)
      
      :conflict_resolution ->
        evaluate_conflict_resolution(institution)
      
      :resource_efficiency ->
        evaluate_resource_efficiency(institution)
      
      _ ->
        {:error, :unknown_metric}
    end
  end
  
  defp evaluate_governance_effectiveness(institution) do
    # In a real implementation, this would collect data from the governance zone
    # and analyze decision processes, implementation rates, etc.
    if institution.governance_zone do
      # Get governance metrics from the zone
      {:ok, metrics} = DistributedGovernance.get_zone_metrics(institution.governance_zone)
      
      # Calculate score based on decision stats and consensus metrics
      decision_score = calculate_decision_score(metrics.decision_stats)
      consensus_score = calculate_consensus_score(metrics.consensus_metrics)
      
      # Combine scores
      score = (decision_score + consensus_score) / 2
      {:ok, score}
    else
      # No governance zone, use default value
      {:ok, 0.5}
    end
  end
  
  defp evaluate_compliance_rate(institution) do
    # This would analyze norm compliance data
    if institution.governance_zone do
      # Get norm compliance data
      {:ok, norms} = SelfRegulation.list_norms("zone:#{institution.governance_zone}")
      
      if Enum.empty?(norms) do
        {:ok, 0.5}
      else
        # Calculate average compliance rate across norms
        total_compliance = Enum.reduce(norms, 0, fn norm, acc ->
          {:ok, stats} = SelfRegulation.ComplianceMonitor.get_norm_compliance_stats(norm.id)
          acc + stats.compliance_rate
        end)
        
        score = total_compliance / length(norms)
        {:ok, score}
      end
    else
      # No governance zone, use default value
      {:ok, 0.5}
    end
  end
  
  defp evaluate_participation_rate(institution) do
    # This would analyze participation in governance processes
    if institution.governance_zone do
      # Get zone metrics
      {:ok, metrics} = DistributedGovernance.get_zone_metrics(institution.governance_zone)
      
      # Participation rate from metrics
      {:ok, metrics.participation_rate}
    else
      # No governance zone, use default value
      {:ok, 0.5}
    end
  end
  
  defp evaluate_decision_quality(institution) do
    # This would analyze decision outcomes and implementation success
    if institution.governance_zone do
      # Get decisions from the zone
      {:ok, decisions} = DistributedGovernance.list_decisions(institution.governance_zone)
      
      if Enum.empty?(decisions) do
        {:ok, 0.5}
      else
        # Calculate decision quality metrics
        # In a real implementation, this would track decision outcomes over time
        approved_decisions = Enum.filter(decisions, & &1.status == :approved)
        consensus_factor = length(approved_decisions) / max(1, length(decisions))
        
        # Placeholder for outcome tracking
        outcome_quality = 0.7
        
        score = (consensus_factor + outcome_quality) / 2
        {:ok, score}
      end
    else
      # No governance zone, use default value
      {:ok, 0.5}
    end
  end
  
  defp evaluate_adaptation_responsiveness(institution) do
    # This would analyze how quickly and effectively the institution adapts
    # Get adaptation history
    {:ok, adaptations} = AdaptiveInstitutions.AdaptationEngine.get_adaptation_history(institution.id)
    
    if Enum.empty?(adaptations) do
      # No adaptations yet
      {:ok, 0.5}
    else
      # Calculate adaptation metrics
      recent_adaptations = Enum.filter(adaptations, fn adaptation ->
        age_days = DateTime.diff(DateTime.utc_now(), adaptation.proposed_at, :second) / 86400
        age_days <= 90 # Consider adaptations in last 90 days
      end)
      
      if Enum.empty?(recent_adaptations) do
        {:ok, 0.5}
      else
        # Calculate implementation rate and speed
        implemented = Enum.filter(recent_adaptations, & &1.status == :implemented)
        implementation_rate = length(implemented) / length(recent_adaptations)
        
        # Calculate average implementation time for implemented adaptations
        total_time = Enum.reduce(implemented, 0, fn adaptation, acc ->
          if adaptation.implemented_at do
            acc + DateTime.diff(adaptation.implemented_at, adaptation.proposed_at, :second)
          else
            acc
          end
        end)
        
        avg_time = if length(implemented) > 0 do
          total_time / length(implemented) / 86400 # Average days to implement
        else
          30 # Default 30 days
        end
        
        # Calculate responsiveness score
        time_factor = max(0, min(1, 1 - (avg_time / 30))) # Higher score for faster implementation
        score = (implementation_rate + time_factor) / 2
        
        {:ok, score}
      end
    end
  end
  
  defp evaluate_conflict_resolution(institution) do
    # This would analyze conflict resolution data
    # In a real implementation, this would track disputes and resolutions
    # For now, use a placeholder value
    {:ok, 0.6}
  end
  
  defp evaluate_resource_efficiency(institution) do
    # This would analyze resource allocation and utilization
    # In a real implementation, this would track resource usage
    # For now, use a placeholder value
    {:ok, 0.7}
  end
  
  defp calculate_overall_score(metric_scores) do
    # Average all metric scores
    if map_size(metric_scores) > 0 do
      total = Enum.reduce(metric_scores, 0, fn {_metric, score}, acc -> acc + score end)
      total / map_size(metric_scores)
    else
      0.0
    end
  end
  
  defp update_institution_evaluations(institution_evaluations, institution_id, evaluation_id) do
    Map.update(institution_evaluations, institution_id, [evaluation_id], fn ids ->
      [evaluation_id | ids]
    end)
  end
  
  defp apply_timeframe_filter(evaluations, timeframe) do
    case timeframe do
      %{since: since} when not is_nil(since) ->
        Enum.filter(evaluations, fn eval -> DateTime.compare(eval.timestamp, since) in [:gt, :eq] end)
      
      %{until: until} when not is_nil(until) ->
        Enum.filter(evaluations, fn eval -> DateTime.compare(eval.timestamp, until) in [:lt, :eq] end)
      
      %{since: since, until: until} when not is_nil(since) and not is_nil(until) ->
        Enum.filter(evaluations, fn eval -> 
          DateTime.compare(eval.timestamp, since) in [:gt, :eq] and
          DateTime.compare(eval.timestamp, until) in [:lt, :eq]
        end)
      
      _ ->
        # No timeframe filter
        evaluations
    end
  end
  
  defp generate_insights(institution, evaluation_results) do
    # Generate insights based on evaluation results
    # In a real implementation, this would be more sophisticated
    
    # Identify strengths and weaknesses
    {strengths, weaknesses} = Enum.split_with(evaluation_results, fn {_metric, score} -> score >= 0.7 end)
    
    # Generate improvement suggestions
    suggestions = Enum.map(weaknesses, fn {metric, score} ->
      suggestion = case metric do
        :governance_effectiveness when score < 0.5 ->
          "Consider streamlining decision processes to improve governance effectiveness"
        
        :compliance_rate when score < 0.5 ->
          "Improve norm communication and potentially revise sanctions to increase compliance"
        
        :participation_rate when score < 0.5 ->
          "Implement incentives for participation in governance processes"
        
        :decision_quality when score < 0.6 ->
          "Enhance information sharing and deliberation processes to improve decision quality"
        
        :adaptation_responsiveness when score < 0.6 ->
          "Streamline adaptation mechanisms to respond more quickly to changing conditions"
        
        :conflict_resolution when score < 0.6 ->
          "Strengthen conflict resolution mechanisms and ensure neutrality"
        
        :resource_efficiency when score < 0.6 ->
          "Review resource allocation mechanisms to improve efficiency"
        
        _ ->
          "Consider improvements in #{metric} area"
      end
      
      %{
        metric: metric,
        score: score,
        suggestion: suggestion
      }
    end)
    
    # Identify trends if previous evaluations exist
    trends = %{} # Would compare with previous evaluations
    
    %{
      strengths: Enum.map(strengths, fn {metric, score} -> %{metric: metric, score: score} end),
      weaknesses: Enum.map(weaknesses, fn {metric, score} -> %{metric: metric, score: score} end),
      improvement_suggestions: suggestions,
      trends: trends
    }
  end
  
  defp calculate_decision_score(decision_stats) do
    # Calculate a score based on decision statistics
    # Higher scores for more decisions, faster decisions, and higher approval rates
    
    # Decision volume factor (more decisions is better, up to a point)
    volume_factor = min(1.0, decision_stats.total / 20)
    
    # Decision time factor (faster is better)
    time_factor = if decision_stats.avg_decision_time > 0 do
      # Convert to days and score (lower is better)
      days = decision_stats.avg_decision_time / 86400
      max(0.0, min(1.0, 1.0 - (days / 7))) # 7 days or less gets full score
    else
      0.5 # Default if no data
    end
    
    # Approval rate factor
    approved = Map.get(decision_stats.by_status, :approved, 0)
    total_decided = approved + Map.get(decision_stats.by_status, :rejected, 0)
    
    approval_factor = if total_decided > 0 do
      approved / total_decided
    else
      0.5 # Default if no decided proposals
    end
    
    # Calculate overall score
    (volume_factor + time_factor + approval_factor) / 3
  end
  
  defp calculate_consensus_score(consensus_metrics) do
    # Calculate a score based on consensus metrics
    # Higher scores for better consensus, lower polarization
    
    # Higher consensus score is better
    consensus_factor = min(1.0, consensus_metrics.avg_consensus_score)
    
    # Lower contested percentage is better
    contested_factor = 1.0 - min(1.0, consensus_metrics.contested_percentage * 2)
    
    # Higher unanimous percentage is better
    unanimous_factor = min(1.0, consensus_metrics.unanimous_percentage * 2)
    
    # Calculate overall score
    (consensus_factor + contested_factor + unanimous_factor) / 3
  end
  
  defp calculate_rankings(comparison_data) do
    # Calculate rankings for each metric
    metrics = comparison_data
    |> Enum.flat_map(fn data -> Map.keys(data.scores) end)
    |> MapSet.new()
    |> MapSet.to_list()
    
    # For each metric, rank institutions
    Enum.map(metrics, fn metric ->
      # Filter institutions that have this metric
      institutions_with_metric = Enum.filter(comparison_data, fn data ->
        Map.has_key?(data.scores, metric)
      end)
      
      # Sort by score (descending)
      sorted = Enum.sort_by(institutions_with_metric, fn data ->
        Map.get(data.scores, metric, 0)
      end, :desc)
      
      # Create ranking
      {metric, Enum.map(sorted, fn data ->
        %{
          institution_id: data.institution_id,
          institution_name: data.institution_name,
          score: Map.get(data.scores, metric, 0)
        }
      end)}
    end)
    |> Enum.into(%{})
  end
  
  defp calculate_average_scores(comparison_data, metrics) do
    # Calculate average score for each metric across all institutions
    Enum.reduce(metrics, %{}, fn metric, acc ->
      # Get scores for this metric
      scores = Enum.map(comparison_data, fn data ->
        Map.get(data.scores, metric)
      end)
      |> Enum.reject(&is_nil/1)
      
      # Calculate average
      avg = if Enum.empty?(scores) do
        0.0
      else
        Enum.sum(scores) / length(scores)
      end
      
      Map.put(acc, metric, avg)
    end)
  end
end