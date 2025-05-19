defmodule DistributedCognition.BeliefPropagationTest do
  use ExUnit.Case, async: true
  
  alias Automata.DistributedCognition.BeliefArchitecture.BeliefPropagation
  alias Automata.DistributedCognition.BeliefArchitecture.BeliefPropagation.{BeliefAtom, BeliefSet}

  describe "BeliefAtom" do
    test "creates a new belief atom" do
      content = %{fact: "The sky is blue"}
      source = :agent1
      confidence = 0.8
      
      belief = BeliefPropagation.create_belief(content, source, confidence)
      
      assert belief.content == content
      assert belief.source == source
      assert belief.confidence == confidence
      assert is_binary(belief.id)
      assert %DateTime{} = belief.timestamp
      assert is_map(belief.metadata)
      assert is_list(belief.tags)
    end
    
    test "updates belief confidence" do
      belief = BeliefPropagation.create_belief("test content", :test, 0.5)
      updated = BeliefAtom.update_confidence(belief, 0.9)
      
      assert updated.confidence == 0.9
      assert DateTime.compare(updated.timestamp, belief.timestamp) in [:gt, :eq]
    end
    
    test "adds metadata to belief" do
      belief = BeliefPropagation.create_belief("test content", :test, 0.5)
      new_metadata = %{source_reliability: 0.9, origin: "sensor_1"}
      updated = BeliefAtom.add_metadata(belief, new_metadata)
      
      assert Map.get(updated.metadata, :source_reliability) == 0.9
      assert Map.get(updated.metadata, :origin) == "sensor_1"
    end
    
    test "adds tags to belief" do
      belief = BeliefPropagation.create_belief("test content", :test, 0.5)
      new_tags = [:important, :verified]
      updated = BeliefAtom.add_tags(belief, new_tags)
      
      assert :important in updated.tags
      assert :verified in updated.tags
    end
  end
  
  describe "BeliefSet" do
    test "creates a new belief set" do
      agent_id = :agent1
      belief_set = BeliefPropagation.create_belief_set(agent_id)
      
      assert belief_set.agent_id == agent_id
      assert belief_set.beliefs == %{}
      assert %DateTime{} = belief_set.last_updated
    end
    
    test "adds a belief to the set" do
      belief_set = BeliefPropagation.create_belief_set(:agent1)
      belief = BeliefPropagation.create_belief("test content", :agent1, 0.8)
      
      updated_set = BeliefPropagation.add_belief(belief_set, belief)
      
      assert Map.has_key?(updated_set.beliefs, belief.id)
      assert BeliefSet.get_belief(updated_set, belief.id) == belief
    end
    
    test "removes a belief from the set" do
      belief_set = BeliefPropagation.create_belief_set(:agent1)
      belief = BeliefPropagation.create_belief("test content", :agent1, 0.8)
      
      updated_set = BeliefSet.add_belief(belief_set, belief)
      removal_set = BeliefSet.remove_belief(updated_set, belief.id)
      
      refute Map.has_key?(removal_set.beliefs, belief.id)
    end
    
    test "updates a belief in the set" do
      belief_set = BeliefPropagation.create_belief_set(:agent1)
      belief = BeliefPropagation.create_belief("test content", :agent1, 0.8)
      
      # Add the belief
      updated_set = BeliefSet.add_belief(belief_set, belief)
      
      # Update the belief
      updated_belief = BeliefAtom.update_confidence(belief, 0.9)
      final_set = BeliefSet.update_belief(updated_set, updated_belief)
      
      retrieved = BeliefSet.get_belief(final_set, belief.id)
      assert retrieved.confidence == 0.9
    end
    
    test "filters beliefs by predicate" do
      belief_set = BeliefPropagation.create_belief_set(:agent1)
      
      # Add multiple beliefs
      belief1 = BeliefPropagation.create_belief("content 1", :agent1, 0.7)
      belief2 = BeliefPropagation.create_belief("content 2", :agent1, 0.3)
      belief3 = BeliefPropagation.create_belief("content 3", :agent1, 0.9)
      
      belief_set = belief_set 
                   |> BeliefSet.add_belief(belief1)
                   |> BeliefSet.add_belief(belief2)
                   |> BeliefSet.add_belief(belief3)
      
      # Filter beliefs with confidence > 0.5
      filtered = BeliefSet.filter_beliefs(belief_set, fn belief -> belief.confidence > 0.5 end)
      
      assert length(filtered) == 2
      assert Enum.any?(filtered, fn b -> b.id == belief1.id end)
      assert Enum.any?(filtered, fn b -> b.id == belief3.id end)
      refute Enum.any?(filtered, fn b -> b.id == belief2.id end)
    end
    
    test "finds conflicts between beliefs" do
      belief_set = BeliefPropagation.create_belief_set(:agent1)
      
      # Add potentially conflicting beliefs
      belief1 = BeliefPropagation.create_belief(%{status: "door", value: "open"}, :agent1, 0.7)
      belief2 = BeliefPropagation.create_belief(%{status: "door", value: "closed"}, :agent2, 0.8)
      
      belief_set = belief_set 
                   |> BeliefSet.add_belief(belief1)
                   |> BeliefSet.add_belief(belief2)
      
      conflicts = BeliefSet.find_conflicts(belief_set)
      
      assert length(conflicts) == 1
      {conflict1, conflict2} = hd(conflicts)
      assert conflict1.id == belief1.id or conflict1.id == belief2.id
      assert conflict2.id == belief1.id or conflict2.id == belief2.id
      assert conflict1.id != conflict2.id
    end
    
    test "merges two belief sets" do
      belief_set1 = BeliefPropagation.create_belief_set(:agent1)
      belief_set2 = BeliefPropagation.create_belief_set(:agent2)
      
      # Add different beliefs to each set
      belief1 = BeliefPropagation.create_belief("content 1", :agent1, 0.7)
      belief2 = BeliefPropagation.create_belief("content 2", :agent2, 0.8)
      
      belief_set1 = BeliefSet.add_belief(belief_set1, belief1)
      belief_set2 = BeliefSet.add_belief(belief_set2, belief2)
      
      # Merge the sets
      merged = BeliefSet.merge(belief_set1, belief_set2)
      
      assert map_size(merged.beliefs) == 2
      assert BeliefSet.get_belief(merged, belief1.id) != nil
      assert BeliefSet.get_belief(merged, belief2.id) != nil
    end
    
    test "calculates consistency score" do
      belief_set = BeliefPropagation.create_belief_set(:agent1)
      
      # Add non-conflicting beliefs
      belief1 = BeliefPropagation.create_belief("content 1", :agent1, 0.7)
      belief2 = BeliefPropagation.create_belief("content 2", :agent2, 0.8)
      
      consistent_set = belief_set 
                       |> BeliefSet.add_belief(belief1)
                       |> BeliefSet.add_belief(belief2)
      
      score1 = BeliefSet.consistency_score(consistent_set)
      assert score1 == 1.0
      
      # Add conflicting beliefs
      belief3 = BeliefPropagation.create_belief(%{status: "door", value: "open"}, :agent1, 0.7)
      belief4 = BeliefPropagation.create_belief(%{status: "door", value: "closed"}, :agent2, 0.8)
      
      conflicting_set = consistent_set 
                        |> BeliefSet.add_belief(belief3)
                        |> BeliefSet.add_belief(belief4)
      
      score2 = BeliefSet.consistency_score(conflicting_set)
      assert score2 < 1.0
    end
  end
  
  describe "AsyncUpdates" do
    test "processes belief update (acceptance case)" do
      belief_set = BeliefPropagation.create_belief_set(:agent1)
      belief = BeliefPropagation.create_belief("test content", :agent2, 0.8)
      
      {updated_set, status} = BeliefPropagation.process_belief_update(belief, belief_set)
      
      assert status == :accepted
      assert BeliefSet.get_belief(updated_set, belief.id) != nil
    end
    
    test "processes belief update (rejection case - low confidence)" do
      belief_set = BeliefPropagation.create_belief_set(:agent1)
      belief = BeliefPropagation.create_belief("test content", :agent2, 0.2)
      
      {updated_set, status} = BeliefPropagation.process_belief_update(
        belief, 
        belief_set, 
        [acceptance_threshold: 0.5]
      )
      
      assert status == :rejected
      assert BeliefSet.get_belief(updated_set, belief.id) == nil
    end
    
    test "synchronizes belief sets between agents" do
      belief_set1 = BeliefPropagation.create_belief_set(:agent1)
      belief_set2 = BeliefPropagation.create_belief_set(:agent2)
      
      # Add different beliefs to each set
      belief1 = BeliefPropagation.create_belief("content 1", :agent1, 0.7)
      belief2 = BeliefPropagation.create_belief("content 2", :agent2, 0.8)
      
      belief_set1 = BeliefSet.add_belief(belief_set1, belief1)
      belief_set2 = BeliefSet.add_belief(belief_set2, belief2)
      
      # Synchronize the belief sets
      {updated_set1, updated_set2} = BeliefPropagation.synchronize_beliefs(belief_set1, belief_set2)
      
      # Both sets should now have both beliefs
      assert BeliefSet.get_belief(updated_set1, belief1.id) != nil
      assert BeliefSet.get_belief(updated_set1, belief2.id) != nil
      assert BeliefSet.get_belief(updated_set2, belief1.id) != nil
      assert BeliefSet.get_belief(updated_set2, belief2.id) != nil
    end
    
    test "verifies convergence across belief sets" do
      # Create identical belief sets (converged)
      belief_set1 = BeliefPropagation.create_belief_set(:agent1)
      belief_set2 = BeliefPropagation.create_belief_set(:agent2)
      
      belief = BeliefPropagation.create_belief("shared content", :shared, 0.9)
      
      belief_set1 = BeliefSet.add_belief(belief_set1, belief)
      belief_set2 = BeliefSet.add_belief(belief_set2, belief)
      
      {converged, score} = BeliefPropagation.verify_convergence([belief_set1, belief_set2])
      
      assert converged
      assert score == 1.0
      
      # Create non-converged belief sets
      belief_set3 = BeliefPropagation.create_belief_set(:agent3)
      belief_set3 = BeliefSet.add_belief(belief_set3, 
        BeliefPropagation.create_belief("unique content", :agent3, 0.8)
      )
      
      {converged2, score2} = BeliefPropagation.verify_convergence([belief_set1, belief_set2, belief_set3])
      
      refute converged2
      assert score2 < 1.0
    end
  end
  
  describe "ConflictResolution" do
    test "detects conflicts between beliefs" do
      belief1 = BeliefPropagation.create_belief(%{status: "door", value: "open"}, :agent1, 0.7)
      belief2 = BeliefPropagation.create_belief(%{status: "door", value: "closed"}, :agent2, 0.8)
      
      # These should conflict (same structure, different values)
      assert BeliefPropagation.ConflictResolution.are_conflicting(belief1, belief2)
      
      # Non-conflicting beliefs
      belief3 = BeliefPropagation.create_belief("totally different", :agent3, 0.9)
      refute BeliefPropagation.ConflictResolution.are_conflicting(belief1, belief3)
    end
    
    test "resolves conflicts using highest confidence strategy" do
      belief1 = BeliefPropagation.create_belief(%{status: "door", value: "open"}, :agent1, 0.7)
      belief2 = BeliefPropagation.create_belief(%{status: "door", value: "closed"}, :agent2, 0.8)
      
      resolved = BeliefPropagation.resolve_conflict(belief1, belief2, :highest_confidence)
      
      # Should select belief2 as it has higher confidence
      assert resolved.content.value == "closed"
    end
    
    test "resolves conflicts using newest strategy" do
      # Create older belief
      belief1 = BeliefPropagation.create_belief(%{status: "door", value: "open"}, :agent1, 0.9)
      
      # Create newer belief with artificially later timestamp
      :timer.sleep(5)  # Ensure timestamp difference
      belief2 = BeliefPropagation.create_belief(%{status: "door", value: "closed"}, :agent2, 0.7)
      
      resolved = BeliefPropagation.resolve_conflict(belief1, belief2, :newest)
      
      # Should select belief2 as it's newer
      assert resolved.content.value == "closed"
    end
    
    test "resolves all conflicts in a belief set" do
      belief_set = BeliefPropagation.create_belief_set(:test)
      
      # Add conflicting beliefs
      belief1 = BeliefPropagation.create_belief(%{status: "door", value: "open"}, :agent1, 0.7)
      belief2 = BeliefPropagation.create_belief(%{status: "door", value: "closed"}, :agent2, 0.8)
      belief3 = BeliefPropagation.create_belief(%{status: "window", value: "open"}, :agent1, 0.7)
      belief4 = BeliefPropagation.create_belief(%{status: "window", value: "closed"}, :agent2, 0.6)
      
      belief_set = belief_set 
                   |> BeliefSet.add_belief(belief1)
                   |> BeliefSet.add_belief(belief2)
                   |> BeliefSet.add_belief(belief3)
                   |> BeliefSet.add_belief(belief4)
      
      # Verify conflicts exist
      conflicts = BeliefSet.find_conflicts(belief_set)
      assert length(conflicts) > 0
      
      # Resolve all conflicts
      resolved_set = BeliefPropagation.resolve_all_conflicts(belief_set, :highest_confidence)
      
      # Verify no conflicts remain
      new_conflicts = BeliefSet.find_conflicts(resolved_set)
      assert Enum.empty?(new_conflicts)
    end
  end
  
  describe "UncertaintyRepresentation" do
    test "creates an uncertain belief with probabilistic representation" do
      content = "The room is occupied"
      source = :motion_sensor
      uncertainty_type = :probabilistic
      uncertainty_values = %{probability: 0.85}
      
      belief = BeliefPropagation.create_uncertain_belief(
        content, 
        source, 
        uncertainty_type, 
        uncertainty_values
      )
      
      assert belief.content == content
      assert belief.source == source
      assert belief.confidence == 0.85
      assert get_in(belief.metadata, [:uncertainty_type]) == :probabilistic
      assert get_in(belief.metadata, [:uncertainty_values]) == uncertainty_values
    end
    
    test "updates uncertainty values for a belief" do
      belief = BeliefPropagation.create_uncertain_belief(
        "Room is occupied",
        :sensor,
        :probabilistic,
        %{probability: 0.7}
      )
      
      # Update uncertainty
      updated = BeliefPropagation.UncertaintyRepresentation.update_uncertainty(
        belief,
        %{probability: 0.9}
      )
      
      assert updated.confidence == 0.9
      assert get_in(updated.metadata, [:uncertainty_values, :probability]) == 0.9
    end
    
    test "aggregates multiple uncertain beliefs using weighted average" do
      belief1 = BeliefPropagation.create_uncertain_belief(
        "Temperature is high",
        :sensor1,
        :probabilistic,
        %{probability: 0.8}
      )
      
      belief2 = BeliefPropagation.create_uncertain_belief(
        "Temperature is high",
        :sensor2,
        :probabilistic,
        %{probability: 0.6}
      )
      
      aggregated = BeliefPropagation.aggregate_beliefs([belief1, belief2], :weighted_average)
      
      # Since belief1 has higher confidence, it should influence the result more
      assert aggregated.confidence > 0.7
      assert aggregated.confidence < 0.8
    end
    
    test "checks if two beliefs agree with each other" do
      belief1 = BeliefPropagation.create_uncertain_belief(
        "Room status",
        :sensor1,
        :probabilistic,
        %{probability: 0.8}
      )
      
      belief2 = BeliefPropagation.create_uncertain_belief(
        "Room status",
        :sensor2,
        :probabilistic,
        %{probability: 0.75}
      )
      
      belief3 = BeliefPropagation.create_uncertain_belief(
        "Room status",
        :sensor3,
        :probabilistic,
        %{probability: 0.2}
      )
      
      # These two beliefs should agree (both high probability)
      assert BeliefPropagation.beliefs_agree?(belief1, belief2)
      
      # These two should disagree (high vs low probability)
      refute BeliefPropagation.beliefs_agree?(belief1, belief3)
    end
  end
end