defmodule Automata.DistributedCognition.BeliefArchitecture.ConsistencyManagement do
  @moduledoc """
  Consistency Management for Decentralized Belief Architecture

  This module implements mechanisms for maintaining consistency in distributed belief systems:
  - Eventual consistency guarantees with bounded time
  - Local-global belief alignment mechanisms
  - Consistency verification protocols
  """

  alias Automata.DistributedCognition.BeliefArchitecture.BeliefPropagation
  alias Automata.DistributedCognition.BeliefArchitecture.BeliefPropagation.{BeliefAtom, BeliefSet}

  defmodule ConsistencyTracker do
    @moduledoc """
    Structure for tracking consistency state across the system
    """

    @type t :: %__MODULE__{
            global_version: non_neg_integer(),
            agent_versions: %{required(pid() | atom()) => non_neg_integer()},
            last_sync_times: %{required(pid() | atom()) => DateTime.t()},
            convergence_history: list(map())
          }

    defstruct [
      :global_version,
      :agent_versions,
      :last_sync_times,
      :convergence_history
    ]

    @doc """
    Creates a new consistency tracker
    """
    @spec new() :: t()
    def new do
      %__MODULE__{
        global_version: 0,
        agent_versions: %{},
        last_sync_times: %{},
        convergence_history: []
      }
    end

    @doc """
    Increments the global version counter
    """
    @spec increment_global_version(t()) :: t()
    def increment_global_version(tracker) do
      %__MODULE__{tracker | global_version: tracker.global_version + 1}
    end

    @doc """
    Updates an agent's version
    """
    @spec update_agent_version(t(), pid() | atom(), non_neg_integer()) :: t()
    def update_agent_version(tracker, agent_id, version) do
      updated_versions = Map.put(tracker.agent_versions, agent_id, version)
      updated_times = Map.put(tracker.last_sync_times, agent_id, DateTime.utc_now())
      
      %__MODULE__{
        tracker | 
        agent_versions: updated_versions,
        last_sync_times: updated_times
      }
    end

    @doc """
    Records a convergence check result
    """
    @spec record_convergence_check(t(), float(), non_neg_integer()) :: t()
    def record_convergence_check(tracker, score, global_version) do
      new_entry = %{
        timestamp: DateTime.utc_now(),
        score: score,
        global_version: global_version
      }
      
      # Keep most recent 50 entries
      updated_history = [new_entry | tracker.convergence_history] |> Enum.take(50)
      
      %__MODULE__{tracker | convergence_history: updated_history}
    end

    @doc """
    Gets the convergence trend over time
    """
    @spec convergence_trend(t(), non_neg_integer()) :: list(float())
    def convergence_trend(tracker, count \\ 10) do
      # Take most recent entries up to count
      tracker.convergence_history
      |> Enum.take(count)
      |> Enum.map(& &1.score)
    end

    @doc """
    Detects agents that are out of sync (lagging behind global version)
    """
    @spec detect_lagging_agents(t(), non_neg_integer()) :: list({pid() | atom(), non_neg_integer()})
    def detect_lagging_agents(tracker, max_lag \\ 2) do
      Enum.filter(tracker.agent_versions, fn {agent_id, version} ->
        (tracker.global_version - version) > max_lag
      end)
      |> Enum.map(fn {agent_id, version} ->
        {agent_id, tracker.global_version - version}
      end)
    end

    @doc """
    Detects agents that haven't synced recently
    """
    @spec detect_stale_agents(t(), non_neg_integer()) :: list({pid() | atom(), DateTime.t()})
    def detect_stale_agents(tracker, max_seconds \\ 300) do
      now = DateTime.utc_now()
      
      Enum.filter(tracker.last_sync_times, fn {agent_id, last_time} ->
        diff = DateTime.diff(now, last_time, :second)
        diff > max_seconds
      end)
      |> Enum.map(fn {agent_id, last_time} ->
        {agent_id, last_time}
      end)
    end
  end

  defmodule EventualConsistency do
    @moduledoc """
    Provides mechanisms for eventual consistency with bounded time guarantees
    """

    @doc """
    Creates a consistency plan for a set of agents
    """
    @spec create_consistency_plan(list(pid() | atom()), keyword()) :: map()
    def create_consistency_plan(agents, options \\ []) do
      # Options
      max_time = Keyword.get(options, :max_time, 60_000)  # Max time in milliseconds
      sync_interval = Keyword.get(options, :sync_interval, 1_000)  # Time between syncs
      batch_size = Keyword.get(options, :batch_size, 10)  # Max agents to sync at once
      
      # Calculate number of batches
      agent_count = length(agents)
      batch_count = Float.ceil(agent_count / batch_size) |> trunc()
      
      # Calculate time per batch
      time_per_batch = max(sync_interval, max_time / max(1, batch_count))
      
      # Create batches
      batches = agents
                |> Enum.chunk_every(batch_size)
                |> Enum.with_index()
                |> Enum.map(fn {batch, index} ->
                      %{
                        id: index,
                        agents: batch,
                        start_time: trunc(index * time_per_batch),
                        end_time: trunc((index + 1) * time_per_batch)
                      }
                    end)
      
      # Create plan
      %{
        total_agents: agent_count,
        batch_count: batch_count,
        estimated_completion_time: batch_count * time_per_batch,
        batches: batches,
        options: %{
          max_time: max_time,
          sync_interval: sync_interval,
          batch_size: batch_size
        }
      }
    end

    @doc """
    Executes a consistency plan by synchronizing agent belief sets
    """
    @spec execute_consistency_plan(map(), map(), keyword()) :: map()
    def execute_consistency_plan(plan, agent_belief_sets, options \\ []) do
      # Options
      conflict_strategy = Keyword.get(options, :conflict_strategy, :probabilistic)
      track_progress = Keyword.get(options, :track_progress, false)
      
      # Initialize results tracking
      results = %{
        start_time: DateTime.utc_now(),
        end_time: nil,
        batches_completed: 0,
        agents_synced: 0,
        batch_results: [],
        convergence_achieved: false,
        final_convergence_score: 0.0
      }
      
      # Execute each batch
      {updated_belief_sets, updated_results} = 
        Enum.reduce(plan.batches, {agent_belief_sets, results}, fn batch, {current_belief_sets, current_results} ->
          # Simulate batch execution time
          if batch.start_time > 0 do
            Process.sleep(batch.start_time - (batch.start_time * Keyword.get(options, :time_scale, 1.0)) |> trunc())
          end
          
          # Execute batch synchronizations
          {synced_belief_sets, batch_result} = 
            execute_batch_sync(batch, current_belief_sets, conflict_strategy)
          
          # Check convergence if requested
          {convergence_achieved, convergence_score} = 
            if Keyword.get(options, :check_convergence, true) do
              BeliefPropagation.verify_convergence(Map.values(synced_belief_sets))
            else
              {false, 0.0}
            end
          
          # Update results
          updated_batch_results = current_results.batch_results ++ [batch_result]
          
          updated_results = %{
            current_results |
            batches_completed: current_results.batches_completed + 1,
            agents_synced: current_results.agents_synced + length(batch.agents),
            batch_results: updated_batch_results,
            convergence_achieved: convergence_achieved,
            final_convergence_score: convergence_score
          }
          
          # If tracking progress, report it
          if track_progress and Keyword.get(options, :progress_callback) do
            progress_callback = Keyword.get(options, :progress_callback)
            progress_percent = updated_results.batches_completed / plan.batch_count * 100
            
            progress_callback.(%{
              percent_complete: progress_percent,
              batches_completed: updated_results.batches_completed,
              total_batches: plan.batch_count,
              agents_synced: updated_results.agents_synced,
              total_agents: plan.total_agents,
              convergence_score: convergence_score
            })
          end
          
          # If convergence achieved and early_stop is true, stop execution
          if convergence_achieved and Keyword.get(options, :early_stop, true) do
            # Complete the results and break the execution
            final_results = %{updated_results | end_time: DateTime.utc_now()}
            throw({:convergence_achieved, synced_belief_sets, final_results})
          end
          
          {synced_belief_sets, updated_results}
        end)
      
      # Finalize results
      final_results = %{updated_results | end_time: DateTime.utc_now()}
      
      %{
        belief_sets: updated_belief_sets,
        results: final_results
      }
    rescue
      e -> 
        %{error: e, message: "Error executing consistency plan: #{inspect(e)}"}
    catch
      {:convergence_achieved, final_belief_sets, final_results} ->
        %{
          belief_sets: final_belief_sets,
          results: final_results,
          early_stop: true
        }
    end

    @doc """
    Executes a single batch of synchronization operations
    """
    @spec execute_batch_sync(map(), map(), atom()) :: {map(), map()}
    defp execute_batch_sync(batch, belief_sets, conflict_strategy) do
      batch_start_time = DateTime.utc_now()
      
      # Perform all-to-all synchronization within the batch
      synced_belief_sets = 
        Enum.reduce(cartesian_product(batch.agents, batch.agents), belief_sets, fn {agent1, agent2}, acc ->
          # Skip self-sync
          if agent1 == agent2 do
            acc
          else
            # Get belief sets
            belief_set1 = Map.get(acc, agent1)
            belief_set2 = Map.get(acc, agent2)
            
            # Skip if either agent doesn't have a belief set
            if is_nil(belief_set1) or is_nil(belief_set2) do
              acc
            else
              # Synchronize the belief sets
              {synced_set1, synced_set2} = 
                BeliefPropagation.synchronize_beliefs(belief_set1, belief_set2, [conflict_strategy: conflict_strategy])
              
              # Update the result
              acc 
              |> Map.put(agent1, synced_set1) 
              |> Map.put(agent2, synced_set2)
            end
          end
        end)
      
      batch_end_time = DateTime.utc_now()
      batch_duration = DateTime.diff(batch_end_time, batch_start_time, :millisecond)
      
      # Prepare batch result
      batch_result = %{
        batch_id: batch.id,
        start_time: batch_start_time,
        end_time: batch_end_time,
        duration_ms: batch_duration,
        agents: batch.agents,
        agent_count: length(batch.agents)
      }
      
      {synced_belief_sets, batch_result}
    end

    @doc """
    Computes the Cartesian product of two lists
    """
    @spec cartesian_product(list(any()), list(any())) :: list({any(), any()})
    defp cartesian_product(list1, list2) do
      for a <- list1, b <- list2, do: {a, b}
    end

    @doc """
    Estimates time to consistency based on current convergence trend
    """
    @spec estimate_time_to_consistency(ConsistencyTracker.t(), float()) :: {:ok, integer()} | {:error, atom()}
    def estimate_time_to_consistency(tracker, target_score \\ 0.95) do
      # Get recent convergence trend
      trend = ConsistencyTracker.convergence_trend(tracker, 5)
      
      if length(trend) < 2 do
        {:error, :insufficient_data}
      else
        # Calculate average rate of change
        changes = Enum.chunk_every(trend, 2, 1, :discard)
                    |> Enum.map(fn [a, b] -> a - b end)
        
        avg_change = Enum.sum(changes) / length(changes)
        
        # If no improvement or declining, return error
        if avg_change <= 0 do
          {:error, :no_improvement}
        else
          # Calculate how many steps needed to reach target
          latest_score = hd(trend)
          
          if latest_score >= target_score do
            {:ok, 0}  # Already at or above target
          else
            steps_needed = Float.ceil((target_score - latest_score) / avg_change) |> trunc()
            
            # Approximate time based on history timestamps
            if length(tracker.convergence_history) >= 2 do
              [latest, previous | _] = tracker.convergence_history
              time_per_step = DateTime.diff(latest.timestamp, previous.timestamp, :second)
              
              {:ok, steps_needed * time_per_step}
            else
              # Can't estimate time, just return steps
              {:ok, steps_needed}
            end
          end
        end
      end
    end

    @doc """
    Verifies if the system has achieved bounded consistency
    """
    @spec verify_bounded_consistency(list(BeliefSet.t()), ConsistencyTracker.t(), keyword()) :: 
          {:ok, float(), non_neg_integer()} | {:error, atom(), float(), non_neg_integer()}
    def verify_bounded_consistency(belief_sets, tracker, options \\ []) do
      # Options
      target_score = Keyword.get(options, :target_score, 0.95)
      max_time = Keyword.get(options, :max_time, 300)  # Max time in seconds
      
      # Check current convergence
      {convergence_achieved, convergence_score} = 
        BeliefPropagation.verify_convergence(belief_sets, [convergence_threshold: target_score])
      
      # Record the check
      updated_tracker = 
        ConsistencyTracker.record_convergence_check(tracker, convergence_score, tracker.global_version)
      
      if convergence_achieved do
        {:ok, convergence_score, 0}
      else
        # Estimate time to consistency
        case estimate_time_to_consistency(updated_tracker, target_score) do
          {:ok, estimated_time} ->
            if estimated_time <= max_time do
              {:ok, convergence_score, estimated_time}
            else
              {:error, :exceeds_time_bound, convergence_score, estimated_time}
            end
            
          {:error, reason} ->
            {:error, reason, convergence_score, 0}
        end
      end
    end
  end

  defmodule GlobalAlignment do
    @moduledoc """
    Provides mechanisms for aligning local beliefs with global state
    """

    @doc """
    Constructs a global belief state from multiple local belief sets
    """
    @spec construct_global_belief_state(list(BeliefSet.t()), keyword()) :: BeliefSet.t()
    def construct_global_belief_state(belief_sets, options \\ []) do
      # Options
      conflict_strategy = Keyword.get(options, :conflict_strategy, :probabilistic)
      confidence_threshold = Keyword.get(options, :confidence_threshold, 0.5)
      
      if Enum.empty?(belief_sets) do
        # Return empty global belief set
        BeliefSet.new(:global)
      else
        # Start with an empty global belief set
        global_set = BeliefSet.new(:global)
        
        # Collect all unique beliefs across belief sets
        all_beliefs = 
          belief_sets
          |> Enum.flat_map(fn set -> Map.values(set.beliefs) end)
        
        # Group beliefs by ID
        beliefs_by_id = Enum.group_by(all_beliefs, & &1.id)
        
        # Process each belief ID
        Enum.reduce(beliefs_by_id, global_set, fn {belief_id, id_beliefs}, acc_global ->
          process_global_belief(belief_id, id_beliefs, acc_global, conflict_strategy, confidence_threshold)
        end)
      end
    end

    @doc """
    Process a single belief ID for inclusion in the global belief state
    """
    @spec process_global_belief(String.t(), list(BeliefAtom.t()), BeliefSet.t(), atom(), float()) :: BeliefSet.t()
    defp process_global_belief(belief_id, beliefs, global_set, conflict_strategy, confidence_threshold) do
      cond do
        # If only one belief, add it if above threshold
        length(beliefs) == 1 ->
          belief = hd(beliefs)
          if belief.confidence >= confidence_threshold do
            BeliefSet.add_belief(global_set, belief)
          else
            global_set
          end
          
        # If multiple beliefs with same ID, handle conflicts
        true ->
          # Check if beliefs actually conflict
          [first | rest] = beliefs
          
          if Enum.all?(rest, fn b -> b.content == first.content end) do
            # Same content, no conflict, aggregate confidences
            aggregated = BeliefPropagation.aggregate_beliefs(beliefs)
            
            if aggregated.confidence >= confidence_threshold do
              BeliefSet.add_belief(global_set, aggregated)
            else
              global_set
            end
          else
            # Conflicting content, resolve conflicts
            resolved = Enum.reduce(rest, first, fn b, acc ->
              BeliefPropagation.resolve_conflict(acc, b, conflict_strategy)
            end)
            
            if resolved.confidence >= confidence_threshold do
              BeliefSet.add_belief(global_set, resolved)
            else
              global_set
            end
          end
      end
    end

    @doc """
    Aligns a local belief set with the global belief state
    """
    @spec align_with_global(BeliefSet.t(), BeliefSet.t(), keyword()) :: BeliefSet.t()
    def align_with_global(local_set, global_set, options \\ []) do
      # Options
      enforcement_level = Keyword.get(options, :enforcement_level, :advisory)
      required_beliefs = Keyword.get(options, :required_beliefs, [])
      prohibited_beliefs = Keyword.get(options, :prohibited_beliefs, [])
      
      case enforcement_level do
        :strong ->
          # Strong enforcement - local set becomes global set (overwrite)
          # Only keep agent_id from local_set
          %BeliefSet{global_set | agent_id: local_set.agent_id}
          
        :additive ->
          # Additive enforcement - add global beliefs but don't remove local ones
          Enum.reduce(Map.values(global_set.beliefs), local_set, fn global_belief, acc ->
            case BeliefSet.get_belief(acc, global_belief.id) do
              nil ->
                # Belief doesn't exist locally, add it
                BeliefSet.add_belief(acc, global_belief)
                
              local_belief ->
                # Belief exists locally, keep the highest confidence one
                if global_belief.confidence > local_belief.confidence do
                  BeliefSet.update_belief(acc, global_belief)
                else
                  acc
                end
            end
          end)
          
        :advisory ->
          # Advisory enforcement - local set keeps precedence, but consider global
          BeliefSet.merge(local_set, global_set, :highest_confidence)
          
        :selective ->
          # Selective enforcement - enforce only required/prohibited beliefs
          updated_set = enforce_required_beliefs(local_set, global_set, required_beliefs)
          enforce_prohibited_beliefs(updated_set, prohibited_beliefs)
          
        _ ->
          # Default to advisory
          BeliefSet.merge(local_set, global_set, :highest_confidence)
      end
    end

    @doc """
    Enforces required beliefs from global state
    """
    @spec enforce_required_beliefs(BeliefSet.t(), BeliefSet.t(), list(String.t())) :: BeliefSet.t()
    defp enforce_required_beliefs(local_set, global_set, required_belief_ids) do
      # For each required belief ID, ensure it exists in local set
      Enum.reduce(required_belief_ids, local_set, fn belief_id, acc ->
        global_belief = BeliefSet.get_belief(global_set, belief_id)
        
        if global_belief do
          # Global belief exists, ensure it's in local set
          BeliefSet.update_belief(acc, global_belief)
        else
          # Global belief doesn't exist, can't enforce
          acc
        end
      end)
    end

    @doc """
    Enforces prohibited beliefs
    """
    @spec enforce_prohibited_beliefs(BeliefSet.t(), list(String.t())) :: BeliefSet.t()
    defp enforce_prohibited_beliefs(local_set, prohibited_belief_ids) do
      # For each prohibited belief ID, ensure it doesn't exist in local set
      Enum.reduce(prohibited_belief_ids, local_set, fn belief_id, acc ->
        BeliefSet.remove_belief(acc, belief_id)
      end)
    end

    @doc """
    Computes alignment score between local and global belief sets
    """
    @spec compute_alignment_score(BeliefSet.t(), BeliefSet.t()) :: float()
    def compute_alignment_score(local_set, global_set) do
      # Get all global belief IDs
      global_ids = MapSet.new(Map.keys(global_set.beliefs))
      
      # If global is empty, local is perfectly aligned
      if MapSet.size(global_ids) == 0 do
        1.0
      else
        # Check how many global beliefs exist in local set with same content
        aligned_count = 
          global_ids
          |> Enum.count(fn id ->
                 global_belief = BeliefSet.get_belief(global_set, id)
                 local_belief = BeliefSet.get_belief(local_set, id)
                 
                 if local_belief do
                   # Belief exists locally, check if content matches
                   local_belief.content == global_belief.content
                 else
                   false
                 end
               end)
        
        # Compute alignment score
        aligned_count / MapSet.size(global_ids)
      end
    end

    @doc """
    Identifies agents with low alignment to global state
    """
    @spec identify_misaligned_agents(map(), BeliefSet.t(), float()) :: list({atom() | pid(), float()})
    def identify_misaligned_agents(agent_belief_sets, global_set, threshold \\ 0.7) do
      # Calculate alignment scores for all agents
      alignment_scores = 
        Enum.map(agent_belief_sets, fn {agent_id, belief_set} ->
          score = compute_alignment_score(belief_set, global_set)
          {agent_id, score}
        end)
      
      # Filter agents below threshold
      Enum.filter(alignment_scores, fn {_, score} -> score < threshold end)
    end

    @doc """
    Creates a global alignment plan for misaligned agents
    """
    @spec create_alignment_plan(list({atom() | pid(), float()}), BeliefSet.t(), keyword()) :: map()
    def create_alignment_plan(misaligned_agents, global_set, options \\ []) do
      # Options
      max_time = Keyword.get(options, :max_time, 30_000)  # Max time in milliseconds
      enforcement_strategy = Keyword.get(options, :enforcement_strategy, :advisory)
      priority_threshold = Keyword.get(options, :priority_threshold, 0.5)
      
      # Sort agents by alignment score (most misaligned first)
      sorted_agents = Enum.sort_by(misaligned_agents, fn {_, score} -> score end)
      
      # Find globally important beliefs
      important_beliefs = 
        global_set.beliefs
        |> Map.values()
        |> Enum.filter(&(&1.confidence >= priority_threshold))
        |> Enum.map(&(&1.id))
      
      # Create the plan
      %{
        agents: Enum.map(sorted_agents, fn {agent_id, score} -> %{id: agent_id, alignment: score} end),
        global_version: global_set.last_updated,
        important_beliefs: important_beliefs,
        enforcement_strategy: enforcement_strategy,
        estimated_time: min(length(sorted_agents) * 100, max_time),
        max_time: max_time
      }
    end

    @doc """
    Executes a global alignment plan
    """
    @spec execute_alignment_plan(map(), map(), BeliefSet.t(), keyword()) :: map()
    def execute_alignment_plan(plan, agent_belief_sets, global_set, options \\ []) do
      # Options
      track_progress = Keyword.get(options, :track_progress, false)
      
      # Initialize results
      results = %{
        start_time: DateTime.utc_now(),
        end_time: nil,
        agents_aligned: 0,
        agent_results: []
      }
      
      # Process each agent
      {updated_belief_sets, updated_results} = 
        Enum.reduce_while(plan.agents, {agent_belief_sets, results}, fn agent_info, {current_sets, current_results} ->
          # Get the agent's belief set
          agent_id = agent_info.id
          belief_set = Map.get(current_sets, agent_id)
          
          if belief_set do
            # Align agent with global state
            alignment_options = [
              enforcement_level: plan.enforcement_strategy,
              required_beliefs: plan.important_beliefs
            ]
            
            aligned_set = align_with_global(belief_set, global_set, alignment_options)
            
            # Calculate new alignment score
            new_score = compute_alignment_score(aligned_set, global_set)
            
            # Update results
            agent_result = %{
              agent_id: agent_id,
              before_score: agent_info.alignment,
              after_score: new_score,
              improvement: new_score - agent_info.alignment
            }
            
            updated_agent_results = current_results.agent_results ++ [agent_result]
            
            updated_results = %{
              current_results |
              agents_aligned: current_results.agents_aligned + 1,
              agent_results: updated_agent_results
            }
            
            # Update belief sets
            updated_sets = Map.put(current_sets, agent_id, aligned_set)
            
            # If tracking progress, report it
            if track_progress and Keyword.get(options, :progress_callback) do
              progress_callback = Keyword.get(options, :progress_callback)
              progress_percent = updated_results.agents_aligned / length(plan.agents) * 100
              
              progress_callback.(%{
                percent_complete: progress_percent,
                agents_aligned: updated_results.agents_aligned,
                total_agents: length(plan.agents),
                latest_agent: %{
                  id: agent_id,
                  before: agent_info.alignment,
                  after: new_score
                }
              })
            end
            
            # Check if we've exceeded max time
            elapsed = DateTime.diff(DateTime.utc_now(), current_results.start_time, :millisecond)
            
            if elapsed > plan.max_time do
              # Time exceeded, stop processing
              {:halt, {updated_sets, updated_results}}
            else
              {:cont, {updated_sets, updated_results}}
            end
          else
            # Agent not found, skip
            {:cont, {current_sets, current_results}}
          end
        end)
      
      # Finalize results
      final_results = %{updated_results | end_time: DateTime.utc_now()}
      
      %{
        belief_sets: updated_belief_sets,
        results: final_results
      }
    end
  end

  defmodule ConsistencyVerification do
    @moduledoc """
    Provides protocols for verifying consistency of distributed beliefs
    """

    @type verification_result :: %{
            consistent: boolean(),
            conflicts: list(map()),
            alignment_score: float(),
            partition_detected: boolean(),
            convergence_score: float(),
            recommendations: list(String.t())
          }

    @doc """
    Performs comprehensive consistency verification
    """
    @spec verify_consistency(map(), keyword()) :: verification_result()
    def verify_consistency(agent_belief_sets, options \\ []) do
      # Options
      consistency_threshold = Keyword.get(options, :consistency_threshold, 0.9)
      alignment_threshold = Keyword.get(options, :alignment_threshold, 0.8)
      
      # Convert to list of belief sets
      belief_sets = Map.values(agent_belief_sets)
      
      # Construct global belief state
      global_set = GlobalAlignment.construct_global_belief_state(belief_sets)
      
      # Check for conflicts in global set
      conflicts = BeliefSet.find_conflicts(global_set)
      
      # Check for network partition
      {partition_detected, _clusters} = 
        BeliefPropagation.AsyncUpdates.detect_network_partition(belief_sets)
      
      # Check convergence
      {_converged, convergence_score} = 
        BeliefPropagation.verify_convergence(belief_sets)
      
      # Check alignment with global state
      alignment_scores = 
        Enum.map(agent_belief_sets, fn {agent_id, set} ->
          {agent_id, GlobalAlignment.compute_alignment_score(set, global_set)}
        end)
      
      avg_alignment = 
        if Enum.empty?(alignment_scores) do
          1.0
        else
          alignment_scores
          |> Enum.map(fn {_, score} -> score end)
          |> Enum.sum()
          |> Kernel./(length(alignment_scores))
        end
      
      # Generate recommendations
      recommendations = generate_recommendations(
        conflicts,
        partition_detected,
        convergence_score,
        avg_alignment,
        consistency_threshold,
        alignment_threshold
      )
      
      # Return result
      %{
        consistent: Enum.empty?(conflicts) and convergence_score >= consistency_threshold and avg_alignment >= alignment_threshold,
        conflicts: conflicts_to_map(conflicts),
        alignment_score: avg_alignment,
        partition_detected: partition_detected,
        convergence_score: convergence_score,
        recommendations: recommendations
      }
    end

    @doc """
    Converts conflict tuples to maps for easier display/processing
    """
    @spec conflicts_to_map(list({BeliefAtom.t(), BeliefAtom.t()})) :: list(map())
    defp conflicts_to_map(conflicts) do
      Enum.map(conflicts, fn {belief1, belief2} ->
        %{
          belief1: %{
            id: belief1.id,
            content: belief1.content,
            confidence: belief1.confidence,
            source: belief1.source
          },
          belief2: %{
            id: belief2.id,
            content: belief2.content,
            confidence: belief2.confidence,
            source: belief2.source
          }
        }
      end)
    end

    @doc """
    Generates recommendations based on verification results
    """
    @spec generate_recommendations(list(), boolean(), float(), float(), float(), float()) :: list(String.t())
    defp generate_recommendations(conflicts, partition_detected, convergence_score, alignment_score, consistency_threshold, alignment_threshold) do
      recommendations = []
      
      # Add recommendations based on conflicts
      recommendations = 
        if not Enum.empty?(conflicts) do
          ["Resolve conflicting beliefs in global state" | recommendations]
        else
          recommendations
        end
      
      # Add recommendations based on partition
      recommendations = 
        if partition_detected do
          ["Network partition detected - check agent connectivity",
           "Consider implementing partition-tolerant belief updates" | recommendations]
        else
          recommendations
        end
      
      # Add recommendations based on convergence
      recommendations = 
        if convergence_score < consistency_threshold do
          ["Improve belief propagation to increase convergence (current: #{Float.round(convergence_score, 2)})",
           "Consider increasing sync frequency between agents" | recommendations]
        else
          recommendations
        end
      
      # Add recommendations based on alignment
      recommendations = 
        if alignment_score < alignment_threshold do
          ["Improve global-local alignment (current: #{Float.round(alignment_score, 2)})",
           "Consider stronger enforcement policy for important beliefs" | recommendations]
        else
          recommendations
        end
      
      # Return all recommendations
      recommendations
    end

    @doc """
    Verifies consistency of specific beliefs across agents
    """
    @spec verify_belief_consistency(list(String.t()), map()) :: map()
    def verify_belief_consistency(belief_ids, agent_belief_sets) do
      # Check consistency for each belief ID
      Enum.reduce(belief_ids, %{}, fn belief_id, results ->
        # Collect all instances of this belief across agents
        belief_instances = 
          Enum.flat_map(agent_belief_sets, fn {agent_id, set} ->
            case BeliefSet.get_belief(set, belief_id) do
              nil -> []
              belief -> [%{agent_id: agent_id, belief: belief}]
            end
          end)
        
        # Skip if no instances found
        if Enum.empty?(belief_instances) do
          Map.put(results, belief_id, %{present: false})
        else
          # Check if all instances have same content
          first_content = hd(belief_instances).belief.content
          
          content_consistent = 
            Enum.all?(belief_instances, fn instance ->
              instance.belief.content == first_content
            end)
          
          # Calculate confidence statistics
          confidences = Enum.map(belief_instances, fn instance -> instance.belief.confidence end)
          avg_confidence = Enum.sum(confidences) / length(confidences)
          min_confidence = Enum.min(confidences)
          max_confidence = Enum.max(confidences)
          
          # Calculate consistency score
          consistency_score = 
            if content_consistent do
              # All content matches, score based on confidence agreement
              confidence_variance = variance(confidences)
              1.0 - min(1.0, confidence_variance * 4)  # Scale variance to 0-1
            else
              # Content inconsistent, count percentage with majority content
              content_groups = Enum.group_by(belief_instances, fn instance -> instance.belief.content end)
              {_, majority_group} = Enum.max_by(content_groups, fn {_, group} -> length(group) end)
              
              length(majority_group) / length(belief_instances)
            end
          
          # Store results
          Map.put(results, belief_id, %{
            present: true,
            instances: length(belief_instances),
            content_consistent: content_consistent,
            confidence_stats: %{
              average: avg_confidence,
              min: min_confidence,
              max: max_confidence,
              range: max_confidence - min_confidence
            },
            consistency_score: consistency_score
          })
        end
      end)
    end

    @doc """
    Calculates variance of a list of numbers
    """
    @spec variance(list(number())) :: float()
    defp variance(numbers) do
      mean = Enum.sum(numbers) / length(numbers)
      
      numbers
      |> Enum.map(fn x -> (x - mean) * (x - mean) end)
      |> Enum.sum()
      |> Kernel./(length(numbers))
    end

    @doc """
    Verifies propagation timing across agents
    """
    @spec verify_propagation_timing(map(), list(String.t()), keyword()) :: map()
    def verify_propagation_timing(agent_belief_sets, recent_belief_ids, options \\ []) do
      # Options
      expected_propagation_time = Keyword.get(options, :expected_time, 1000)  # ms
      
      # For each recent belief, check propagation time
      Enum.reduce(recent_belief_ids, %{}, fn belief_id, results ->
        # Collect timestamps for this belief across agents
        belief_timestamps = 
          Enum.flat_map(agent_belief_sets, fn {agent_id, set} ->
            case BeliefSet.get_belief(set, belief_id) do
              nil -> []
              belief -> [%{agent_id: agent_id, timestamp: belief.timestamp}]
            end
          end)
        
        # Skip if fewer than 2 instances found
        if length(belief_timestamps) < 2 do
          Map.put(results, belief_id, %{measurable: false})
        else
          # Find earliest and latest timestamp
          earliest = Enum.min_by(belief_timestamps, fn instance -> DateTime.to_unix(instance.timestamp) end)
          latest = Enum.max_by(belief_timestamps, fn instance -> DateTime.to_unix(instance.timestamp) end)
          
          # Calculate propagation time in milliseconds
          propagation_time = DateTime.diff(latest.timestamp, earliest.timestamp, :millisecond)
          
          # Calculate coverage (percentage of agents that have received the belief)
          coverage = length(belief_timestamps) / map_size(agent_belief_sets)
          
          # Store results
          Map.put(results, belief_id, %{
            measurable: true,
            propagation_time_ms: propagation_time,
            meets_expectation: propagation_time <= expected_propagation_time,
            coverage: coverage,
            first_agent: earliest.agent_id,
            last_agent: latest.agent_id
          })
        end
      end)
    end
  end

  @doc """
  Creates a consistency tracker for monitoring system consistency
  """
  @spec create_consistency_tracker() :: ConsistencyTracker.t()
  def create_consistency_tracker do
    ConsistencyTracker.new()
  end

  @doc """
  Creates a consistency plan for synchronizing agent beliefs
  """
  @spec create_consistency_plan(list(pid() | atom()), keyword()) :: map()
  def create_consistency_plan(agents, options \\ []) do
    EventualConsistency.create_consistency_plan(agents, options)
  end

  @doc """
  Executes a consistency plan to synchronize agent beliefs
  """
  @spec execute_consistency_plan(map(), map(), keyword()) :: map()
  def execute_consistency_plan(plan, agent_belief_sets, options \\ []) do
    EventualConsistency.execute_consistency_plan(plan, agent_belief_sets, options)
  end

  @doc """
  Verifies if the system has achieved bounded consistency
  """
  @spec verify_bounded_consistency(list(BeliefSet.t()), ConsistencyTracker.t(), keyword()) :: 
        {:ok, float(), non_neg_integer()} | {:error, atom(), float(), non_neg_integer()}
  def verify_bounded_consistency(belief_sets, tracker, options \\ []) do
    EventualConsistency.verify_bounded_consistency(belief_sets, tracker, options)
  end

  @doc """
  Constructs a global belief state from multiple local belief sets
  """
  @spec construct_global_belief_state(list(BeliefSet.t()), keyword()) :: BeliefSet.t()
  def construct_global_belief_state(belief_sets, options \\ []) do
    GlobalAlignment.construct_global_belief_state(belief_sets, options)
  end

  @doc """
  Aligns a local belief set with the global belief state
  """
  @spec align_with_global(BeliefSet.t(), BeliefSet.t(), keyword()) :: BeliefSet.t()
  def align_with_global(local_set, global_set, options \\ []) do
    GlobalAlignment.align_with_global(local_set, global_set, options)
  end

  @doc """
  Computes alignment score between local and global belief sets
  """
  @spec compute_alignment_score(BeliefSet.t(), BeliefSet.t()) :: float()
  def compute_alignment_score(local_set, global_set) do
    GlobalAlignment.compute_alignment_score(local_set, global_set)
  end

  @doc """
  Identifies agents with low alignment to global state
  """
  @spec identify_misaligned_agents(map(), BeliefSet.t(), float()) :: list({atom() | pid(), float()})
  def identify_misaligned_agents(agent_belief_sets, global_set, threshold \\ 0.7) do
    GlobalAlignment.identify_misaligned_agents(agent_belief_sets, global_set, threshold)
  end

  @doc """
  Creates a global alignment plan for misaligned agents
  """
  @spec create_alignment_plan(list({atom() | pid(), float()}), BeliefSet.t(), keyword()) :: map()
  def create_alignment_plan(misaligned_agents, global_set, options \\ []) do
    GlobalAlignment.create_alignment_plan(misaligned_agents, global_set, options)
  end

  @doc """
  Executes a global alignment plan
  """
  @spec execute_alignment_plan(map(), map(), BeliefSet.t(), keyword()) :: map()
  def execute_alignment_plan(plan, agent_belief_sets, global_set, options \\ []) do
    GlobalAlignment.execute_alignment_plan(plan, agent_belief_sets, global_set, options)
  end

  @doc """
  Performs comprehensive consistency verification
  """
  @spec verify_consistency(map(), keyword()) :: ConsistencyVerification.verification_result()
  def verify_consistency(agent_belief_sets, options \\ []) do
    ConsistencyVerification.verify_consistency(agent_belief_sets, options)
  end

  @doc """
  Verifies consistency of specific beliefs across agents
  """
  @spec verify_belief_consistency(list(String.t()), map()) :: map()
  def verify_belief_consistency(belief_ids, agent_belief_sets) do
    ConsistencyVerification.verify_belief_consistency(belief_ids, agent_belief_sets)
  end

  @doc """
  Verifies propagation timing across agents
  """
  @spec verify_propagation_timing(map(), list(String.t()), keyword()) :: map()
  def verify_propagation_timing(agent_belief_sets, recent_belief_ids, options \\ []) do
    ConsistencyVerification.verify_propagation_timing(agent_belief_sets, recent_belief_ids, options)
  end
end