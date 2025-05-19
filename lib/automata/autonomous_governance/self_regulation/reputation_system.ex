defmodule Automata.AutonomousGovernance.SelfRegulation.ReputationSystem do
  @moduledoc """
  System for tracking agent reputation within the self-regulation system.
  
  This module provides functionality for:
  - Maintaining reputation scores for agents across different contexts
  - Updating reputation based on norm compliance and violations
  - Calculating reputation decay over time
  - Providing reputation information for decision-making
  
  Reputation serves as a social mechanism for encouraging good behavior.
  """
  
  use GenServer
  require Logger
  
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @type agent_id :: binary()
  @type context :: binary()
  @type update_type :: :positive | :negative
  
  # Default reputation settings
  @default_settings %{
    initial_score: 0.5,
    min_score: 0.0,
    max_score: 1.0,
    decay_rate: 0.01, # Amount of decay per day
    decay_interval: 24 * 60 * 60, # 24 hours in seconds
    positive_impact: 0.05,
    negative_impact: 0.1,
    history_limit: 100
  }
  
  # Client API
  
  @doc """
  Starts the Reputation System.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Gets the current reputation score for an agent.
  
  ## Parameters
  - agent_id: ID of the agent
  - context: Context for the reputation (defaults to "global")
  
  ## Returns
  - `{:ok, score}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_reputation(agent_id(), context()) :: {:ok, float()} | {:error, term()}
  def get_reputation(agent_id, context \\ "global") do
    GenServer.call(__MODULE__, {:get_reputation, agent_id, context})
  end
  
  @doc """
  Updates an agent's reputation based on an observation.
  
  ## Parameters
  - agent_id: ID of the agent
  - context: Context for the reputation
  - update_type: Type of update (:positive or :negative)
  - details: Map containing details about the update
  
  ## Returns
  - `{:ok, new_score}` if successful
  - `{:error, reason}` if failed
  """
  @spec update_reputation(agent_id(), context(), update_type(), map()) :: 
    {:ok, float()} | {:error, term()}
  def update_reputation(agent_id, context, update_type, details \\ %{}) do
    GenServer.call(__MODULE__, {:update_reputation, agent_id, context, update_type, details})
  end
  
  @doc """
  Gets reputation history for an agent.
  
  ## Parameters
  - agent_id: ID of the agent
  - context: Context for the reputation
  - limit: Maximum number of history entries to return
  
  ## Returns
  - `{:ok, history}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_reputation_history(agent_id(), context(), integer()) :: 
    {:ok, list(map())} | {:error, term()}
  def get_reputation_history(agent_id, context \\ "global", limit \\ 10) do
    GenServer.call(__MODULE__, {:get_reputation_history, agent_id, context, limit})
  end
  
  @doc """
  Sets the reputation settings.
  
  ## Parameters
  - settings: Map of settings to update
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec set_settings(map()) :: :ok | {:error, term()}
  def set_settings(settings) do
    GenServer.call(__MODULE__, {:set_settings, settings})
  end
  
  @doc """
  Gets the current reputation settings.
  
  ## Returns
  - `{:ok, settings}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_settings() :: {:ok, map()} | {:error, term()}
  def get_settings do
    GenServer.call(__MODULE__, :get_settings)
  end
  
  @doc """
  Sets context-specific reputation settings.
  
  ## Parameters
  - context: Context for the settings
  - settings: Map of settings to update
  
  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if failed
  """
  @spec set_context_settings(context(), map()) :: :ok | {:error, term()}
  def set_context_settings(context, settings) do
    GenServer.call(__MODULE__, {:set_context_settings, context, settings})
  end
  
  @doc """
  Gets reputation scores for multiple agents.
  
  ## Parameters
  - agent_ids: List of agent IDs
  - context: Context for the reputation
  
  ## Returns
  - `{:ok, scores}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_multiple_reputations(list(agent_id()), context()) :: 
    {:ok, map()} | {:error, term()}
  def get_multiple_reputations(agent_ids, context \\ "global") do
    GenServer.call(__MODULE__, {:get_multiple_reputations, agent_ids, context})
  end
  
  @doc """
  Gets all agents ranked by reputation score.
  
  ## Parameters
  - context: Context for the reputation
  - min_score: Minimum score to include
  
  ## Returns
  - `{:ok, rankings}` if successful
  - `{:error, reason}` if failed
  """
  @spec get_reputation_rankings(context(), float()) :: {:ok, list(map())} | {:error, term()}
  def get_reputation_rankings(context \\ "global", min_score \\ 0.0) do
    GenServer.call(__MODULE__, {:get_reputation_rankings, context, min_score})
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    Logger.info("Starting Reputation System")
    
    # Schedule periodic reputation decay
    schedule_reputation_decay()
    
    # Initialize with default settings
    initial_state = %{
      reputations: %{},
      history: %{},
      settings: @default_settings,
      context_settings: %{}
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:get_reputation, agent_id, context}, _from, state) do
    score = get_agent_reputation(state, agent_id, context)
    {:reply, {:ok, score}, state}
  end
  
  @impl true
  def handle_call({:update_reputation, agent_id, context, update_type, details}, _from, state) do
    # Get current reputation
    current_score = get_agent_reputation(state, agent_id, context)
    
    # Get settings for this context
    settings = get_context_settings(state, context)
    
    # Calculate change amount
    change_amount = calculate_reputation_change(update_type, details, settings)
    
    # Apply the change
    new_score = apply_reputation_change(current_score, change_amount, settings)
    
    # Create history entry
    timestamp = DateTime.utc_now()
    history_entry = %{
      agent_id: agent_id,
      context: context,
      previous_score: current_score,
      new_score: new_score,
      change: change_amount,
      update_type: update_type,
      details: details,
      timestamp: timestamp
    }
    
    # Update knowledge system with reputation change
    KnowledgeSystem.add_knowledge_item("norms", "reputation_update", %{
      agent_id: agent_id,
      context: context,
      previous_score: current_score,
      new_score: new_score,
      change: change_amount,
      update_type: update_type,
      details: Map.drop(details, [:weight]), # Drop the weight to avoid duplicates
      timestamp: timestamp
    })
    
    # Update state
    updated_state = update_reputation_state(state, agent_id, context, new_score, history_entry)
    
    Logger.info("Updated reputation for agent #{agent_id} in context '#{context}': #{current_score} -> #{new_score}")
    {:reply, {:ok, new_score}, updated_state}
  end
  
  @impl true
  def handle_call({:get_reputation_history, agent_id, context, limit}, _from, state) do
    # Get history for agent in context
    history_key = "#{agent_id}:#{context}"
    history = Map.get(state.history, history_key, [])
    
    # Return the most recent entries up to the limit
    limited_history = Enum.take(history, limit)
    
    {:reply, {:ok, limited_history}, state}
  end
  
  @impl true
  def handle_call({:set_settings, settings}, _from, state) do
    # Update global settings
    updated_settings = Map.merge(state.settings, settings)
    updated_state = %{state | settings: updated_settings}
    
    Logger.info("Updated reputation system settings")
    {:reply, :ok, updated_state}
  end
  
  @impl true
  def handle_call(:get_settings, _from, state) do
    {:reply, {:ok, state.settings}, state}
  end
  
  @impl true
  def handle_call({:set_context_settings, context, settings}, _from, state) do
    # Get current context settings or use default
    current_context_settings = Map.get(state.context_settings, context, %{})
    
    # Merge new settings
    updated_context_settings = Map.merge(current_context_settings, settings)
    
    # Update state
    updated_state = %{
      state |
      context_settings: Map.put(state.context_settings, context, updated_context_settings)
    }
    
    Logger.info("Updated reputation settings for context '#{context}'")
    {:reply, :ok, updated_state}
  end
  
  @impl true
  def handle_call({:get_multiple_reputations, agent_ids, context}, _from, state) do
    # Get reputation for each agent
    scores = Enum.reduce(agent_ids, %{}, fn agent_id, acc ->
      score = get_agent_reputation(state, agent_id, context)
      Map.put(acc, agent_id, score)
    end)
    
    {:reply, {:ok, scores}, state}
  end
  
  @impl true
  def handle_call({:get_reputation_rankings, context, min_score}, _from, state) do
    # Extract all agents in this context
    agent_scores = Enum.reduce(state.reputations, [], fn {key, score}, acc ->
      case String.split(key, ":", parts: 2) do
        [agent_id, ^context] ->
          if score >= min_score do
            [{agent_id, score} | acc]
          else
            acc
          end
        
        _ ->
          acc
      end
    end)
    
    # Sort by score (descending)
    sorted_rankings = Enum.sort_by(agent_scores, fn {_agent_id, score} -> score end, :desc)
    
    # Format the result
    formatted_rankings = Enum.map(sorted_rankings, fn {agent_id, score} ->
      %{agent_id: agent_id, score: score}
    end)
    
    {:reply, {:ok, formatted_rankings}, state}
  end
  
  @impl true
  def handle_info(:apply_reputation_decay, state) do
    # Get current time
    now = DateTime.utc_now()
    
    # Apply decay to all reputation scores
    updated_reputations = Enum.reduce(state.reputations, state.reputations, fn {key, score}, acc ->
      case String.split(key, ":", parts: 2) do
        [agent_id, context] ->
          # Get settings for this context
          settings = get_context_settings(state, context)
          
          # Calculate decayed score
          decayed_score = apply_decay(score, settings)
          
          # Only update if there's a significant change
          if abs(decayed_score - score) > 0.001 do
            # Create history entry for decay
            history_entry = %{
              agent_id: agent_id,
              context: context,
              previous_score: score,
              new_score: decayed_score,
              change: decayed_score - score,
              update_type: :decay,
              details: %{},
              timestamp: now
            }
            
            # Update history
            history_key = "#{agent_id}:#{context}"
            updated_history = [history_entry | Map.get(state.history, history_key, [])]
                              |> Enum.take(settings.history_limit)
            
            # Update state entries
            acc = Map.put(acc, key, decayed_score)
            state = Map.put(state.history, history_key, updated_history)
            
            acc
          else
            acc
          end
        
        _ ->
          acc
      end
    end)
    
    # Schedule next decay
    schedule_reputation_decay()
    
    {:noreply, %{state | reputations: updated_reputations}}
  end
  
  # Helper functions
  
  defp get_agent_reputation(state, agent_id, context) do
    # Look up the reputation score
    rep_key = "#{agent_id}:#{context}"
    
    case Map.fetch(state.reputations, rep_key) do
      {:ok, score} -> score
      :error -> state.settings.initial_score
    end
  end
  
  defp get_context_settings(state, context) do
    # Get context-specific settings or fall back to global settings
    context_settings = Map.get(state.context_settings, context, %{})
    Map.merge(state.settings, context_settings)
  end
  
  defp calculate_reputation_change(update_type, details, settings) do
    # Get base change amount
    base_change = case update_type do
      :positive -> settings.positive_impact
      :negative -> -settings.negative_impact
      _ -> 0.0
    end
    
    # Apply weight if provided
    weight = Map.get(details, :weight, 1.0)
    base_change * weight
  end
  
  defp apply_reputation_change(current_score, change_amount, settings) do
    # Apply change and clamp to valid range
    new_score = current_score + change_amount
    new_score = max(settings.min_score, min(settings.max_score, new_score))
    new_score
  end
  
  defp apply_decay(score, settings) do
    # Calculate decay amount
    decay_amount = score * settings.decay_rate
    
    # Apply decay, but don't go below initial score
    decayed = score - decay_amount
    max(settings.initial_score, decayed)
  end
  
  defp update_reputation_state(state, agent_id, context, new_score, history_entry) do
    # Update reputation score
    rep_key = "#{agent_id}:#{context}"
    updated_reputations = Map.put(state.reputations, rep_key, new_score)
    
    # Update history
    history_key = "#{agent_id}:#{context}"
    settings = get_context_settings(state, context)
    updated_history = [history_entry | Map.get(state.history, history_key, [])]
                      |> Enum.take(settings.history_limit)
    updated_histories = Map.put(state.history, history_key, updated_history)
    
    # Return updated state
    %{state | reputations: updated_reputations, history: updated_histories}
  end
  
  defp schedule_reputation_decay do
    # Run decay daily (convert to milliseconds)
    Process.send_after(self(), :apply_reputation_decay, 24 * 60 * 60 * 1000)
  end
end