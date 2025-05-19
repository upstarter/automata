defmodule Automata.DistributedCognition.EmergentSpecialization.SpecializationEmergenceTest do
  use ExUnit.Case, async: true
  
  alias Automata.DistributedCognition.EmergentSpecialization.SpecializationEmergence
  alias SpecializationEmergence.SpecializationPattern
  alias SpecializationEmergence.SpecializationDetection
  alias SpecializationEmergence.SpecializationReinforcement
  alias SpecializationEmergence.ComplementarySpecialization
  alias SpecializationEmergence.SystemAdaptation
  
  describe "SpecializationPattern" do
    test "creates a new specialization pattern" do
      id = "test_pattern"
      name = "Test Pattern"
      description = "A pattern for testing"
      core_capabilities = [:computation, :planning]
      
      pattern = SpecializationPattern.new(id, name, description, core_capabilities)
      
      assert pattern.id == id
      assert pattern.name == name
      assert pattern.description == description
      assert pattern.core_capabilities == core_capabilities
      assert pattern.related_roles == []  # Default
      assert pattern.exemplar_agents == []  # Default
      assert pattern.complementary_patterns == []  # Default
      assert pattern.emergence_score == 0.5  # Default
      assert pattern.stability == 0.5  # Default
    end
    
    test "creates a new specialization pattern with options" do
      id = "test_pattern"
      name = "Test Pattern"
      description = "A pattern for testing"
      core_capabilities = [:computation, :planning]
      
      related_roles = [:role1, :role2]
      exemplar_agents = [:agent1, :agent2]
      complementary_patterns = ["other_pattern"]
      
      pattern = SpecializationPattern.new(id, name, description, core_capabilities,
        related_roles: related_roles,
        exemplar_agents: exemplar_agents,
        complementary_patterns: complementary_patterns,
        emergence_score: 0.8,
        stability: 0.7
      )
      
      assert pattern.id == id
      assert pattern.name == name
      assert pattern.description == description
      assert pattern.core_capabilities == core_capabilities
      assert pattern.related_roles == related_roles
      assert pattern.exemplar_agents == exemplar_agents
      assert pattern.complementary_patterns == complementary_patterns
      assert pattern.emergence_score == 0.8
      assert pattern.stability == 0.7
    end
    
    test "updates a specialization pattern" do
      # Create a pattern
      pattern = SpecializationPattern.new(
        "test_pattern",
        "Test Pattern",
        "A pattern for testing",
        [:computation, :planning]
      )
      
      # Updates to apply
      updates = %{
        name: "Updated Pattern",
        emergence_score: 0.9,
        exemplar_agents: [:agent1, :agent3]
      }
      
      # Update the pattern
      updated_pattern = SpecializationPattern.update(pattern, updates)
      
      # Verify updates were applied
      assert updated_pattern.name == "Updated Pattern"
      assert updated_pattern.emergence_score == 0.9
      assert updated_pattern.exemplar_agents == [:agent1, :agent3]
      
      # Other fields should remain unchanged
      assert updated_pattern.id == pattern.id
      assert updated_pattern.description == pattern.description
      assert updated_pattern.core_capabilities == pattern.core_capabilities
    end
    
    test "merges two specialization patterns" do
      # Create two patterns
      pattern1 = SpecializationPattern.new(
        "pattern1",
        "Pattern 1",
        "First pattern",
        [:computation, :planning],
        related_roles: [:role1, :role2],
        exemplar_agents: [:agent1, :agent2],
        complementary_patterns: ["pattern3"],
        emergence_score: 0.7,
        stability: 0.8
      )
      
      pattern2 = SpecializationPattern.new(
        "pattern2",
        "Pattern 2",
        "Second pattern",
        [:planning, :communication],
        related_roles: [:role2, :role3],
        exemplar_agents: [:agent2, :agent3],
        complementary_patterns: ["pattern4"],
        emergence_score: 0.8,
        stability: 0.6
      )
      
      # Merge the patterns
      merged_pattern = SpecializationPattern.merge(pattern1, pattern2)
      
      # Verify merged pattern
      assert merged_pattern.id == "merged_pattern1_pattern2"
      assert merged_pattern.name == "Pattern 1 + Pattern 2"
      assert merged_pattern.core_capabilities == [:computation, :planning, :communication]
      assert merged_pattern.related_roles == [:role1, :role2, :role3]
      assert merged_pattern.exemplar_agents == [:agent1, :agent2, :agent3]
      assert merged_pattern.complementary_patterns == ["pattern3", "pattern4"]
      assert merged_pattern.emergence_score == 0.75  # Average
      assert merged_pattern.stability == 0.6  # Minimum
    end
    
    test "calculates similarity between two specialization patterns" do
      # Create two patterns with overlapping capabilities, roles, and agents
      pattern1 = SpecializationPattern.new(
        "pattern1",
        "Pattern 1",
        "First pattern",
        [:computation, :planning, :learning],
        related_roles: [:role1, :role2, :role3],
        exemplar_agents: [:agent1, :agent2, :agent3]
      )
      
      pattern2 = SpecializationPattern.new(
        "pattern2",
        "Pattern 2",
        "Second pattern",
        [:planning, :learning, :communication],
        related_roles: [:role2, :role3, :role4],
        exemplar_agents: [:agent2, :agent3, :agent4]
      )
      
      # Calculate similarity
      similarity = SpecializationPattern.similarity(pattern1, pattern2)
      
      # Expected similarity:
      # - Capabilities: Jaccard([:computation, :planning, :learning], [:planning, :learning, :communication]) = 2/4 = 0.5
      # - Roles: Jaccard([:role1, :role2, :role3], [:role2, :role3, :role4]) = 2/4 = 0.5
      # - Agents: Jaccard([:agent1, :agent2, :agent3], [:agent2, :agent3, :agent4]) = 2/4 = 0.5
      # - Weighted: 0.5 * 0.5 + 0.5 * 0.3 + 0.5 * 0.2 = 0.25 + 0.15 + 0.1 = 0.5
      assert_in_delta similarity, 0.5, 0.01
      
      # Test identical patterns
      assert SpecializationPattern.similarity(pattern1, pattern1) == 1.0
      
      # Test completely different patterns
      pattern3 = SpecializationPattern.new(
        "pattern3",
        "Pattern 3",
        "Third pattern",
        [:communication, :coordination],
        related_roles: [:role5, :role6],
        exemplar_agents: [:agent5, :agent6]
      )
      
      assert SpecializationPattern.similarity(pattern1, pattern3) == 0.0
    end
  end
  
  describe "SpecializationDetection" do
    # These tests verify the functionality of the SpecializationDetection module
    
    test "detect_from_capabilities exists" do
      assert function_exported?(SpecializationDetection, :detect_from_capabilities, 2)
    end
    
    test "detect_from_roles exists" do
      assert function_exported?(SpecializationDetection, :detect_from_roles, 3)
    end
    
    test "detect_from_behaviors exists" do
      assert function_exported?(SpecializationDetection, :detect_from_behaviors, 2)
    end
    
    test "comprehensive_detection exists" do
      assert function_exported?(SpecializationDetection, :comprehensive_detection, 2)
    end
  end
  
  describe "SpecializationReinforcement" do
    # These tests verify the functionality of the SpecializationReinforcement module
    
    test "apply_selective_pressure exists" do
      assert function_exported?(SpecializationReinforcement, :apply_selective_pressure, 3)
    end
    
    test "incremental_reinforcement exists" do
      assert function_exported?(SpecializationReinforcement, :incremental_reinforcement, 4)
    end
    
    test "create_roles_from_patterns exists" do
      assert function_exported?(SpecializationReinforcement, :create_roles_from_patterns, 2)
    end
    
    test "reinforce_through_beliefs exists" do
      assert function_exported?(SpecializationReinforcement, :reinforce_through_beliefs, 2)
    end
  end
  
  describe "ComplementarySpecialization" do
    # These tests verify the functionality of the ComplementarySpecialization module
    
    test "identify_complementary_patterns exists" do
      assert function_exported?(ComplementarySpecialization, :identify_complementary_patterns, 1)
    end
    
    test "promote_complementary_development exists" do
      assert function_exported?(ComplementarySpecialization, :promote_complementary_development, 2)
    end
    
    test "ensure_specialization_diversity exists" do
      assert function_exported?(ComplementarySpecialization, :ensure_specialization_diversity, 3)
    end
    
    test "coordinate_coalition_specialization exists" do
      assert function_exported?(ComplementarySpecialization, :coordinate_coalition_specialization, 2)
    end
  end
  
  describe "SystemAdaptation" do
    # These tests verify the functionality of the SystemAdaptation module
    
    test "adapt_organization exists" do
      assert function_exported?(SystemAdaptation, :adapt_organization, 2)
    end
    
    test "adjust_resource_allocation exists" do
      assert function_exported?(SystemAdaptation, :adjust_resource_allocation, 2)
    end
    
    test "create_supporting_components exists" do
      assert function_exported?(SystemAdaptation, :create_supporting_components, 1)
    end
    
    test "evolve_communication_pathways exists" do
      assert function_exported?(SystemAdaptation, :evolve_communication_pathways, 2)
    end
  end
end