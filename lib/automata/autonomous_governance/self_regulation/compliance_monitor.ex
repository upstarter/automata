defmodule Automata.AutonomousGovernance.SelfRegulation.ComplianceMonitor do
  @moduledoc """
  Monitors agent compliance with social norms.
  
  This module provides functionality for:
  - Recording observations of agent behavior
  - Evaluating compliance/violation of norms
  - Tracking compliance history
  - Generating compliance reports
  
  The compliance monitor serves as the "perception" system for norm-related behavior.
  """
  
  use GenServer
  require Logger
  
  alias Automata.AutonomousGovernance.SelfRegulation.NormManager
  
  @type norm_id :: binary()
  @type agent_id :: binary()
  @type observation_id :: binary()
  
  # Client API
  
  @doc """
  Starts the Compliance Monitor.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Records an observation related to norm compliance or violation.
  
  ## Parameters
  - norm_id: ID of the norm being observed
  - agent_id: ID of the agent being observed
  - type: Type of observation (:comply or :violate)
  - details: Map containing details about the observation
  
  ## Returns
  - `{:ok, observation_id}` if successful
  - `{:error, reason}` if failed
  """
  @spec record_observation(norm_id(), agent_id(), :comply | :violate, map()) :: 
    {:ok, observation_id()} | {:error, term()}
  def record_observation(norm_id, agent_id, type, details) do
    GenServer.call(__MODULE__, {:record_observation, norm_id, agent_id, type, details})
  end
  
  @doc """
  Lists all observations for a specific agent or norm.
  
  ## Parameters
  - filters: Map of filters to apply
    - agent_id: Optional agent ID to filter
    - norm_id: Optional norm ID to filter
    - type: Optional observation type to filter
  
  ## Returns
  - `{:ok, observations}` if successful
  - `{:error, reason}` if failed
  """
  @spec list_observations(map()) :: {:ok, list(map())} | {:error, term()}
  def list_observations(filters \\ %{}) do
    GenServer.call(__MODULE__, {:list_observations, filters})
  end
  
  @doc """
  Gets compliance statistics for an agent.
  
  ## Parameters
  - agent_id: ID of the agent
  - timeframe: Optional timeframe to consider
  
  ## Returns
  - `{:ok, stats}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_agent_compliance_stats(agent_id(), map()) :: {:ok, map()} | {:error, term()}
  def get_agent_compliance_stats(agent_id, timeframe \\ %{}) do
    GenServer.call(__MODULE__, {:get_agent_compliance_stats, agent_id, timeframe})
  end
  
  @doc """
  Gets compliance statistics for a norm.
  
  ## Parameters
  - norm_id: ID of the norm
  - timeframe: Optional timeframe to consider
  
  ## Returns
  - `{:ok, stats}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_norm_compliance_stats(norm_id(), map()) :: {:ok, map()} | {:error, term()}
  def get_norm_compliance_stats(norm_id, timeframe \\ %{}) do
    GenServer.call(__MODULE__, {:get_norm_compliance_stats, norm_id, timeframe})
  end
  
  @doc """
  Evaluates an action against applicable norms.
  
  ## Parameters
  - agent_id: ID of the agent performing the action
  - action: Map describing the action
  - context: Context where the action is performed
  
  ## Returns
  - `{:ok, evaluation}` if successful
  - `{:error, reason}` if failed
  """
  @spec evaluate_action(agent_id(), map(), binary()) :: {:ok, map()} | {:error, term()}
  def evaluate_action(agent_id, action, context) do
    GenServer.call(__MODULE__, {:evaluate_action, agent_id, action, context})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Compliance Monitor")
    
    # Initialize with empty state
    initial_state = %{
      observations: %{},
      agent_observations: %{},
      norm_observations: %{},
      next_id: 1
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:record_observation, norm_id, agent_id, type, details}, _from, state) do
    # Validate the norm exists
    with {:ok, _norm} <- NormManager.get_norm(norm_id) do
      # Generate observation ID
      observation_id = "observation_#{state.next_id}"
      
      # Create observation record
      timestamp = DateTime.utc_now()
      observation = %{
        id: observation_id,
        norm_id: norm_id,
        agent_id: agent_id,
        type: type,
        details: details,
        timestamp: timestamp
      }
      
      # Update state
      updated_state = %{
        state |
        observations: Map.put(state.observations, observation_id, observation),
        agent_observations: update_agent_observations(state.agent_observations, agent_id, observation_id),
        norm_observations: update_norm_observations(state.norm_observations, norm_id, observation_id),
        next_id: state.next_id + 1
      }
      
      Logger.info("Recorded #{type} observation for agent #{agent_id} on norm #{norm_id}")
      {:reply, {:ok, observation_id}, updated_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to record observation: #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:list_observations, filters}, _from, state) do
    filtered_observations = apply_observation_filters(state.observations, filters)
    {:reply, {:ok, filtered_observations}, state}
  end
  
  @impl true
  def handle_call({:get_agent_compliance_stats, agent_id, timeframe}, _from, state) do
    # Get all observations for this agent
    observation_ids = Map.get(state.agent_observations, agent_id, MapSet.new())
    observations = Enum.map(observation_ids, &Map.get(state.observations, &1)) |> Enum.reject(&is_nil/1)
    
    # Apply timeframe filter if provided
    filtered_observations = apply_timeframe_filter(observations, timeframe)
    
    # Compile statistics
    stats = compute_compliance_stats(filtered_observations)
    
    # Add agent-specific information
    agent_stats = Map.put(stats, :agent_id, agent_id)
    
    {:reply, {:ok, agent_stats}, state}
  end
  
  @impl true
  def handle_call({:get_norm_compliance_stats, norm_id, timeframe}, _from, state) do
    # Get all observations for this norm
    observation_ids = Map.get(state.norm_observations, norm_id, MapSet.new())
    observations = Enum.map(observation_ids, &Map.get(state.observations, &1)) |> Enum.reject(&is_nil/1)
    
    # Apply timeframe filter if provided
    filtered_observations = apply_timeframe_filter(observations, timeframe)
    
    # Compile statistics
    stats = compute_compliance_stats(filtered_observations)
    
    # Add norm-specific information
    case NormManager.get_norm(norm_id) do
      {:ok, norm} ->
        norm_stats = stats
        |> Map.put(:norm_id, norm_id)
        |> Map.put(:norm_name, norm.name)
        
        # Add agent-specific breakdown
        agent_breakdown = filtered_observations
        |> Enum.group_by(& &1.agent_id)
        |> Enum.map(fn {agent_id, obs} -> {agent_id, compute_compliance_stats(obs)} end)
        |> Enum.into(%{})
        
        norm_stats = Map.put(norm_stats, :agent_breakdown, agent_breakdown)
        
        {:reply, {:ok, norm_stats}, state}
      
      {:error, _reason} ->
        # Still return stats even if norm is not found
        norm_stats = Map.put(stats, :norm_id, norm_id)
        {:reply, {:ok, norm_stats}, state}
    end
  end
  
  @impl true
  def handle_call({:evaluate_action, agent_id, action, context}, _from, state) do
    # Get applicable norms for this context
    {:ok, applicable_norms} = NormManager.list_norms(context)
    
    # Evaluate action against each applicable norm
    norm_evaluations = Enum.map(applicable_norms, fn norm ->
      {norm.id, evaluate_against_norm(agent_id, action, norm)}
    end)
    |> Enum.into(%{})
    
    # Create overall evaluation
    evaluation = %{
      agent_id: agent_id,
      action: action,
      context: context,
      timestamp: DateTime.utc_now(),
      norm_evaluations: norm_evaluations,
      compliant: Enum.all?(norm_evaluations, fn {_id, eval} -> eval.compliant end),
      violations: Enum.filter(norm_evaluations, fn {_id, eval} -> !eval.compliant end)
                  |> Enum.map(fn {id, _} -> id end)
    }
    
    {:reply, {:ok, evaluation}, state}
  end
  
  # Helper functions
  
  defp update_agent_observations(agent_observations, agent_id, observation_id) do
    Map.update(agent_observations, agent_id, MapSet.new([observation_id]), fn ids ->
      MapSet.put(ids, observation_id)
    end)
  end
  
  defp update_norm_observations(norm_observations, norm_id, observation_id) do
    Map.update(norm_observations, norm_id, MapSet.new([observation_id]), fn ids ->
      MapSet.put(ids, observation_id)
    end)
  end
  
  defp apply_observation_filters(observations, filters) do
    observations
    |> Map.values()
    |> Enum.filter(fn observation ->
      Enum.all?(filters, fn {key, value} ->
        Map.get(observation, key) == value
      end)
    end)
    |> Enum.sort_by(& &1.timestamp, DateTime)
  end
  
  defp apply_timeframe_filter(observations, timeframe) do
    case timeframe do
      %{since: since} when not is_nil(since) ->
        Enum.filter(observations, fn obs -> DateTime.compare(obs.timestamp, since) in [:gt, :eq] end)
      
      %{until: until} when not is_nil(until) ->
        Enum.filter(observations, fn obs -> DateTime.compare(obs.timestamp, until) in [:lt, :eq] end)
      
      %{since: since, until: until} when not is_nil(since) and not is_nil(until) ->
        Enum.filter(observations, fn obs -> 
          DateTime.compare(obs.timestamp, since) in [:gt, :eq] and
          DateTime.compare(obs.timestamp, until) in [:lt, :eq]
        end)
      
      _ ->
        # No timeframe filter
        observations
    end
  end
  
  defp compute_compliance_stats(observations) do
    total_count = length(observations)
    
    {comply_count, violate_count} = Enum.reduce(observations, {0, 0}, fn observation, {comply, violate} ->
      case observation.type do
        :comply -> {comply + 1, violate}
        :violate -> {comply, violate + 1}
        _ -> {comply, violate}
      end
    end)
    
    # Calculate compliance rate
    compliance_rate = if total_count > 0 do
      comply_count / total_count
    else
      0.0
    end
    
    # Group observations by norm
    norm_breakdown = observations
    |> Enum.group_by(& &1.norm_id)
    |> Enum.map(fn {norm_id, obs} -> 
      norm_total = length(obs)
      norm_comply = Enum.count(obs, & &1.type == :comply)
      norm_rate = if norm_total > 0, do: norm_comply / norm_total, else: 0.0
      
      {norm_id, %{
        total: norm_total,
        comply: norm_comply,
        violate: norm_total - norm_comply,
        compliance_rate: norm_rate
      }}
    end)
    |> Enum.into(%{})
    
    # Return stats
    %{
      total_observations: total_count,
      comply_count: comply_count,
      violate_count: violate_count,
      compliance_rate: compliance_rate,
      norm_breakdown: norm_breakdown,
      timeframe: %{
        earliest: List.first(Enum.sort_by(observations, & &1.timestamp, DateTime))
                  |> case do
                      nil -> nil
                      obs -> obs.timestamp
                    end,
        latest: List.last(Enum.sort_by(observations, & &1.timestamp, DateTime))
                |> case do
                    nil -> nil
                    obs -> obs.timestamp
                  end
      }
    }
  end
  
  defp evaluate_against_norm(agent_id, action, norm) do
    # Check if action triggers norm evaluation
    if action_matches_condition?(action, norm.condition) do
      # Check for compliance or violation
      compliant = action_complies_with_norm?(action, norm)
      
      %{
        compliant: compliant,
        norm_id: norm.id,
        norm_name: norm.name,
        agent_id: agent_id,
        action: action,
        timestamp: DateTime.utc_now(),
        condition_matched: true
      }
    else
      # Action doesn't trigger this norm
      %{
        compliant: true, # Default to compliant if norm doesn't apply
        norm_id: norm.id,
        norm_name: norm.name,
        agent_id: agent_id,
        action: action,
        timestamp: DateTime.utc_now(),
        condition_matched: false
      }
    end
  end
  
  defp action_matches_condition?(action, condition) do
    # A simple pattern matching implementation
    # In a real system, this would be more sophisticated
    action_type = Map.get(action, :type)
    condition_type = Map.get(condition, :action)
    
    cond do
      is_nil(condition_type) ->
        # No action type specified in condition, so it matches any action
        true
      
      is_nil(action_type) ->
        # Action doesn't have a type, but condition requires one
        false
      
      is_binary(condition_type) && condition_type == action_type ->
        # Direct match
        true
      
      is_list(condition_type) && action_type in condition_type ->
        # Action type is in list of condition types
        true
      
      true ->
        # No match
        false
    end
  end
  
  defp action_complies_with_norm?(action, norm) do
    # Check compliance criteria
    compliance_matched = action_matches_criteria?(action, norm.compliance)
    
    # Check violation criteria
    violation_matched = action_matches_criteria?(action, norm.violation)
    
    cond do
      compliance_matched && !violation_matched ->
        # Explicitly complies
        true
      
      !compliance_matched && violation_matched ->
        # Explicitly violates
        false
      
      compliance_matched && violation_matched ->
        # Both match - ambiguous, but lean toward compliance
        Logger.warning("Ambiguous norm evaluation: action matches both compliance and violation criteria")
        true
      
      !compliance_matched && !violation_matched ->
        # Neither matches - default to compliant
        true
    end
  end
  
  defp action_matches_criteria?(action, criteria) do
    # Similar to action_matches_condition? but specific to compliance/violation criteria
    action_type = Map.get(action, :type)
    criteria_action = Map.get(criteria, :action)
    
    # Check action type match
    action_type_matches = cond do
      is_nil(criteria_action) ->
        true
      
      is_nil(action_type) ->
        false
      
      is_binary(criteria_action) && criteria_action == action_type ->
        true
      
      is_list(criteria_action) && action_type in criteria_action ->
        true
      
      criteria_action == "not_#{action_type}" ->
        false
      
      true ->
        false
    end
    
    # Check conditions match
    conditions_match = case Map.get(criteria, :conditions) do
      nil ->
        true
      
      conditions ->
        Enum.all?(conditions, fn {key, value} ->
          action_value = get_in(action, [key])
          action_value == value
        end)
    end
    
    # Both action type and conditions must match
    action_type_matches && conditions_match
  end
end