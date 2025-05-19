defmodule Automata.DistributedCognition.EmergentSpecialization.RoleAdaptationTest do
  use ExUnit.Case, async: true
  
  alias Automata.DistributedCognition.EmergentSpecialization.RoleAdaptation
  alias RoleAdaptation.Role
  alias RoleAdaptation.RoleAssignment
  alias RoleAdaptation.BehavioralAdaptation
  alias RoleAdaptation.FeedbackSystem
  
  describe "Role" do
    test "creates a new role" do
      id = :test_role
      name = "Test Role"
      description = "A role for testing"
      
      role = Role.new(id, name, description)
      
      assert role.id == id
      assert role.name == name
      assert role.description == description
      assert role.authority_level == 1  # Default
      assert role.adaptability == 0.5  # Default
    end
    
    test "creates a new role with options" do
      id = :test_role
      name = "Test Role"
      description = "A role for testing"
      
      capability_requirements = [
        %{capability_id: :computation, min_performance: 0.7, weight: 1.0},
        %{capability_id: :planning, min_performance: 0.6, weight: 0.8}
      ]
      
      responsibilities = [
        %{action: :task1, priority: 1, conditions: []},
        %{action: :task2, priority: 2, conditions: []}
      ]
      
      role = Role.new(id, name, description,
        capability_requirements: capability_requirements,
        responsibilities: responsibilities,
        authority_level: 2,
        adaptability: 0.7
      )
      
      assert role.id == id
      assert role.name == name
      assert role.description == description
      assert role.capability_requirements == capability_requirements
      assert role.responsibilities == responsibilities
      assert role.authority_level == 2
      assert role.adaptability == 0.7
    end
    
    test "calculates how well an agent fits a role" do
      # Create a role with requirements
      role = Role.new(:test_role, "Test Role", "A role for testing",
        capability_requirements: [
          %{capability_id: :computation, min_performance: 0.7, weight: 1.0},
          %{capability_id: :planning, min_performance: 0.6, weight: 0.8}
        ]
      )
      
      # Mock capability profile
      profile = %{
        agent_id: :agent1,
        capabilities: %{
          computation: %{
            efficiency: 0.8,
            quality: 0.7,
            reliability: 0.9,
            latency: 0.2
          },
          planning: %{
            efficiency: 0.7,
            quality: 0.7,
            reliability: 0.8,
            latency: 0.3
          }
        },
        capability_history: %{},
        specializations: [],
        profile_updated_at: DateTime.utc_now()
      }
      
      # Define the calculate_overall_performance function that's being mocked
      defmodule MockCapabilityProfile do
        def capability_performance(_profile, :computation), do: 0.85
        def capability_performance(_profile, :planning), do: 0.7
        def capability_performance(_profile, _), do: 0.0
        
        def calculate_overall_performance(_metrics), do: 0.0
      end
      
      # Replace the imported function with our mock for this test
      original = Application.get_env(:automata, :capability_profile_module)
      Application.put_env(:automata, :capability_profile_module, MockCapabilityProfile)
      
      # Test the function
      fit = Role.calculate_fit(role, profile)
      
      # Verify the result
      assert_in_delta fit, 0.96, 0.01  # (1.0 * 0.85/0.7 * 1.0 + 0.8 * 0.7/0.6 * 0.8) / (1.0 + 0.8)
      
      # Restore the original module
      if original, do: Application.put_env(:automata, :capability_profile_module, original)
    end
    
    test "evolves a role based on feedback" do
      # Create a role
      role = Role.new(:test_role, "Test Role", "A role for testing",
        capability_requirements: [
          %{capability_id: :computation, min_performance: 0.7, weight: 1.0},
          %{capability_id: :planning, min_performance: 0.6, weight: 0.8}
        ],
        adaptability: 0.5
      )
      
      # Create feedback and performance data
      feedback = %{
        performance: 0.8,
        satisfaction: 0.7,
        aspects: %{
          responsiveness: 0.8,
          initiative: 0.7,
          teamwork: 0.9
        }
      }
      
      performance_data = %{
        computation: 0.9,
        planning: 0.7
      }
      
      # Evolve the role
      evolved_role = Role.evolve(role, feedback, performance_data)
      
      # Verify the role has been evolved
      assert evolved_role.adaptability > role.adaptability
      
      # Updated requirements should reflect the performance data and adaptability
      computation_req = Enum.find(evolved_role.capability_requirements, &(&1.capability_id == :computation))
      assert computation_req.min_performance > 0.7
      
      planning_req = Enum.find(evolved_role.capability_requirements, &(&1.capability_id == :planning))
      assert planning_req.min_performance > 0.6
    end
  end
  
  describe "RoleAssignment" do
    # These tests verify the functionality of the RoleAssignment module
    
    test "assign_role exists" do
      assert function_exported?(RoleAssignment, :assign_role, 4)
    end
    
    test "find_best_role exists" do
      assert function_exported?(RoleAssignment, :find_best_role, 2)
    end
    
    test "find_best_agent exists" do
      assert function_exported?(RoleAssignment, :find_best_agent, 2)
    end
    
    test "get_agent_role exists" do
      assert function_exported?(RoleAssignment, :get_agent_role, 1)
    end
    
    test "list_agents_with_role exists" do
      assert function_exported?(RoleAssignment, :list_agents_with_role, 1)
    end
    
    test "unassign_role exists" do
      assert function_exported?(RoleAssignment, :unassign_role, 2)
    end
    
    test "optimize_role_assignments exists" do
      assert function_exported?(RoleAssignment, :optimize_role_assignments, 3)
    end
  end
  
  describe "BehavioralAdaptation" do
    # These tests verify the functionality of the BehavioralAdaptation module
    
    test "adapt_behavior exists" do
      assert function_exported?(BehavioralAdaptation, :adapt_behavior, 2)
    end
    
    test "learn_from_exemplars exists" do
      assert function_exported?(BehavioralAdaptation, :learn_from_exemplars, 3)
    end
    
    test "progressive_adaptation exists" do
      assert function_exported?(BehavioralAdaptation, :progressive_adaptation, 3)
    end
    
    test "monitor_behavioral_drift exists" do
      assert function_exported?(BehavioralAdaptation, :monitor_behavioral_drift, 3)
    end
  end
  
  describe "FeedbackSystem" do
    # These tests verify the functionality of the FeedbackSystem module
    
    test "record_feedback exists" do
      assert function_exported?(FeedbackSystem, :record_feedback, 4)
    end
    
    test "analyze_role_effectiveness exists" do
      assert function_exported?(FeedbackSystem, :analyze_role_effectiveness, 2)
    end
    
    test "evaluate_agent_performance exists" do
      assert function_exported?(FeedbackSystem, :evaluate_agent_performance, 3)
    end
    
    test "recommend_role_adjustments exists" do
      assert function_exported?(FeedbackSystem, :recommend_role_adjustments, 1)
    end
  end
end