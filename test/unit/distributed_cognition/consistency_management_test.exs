defmodule DistributedCognition.ConsistencyManagementTest do
  use ExUnit.Case, async: true
  
  alias Automata.DistributedCognition.BeliefArchitecture.BeliefPropagation
  alias Automata.DistributedCognition.BeliefArchitecture.BeliefPropagation.{BeliefAtom, BeliefSet}
  alias Automata.DistributedCognition.BeliefArchitecture.ConsistencyManagement
  alias Automata.DistributedCognition.BeliefArchitecture.ConsistencyManagement.{
    ConsistencyTracker,
    EventualConsistency,
    GlobalAlignment,
    ConsistencyVerification
  }

  describe "ConsistencyTracker" do
    test "creates a new consistency tracker" do
      tracker = ConsistencyManagement.create_consistency_tracker()
      
      assert tracker.global_version == 0
      assert tracker.agent_versions == %{}
      assert tracker.last_sync_times == %{}
      assert tracker.convergence_history == []
    end
    
    test "increments global version" do
      tracker = ConsistencyTracker.new()
      updated = ConsistencyTracker.increment_global_version(tracker)
      
      assert updated.global_version == 1
      
      # Increment again
      updated2 = ConsistencyTracker.increment_global_version(updated)
      assert updated2.global_version == 2
    end
    
    test "updates agent version" do
      tracker = ConsistencyTracker.new()
      agent_id = :test_agent
      version = 5
      
      updated = ConsistencyTracker.update_agent_version(tracker, agent_id, version)
      
      assert Map.get(updated.agent_versions, agent_id) == version
      assert Map.has_key?(updated.last_sync_times, agent_id)
    end
    
    test "records convergence check" do
      tracker = ConsistencyTracker.new()
      score = 0.85
      version = 3
      
      updated = ConsistencyTracker.record_convergence_check(tracker, score, version)
      
      assert length(updated.convergence_history) == 1
      history_entry = hd(updated.convergence_history)
      assert history_entry.score == score
      assert history_entry.global_version == version
    end
    
    test "detects lagging agents" do
      # Create tracker with global version 5
      tracker = ConsistencyTracker.new()
      tracker = %{tracker | global_version: 5}
      
      # Add agents with different versions
      tracker = ConsistencyTracker.update_agent_version(tracker, :agent1, 5)  # Up to date
      tracker = ConsistencyTracker.update_agent_version(tracker, :agent2, 3)  # Lagging by 2
      tracker = ConsistencyTracker.update_agent_version(tracker, :agent3, 1)  # Lagging by 4
      
      # Detect agents lagging by more than 2 versions
      lagging = ConsistencyTracker.detect_lagging_agents(tracker, 2)
      
      assert length(lagging) == 1
      assert {agent_id, _lag} = hd(lagging)
      assert agent_id == :agent3
    end
  end
  
  describe "EventualConsistency" do
    test "creates a consistency plan" do
      agents = [:agent1, :agent2, :agent3, :agent4]
      
      plan = ConsistencyManagement.create_consistency_plan(agents)
      
      assert plan.total_agents == 4
      assert is_integer(plan.batch_count)
      assert is_number(plan.estimated_completion_time)
      assert is_list(plan.batches)
      assert length(plan.batches) > 0
    end
    
    test "executes a consistency plan" do
      # Create agents with belief sets
      agent1 = :agent1
      agent2 = :agent2
      
      belief_set1 = BeliefPropagation.create_belief_set(agent1)
      belief_set2 = BeliefPropagation.create_belief_set(agent2)
      
      # Add different beliefs to each set
      belief1 = BeliefPropagation.create_belief("content 1", agent1, 0.8)
      belief2 = BeliefPropagation.create_belief("content 2", agent2, 0.9)
      
      belief_set1 = BeliefSet.add_belief(belief_set1, belief1)
      belief_set2 = BeliefSet.add_belief(belief_set2, belief2)
      
      agent_belief_sets = %{
        agent1 => belief_set1,
        agent2 => belief_set2
      }
      
      # Create a simple consistency plan
      plan = %{
        total_agents: 2,
        batch_count: 1,
        estimated_completion_time: 1000,
        batches: [
          %{
            id: 0,
            agents: [agent1, agent2],
            start_time: 0,
            end_time: 1000
          }
        ],
        options: %{
          max_time: 5000,
          sync_interval: 1000,
          batch_size: 2
        }
      }
      
      # Execute the plan
      result = ConsistencyManagement.execute_consistency_plan(
        plan, 
        agent_belief_sets, 
        [time_scale: 0.1]  # Speed up for test
      )
      
      assert is_map(result)
      assert is_map(result.belief_sets)
      assert is_map(result.results)
      
      # Check that beliefs have been synchronized
      updated_set1 = result.belief_sets[agent1]
      updated_set2 = result.belief_sets[agent2]
      
      assert BeliefSet.get_belief(updated_set1, belief1.id) != nil
      assert BeliefSet.get_belief(updated_set1, belief2.id) != nil
      assert BeliefSet.get_belief(updated_set2, belief1.id) != nil
      assert BeliefSet.get_belief(updated_set2, belief2.id) != nil
    end
    
    test "verifies bounded consistency" do
      # Create belief sets with good convergence
      belief_set1 = BeliefPropagation.create_belief_set(:agent1)
      belief_set2 = BeliefPropagation.create_belief_set(:agent2)
      
      # Share the same belief in both sets
      shared_belief = BeliefPropagation.create_belief("shared content", :shared, 0.9)
      belief_set1 = BeliefSet.add_belief(belief_set1, shared_belief)
      belief_set2 = BeliefSet.add_belief(belief_set2, shared_belief)
      
      # Create a tracker with some history
      tracker = ConsistencyTracker.new()
      |> ConsistencyTracker.increment_global_version()
      |> ConsistencyTracker.record_convergence_check(0.8, 0)
      |> ConsistencyTracker.record_convergence_check(0.9, 1)
      
      # Verify bounded consistency
      result = ConsistencyManagement.verify_bounded_consistency(
        [belief_set1, belief_set2],
        tracker
      )
      
      assert {:ok, score, _time} = result
      assert score > 0.9
    end
  end
  
  describe "GlobalAlignment" do
    test "constructs a global belief state" do
      # Create belief sets
      belief_set1 = BeliefPropagation.create_belief_set(:agent1)
      belief_set2 = BeliefPropagation.create_belief_set(:agent2)
      
      # Add beliefs to each set
      belief1 = BeliefPropagation.create_belief("content 1", :agent1, 0.8)
      belief2 = BeliefPropagation.create_belief("content 2", :agent2, 0.9)
      shared_belief = BeliefPropagation.create_belief("shared content", :shared, 0.95)
      
      belief_set1 = belief_set1
                    |> BeliefSet.add_belief(belief1)
                    |> BeliefSet.add_belief(shared_belief)
                    
      belief_set2 = belief_set2
                    |> BeliefSet.add_belief(belief2)
                    |> BeliefSet.add_belief(shared_belief)
      
      # Construct global state
      global_set = ConsistencyManagement.construct_global_belief_state([belief_set1, belief_set2])
      
      # Global set should have all three beliefs
      assert global_set.agent_id == :global
      assert map_size(global_set.beliefs) == 3
      assert BeliefSet.get_belief(global_set, belief1.id) != nil
      assert BeliefSet.get_belief(global_set, belief2.id) != nil
      assert BeliefSet.get_belief(global_set, shared_belief.id) != nil
    end
    
    test "aligns local belief set with global state" do
      # Create belief sets
      local_set = BeliefPropagation.create_belief_set(:local_agent)
      global_set = BeliefPropagation.create_belief_set(:global)
      
      # Add beliefs
      local_belief = BeliefPropagation.create_belief("local content", :local_agent, 0.8)
      global_belief = BeliefPropagation.create_belief("global content", :global, 0.9)
      
      local_set = BeliefSet.add_belief(local_set, local_belief)
      global_set = BeliefSet.add_belief(global_set, global_belief)
      
      # Align local with global (advisory mode - keep local precedence but add global)
      aligned_set = ConsistencyManagement.align_with_global(local_set, global_set)
      
      # Should have both beliefs
      assert BeliefSet.get_belief(aligned_set, local_belief.id) != nil
      assert BeliefSet.get_belief(aligned_set, global_belief.id) != nil
      
      # Now test strong enforcement (overwrite local)
      aligned_set2 = ConsistencyManagement.align_with_global(
        local_set, 
        global_set, 
        [enforcement_level: :strong]
      )
      
      # Should only have global belief, but keep local agent ID
      assert aligned_set2.agent_id == :local_agent
      assert BeliefSet.get_belief(aligned_set2, local_belief.id) == nil
      assert BeliefSet.get_belief(aligned_set2, global_belief.id) != nil
    end
    
    test "computes alignment score" do
      # Create belief sets
      local_set = BeliefPropagation.create_belief_set(:local_agent)
      global_set = BeliefPropagation.create_belief_set(:global)
      
      # Case 1: Perfect alignment - all global beliefs in local set
      belief1 = BeliefPropagation.create_belief("content 1", :source, 0.8)
      
      global_set1 = BeliefSet.add_belief(global_set, belief1)
      local_set1 = BeliefSet.add_belief(local_set, belief1)
      
      score1 = ConsistencyManagement.compute_alignment_score(local_set1, global_set1)
      assert score1 == 1.0
      
      # Case 2: Partial alignment - some global beliefs missing from local
      belief2 = BeliefPropagation.create_belief("content 2", :source, 0.9)
      global_set2 = BeliefSet.add_belief(global_set1, belief2)
      
      score2 = ConsistencyManagement.compute_alignment_score(local_set1, global_set2)
      assert score2 == 0.5  # 1 of 2 global beliefs present
    end
    
    test "identifies misaligned agents" do
      # Create belief sets
      global_set = BeliefPropagation.create_belief_set(:global)
      
      belief1 = BeliefPropagation.create_belief("content 1", :source, 0.8)
      belief2 = BeliefPropagation.create_belief("content 2", :source, 0.9)
      
      global_set = global_set
                   |> BeliefSet.add_belief(belief1)
                   |> BeliefSet.add_belief(belief2)
      
      # Create agent belief sets with varying alignment
      agent1_set = BeliefPropagation.create_belief_set(:agent1)
                   |> BeliefSet.add_belief(belief1)
                   |> BeliefSet.add_belief(belief2)
                   
      agent2_set = BeliefPropagation.create_belief_set(:agent2)
                   |> BeliefSet.add_belief(belief1)
                   
      agent3_set = BeliefPropagation.create_belief_set(:agent3)
      
      agent_belief_sets = %{
        :agent1 => agent1_set,
        :agent2 => agent2_set,
        :agent3 => agent3_set
      }
      
      # Identify misaligned agents
      misaligned = ConsistencyManagement.identify_misaligned_agents(
        agent_belief_sets,
        global_set,
        0.6  # Threshold
      )
      
      # Agent1 should be aligned, Agent2 partially aligned, Agent3 completely misaligned
      assert length(misaligned) == 2
      
      # Check that agent3 (completely misaligned) has lowest score
      {worst_agent, worst_score} = Enum.min_by(misaligned, fn {_, score} -> score end)
      assert worst_agent == :agent3
      assert worst_score == 0.0
    end
    
    test "creates and executes alignment plan" do
      # Create global belief set
      global_set = BeliefPropagation.create_belief_set(:global)
      
      belief1 = BeliefPropagation.create_belief("content 1", :source, 0.8)
      belief2 = BeliefPropagation.create_belief("content 2", :source, 0.9)
      
      global_set = global_set
                   |> BeliefSet.add_belief(belief1)
                   |> BeliefSet.add_belief(belief2)
      
      # Create agent belief sets with varying alignment
      agent1_set = BeliefPropagation.create_belief_set(:agent1)
                   
      agent2_set = BeliefPropagation.create_belief_set(:agent2)
                   |> BeliefSet.add_belief(belief1)
      
      agent_belief_sets = %{
        :agent1 => agent1_set,
        :agent2 => agent2_set
      }
      
      # Identify misaligned agents
      misaligned = [
        {:agent1, 0.0},
        {:agent2, 0.5}
      ]
      
      # Create alignment plan
      plan = ConsistencyManagement.create_alignment_plan(
        misaligned,
        global_set,
        [max_time: 1000]
      )
      
      assert length(plan.agents) == 2
      assert plan.enforcement_strategy == :advisory
      
      # Execute alignment plan
      result = ConsistencyManagement.execute_alignment_plan(
        plan,
        agent_belief_sets,
        global_set
      )
      
      assert is_map(result)
      assert is_map(result.belief_sets)
      assert is_map(result.results)
      
      # Check that beliefs have been aligned
      updated_agent1 = result.belief_sets[:agent1]
      updated_agent2 = result.belief_sets[:agent2]
      
      # Both agents should now have both beliefs
      assert BeliefSet.get_belief(updated_agent1, belief1.id) != nil
      assert BeliefSet.get_belief(updated_agent1, belief2.id) != nil
      assert BeliefSet.get_belief(updated_agent2, belief1.id) != nil
      assert BeliefSet.get_belief(updated_agent2, belief2.id) != nil
    end
  end
  
  describe "ConsistencyVerification" do
    test "performs comprehensive consistency verification" do
      # Create belief sets
      belief_set1 = BeliefPropagation.create_belief_set(:agent1)
      belief_set2 = BeliefPropagation.create_belief_set(:agent2)
      
      # Add same beliefs to each (good consistency)
      belief1 = BeliefPropagation.create_belief("content 1", :source, 0.8)
      belief2 = BeliefPropagation.create_belief("content 2", :source, 0.9)
      
      belief_set1 = belief_set1
                    |> BeliefSet.add_belief(belief1)
                    |> BeliefSet.add_belief(belief2)
                    
      belief_set2 = belief_set2
                    |> BeliefSet.add_belief(belief1)
                    |> BeliefSet.add_belief(belief2)
      
      agent_belief_sets = %{
        :agent1 => belief_set1,
        :agent2 => belief_set2
      }
      
      # Verify consistency (should be good)
      result = ConsistencyManagement.verify_consistency(agent_belief_sets)
      
      assert result.consistent == true
      assert Enum.empty?(result.conflicts)
      assert result.alignment_score == 1.0
      assert result.partition_detected == false
      assert result.convergence_score == 1.0
      
      # Now create inconsistent belief sets
      belief_set3 = BeliefPropagation.create_belief_set(:agent3)
      conflict_belief = BeliefPropagation.create_belief(%{key: "status", value: "active"}, :agent3, 0.7)
      belief_set3 = BeliefSet.add_belief(belief_set3, conflict_belief)
      
      belief_set4 = BeliefPropagation.create_belief_set(:agent4)
      conflict_belief2 = BeliefPropagation.create_belief(%{key: "status", value: "inactive"}, :agent4, 0.8)
      belief_set4 = BeliefSet.add_belief(belief_set4, conflict_belief2)
      
      inconsistent_sets = %{
        :agent3 => belief_set3,
        :agent4 => belief_set4
      }
      
      # Verify consistency (should be bad)
      result2 = ConsistencyManagement.verify_consistency(inconsistent_sets)
      
      assert result2.consistent == false
      assert length(result2.conflicts) > 0
      assert is_list(result2.recommendations)
      assert length(result2.recommendations) > 0
    end
    
    test "verifies consistency of specific beliefs" do
      # Create agent belief sets
      agent1_set = BeliefPropagation.create_belief_set(:agent1)
      agent2_set = BeliefPropagation.create_belief_set(:agent2)
      agent3_set = BeliefPropagation.create_belief_set(:agent3)
      
      # Create a belief that will be consistent across agents
      consistent_belief = BeliefPropagation.create_belief("consistent content", :source, 0.8)
      
      # Create conflicting beliefs (same ID, different content)
      inconsistent_belief1 = BeliefPropagation.create_belief(%{key: "setting", value: "on"}, :agent1, 0.7)
      inconsistent_belief_id = inconsistent_belief1.id
      
      # Create a belief with same ID but different content
      inconsistent_belief2 = %{inconsistent_belief1 | content: %{key: "setting", value: "off"}}
      
      # Add beliefs to agents
      agent1_set = agent1_set
                   |> BeliefSet.add_belief(consistent_belief)
                   |> BeliefSet.add_belief(inconsistent_belief1)
                   
      agent2_set = agent2_set
                   |> BeliefSet.add_belief(consistent_belief)
                   |> BeliefSet.add_belief(inconsistent_belief2)
                   
      agent3_set = agent3_set
                   |> BeliefSet.add_belief(consistent_belief)
      
      agent_belief_sets = %{
        :agent1 => agent1_set,
        :agent2 => agent2_set,
        :agent3 => agent3_set
      }
      
      # Verify specific beliefs
      result = ConsistencyManagement.verify_belief_consistency(
        [consistent_belief.id, inconsistent_belief_id],
        agent_belief_sets
      )
      
      # Check result for consistent belief
      consistent_result = result[consistent_belief.id]
      assert consistent_result.present == true
      assert consistent_result.instances == 3
      assert consistent_result.content_consistent == true
      assert consistent_result.consistency_score == 1.0
      
      # Check result for inconsistent belief
      inconsistent_result = result[inconsistent_belief_id]
      assert inconsistent_result.present == true
      assert inconsistent_result.instances == 2
      assert inconsistent_result.content_consistent == false
      assert inconsistent_result.consistency_score < 1.0
    end
  end
end