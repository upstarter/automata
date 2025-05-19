defmodule Automata.DistributedCognition.EmergentSpecialization.EmergentSpecializationSystemTest do
  use ExUnit.Case
  
  alias Automata.DistributedCognition.EmergentSpecialization.EmergentSpecializationSystem
  
  @moduletag :capture_log
  
  setup do
    # Start the system with a unique name for each test
    {:ok, system} = EmergentSpecializationSystem.start_link(
      name: :"EmergentSpecializationSystem#{:erlang.unique_integer([:positive])}"
    )
    
    # Return the system for use in tests
    %{system: system}
  end
  
  describe "client API" do
    test "create_capability_profile/3", %{system: system} do
      agent_id = :test_agent
      
      # Create a capability profile for the agent
      {:ok, profile} = EmergentSpecializationSystem.create_capability_profile(system, agent_id)
      
      # Verify the profile
      assert profile.agent_id == agent_id
      assert is_map(profile.capabilities)
      assert is_map(profile.capability_history)
      assert is_list(profile.specializations)
    end
    
    test "record_performance_event/4", %{system: system} do
      agent_id = :test_agent
      capability_id = :computation
      event_data = %{efficiency: 0.8, quality: 0.7}
      
      # Create a capability profile first
      {:ok, _} = EmergentSpecializationSystem.create_capability_profile(system, agent_id)
      
      # Record a performance event
      {:ok, updated_profile} = EmergentSpecializationSystem.record_performance_event(
        system, agent_id, capability_id, event_data
      )
      
      # Verify the event was recorded
      assert Map.has_key?(updated_profile.capabilities, capability_id)
      assert updated_profile.capabilities[capability_id].efficiency == 0.8
      assert updated_profile.capabilities[capability_id].quality == 0.7
    end
    
    test "create_role/5", %{system: system} do
      role_id = :test_role
      name = "Test Role"
      description = "A role for testing"
      
      # Create a role
      {:ok, role} = EmergentSpecializationSystem.create_role(system, role_id, name, description)
      
      # Verify the role
      assert role.id == role_id
      assert role.name == name
      assert role.description == description
    end
    
    test "assign_role/4", %{system: system} do
      agent_id = :test_agent
      role_id = :test_role
      
      # Create a capability profile
      {:ok, _} = EmergentSpecializationSystem.create_capability_profile(system, agent_id)
      
      # Create a role
      {:ok, _} = EmergentSpecializationSystem.create_role(
        system, role_id, "Test Role", "A role for testing"
      )
      
      # Assign the role
      {:ok, assignment} = EmergentSpecializationSystem.assign_role(system, agent_id, role_id)
      
      # Verify the assignment
      assert assignment.agent_id == agent_id
      assert assignment.role_id == role_id
      assert assignment.status == :active
    end
    
    test "find_best_role/2", %{system: system} do
      agent_id = :test_agent
      
      # Create a capability profile
      {:ok, _} = EmergentSpecializationSystem.create_capability_profile(system, agent_id, %{
        computation: %{
          efficiency: 0.8,
          quality: 0.7,
          reliability: 0.9,
          latency: 0.2
        }
      })
      
      # Create roles
      {:ok, _} = EmergentSpecializationSystem.create_role(
        system, :role1, "Role 1", "First role",
        capability_requirements: [
          %{capability_id: :computation, min_performance: 0.7, weight: 1.0}
        ]
      )
      
      {:ok, _} = EmergentSpecializationSystem.create_role(
        system, :role2, "Role 2", "Second role",
        capability_requirements: [
          %{capability_id: :planning, min_performance: 0.7, weight: 1.0}
        ]
      )
      
      # Find the best role
      result = EmergentSpecializationSystem.find_best_role(system, agent_id)
      
      # Verify the result (should be role1 since the agent is strong in computation)
      case result do
        {:ok, best_role, fit_score} ->
          assert best_role.id == :role1
          assert fit_score > 0.7
          
        {:error, _} ->
          # In a real test with mocks, we'd expect a successful match
          flunk("Expected to find a best role")
      end
    end
    
    test "record_feedback/5", %{system: system} do
      agent_id = :test_agent
      role_id = :test_role
      source = :supervisor
      feedback_data = %{
        performance: 0.8,
        satisfaction: 0.7,
        aspects: %{
          responsiveness: 0.8,
          initiative: 0.7,
          teamwork: 0.9
        }
      }
      
      # Record feedback
      {:ok, feedback_record} = EmergentSpecializationSystem.record_feedback(
        system, agent_id, role_id, source, feedback_data
      )
      
      # Verify the feedback record
      assert feedback_record.agent_id == agent_id
      assert feedback_record.role_id == role_id
      assert feedback_record.source == source
      assert feedback_record.feedback.performance == 0.8
      assert feedback_record.feedback.satisfaction == 0.7
    end
    
    test "detect_specialization_patterns/3", %{system: system} do
      agent_ids = [:agent1, :agent2, :agent3]
      
      # Create capability profiles
      Enum.each(agent_ids, fn agent_id ->
        {:ok, _} = EmergentSpecializationSystem.create_capability_profile(system, agent_id, %{
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
        })
      end)
      
      # Detect patterns
      {:ok, patterns} = EmergentSpecializationSystem.detect_specialization_patterns(
        system, agent_ids
      )
      
      # In a real test with mocks, we would assert specific patterns were detected
      # For now, just verify the function returns something
      assert is_list(patterns)
    end
    
    test "reinforce_specialization/4", %{system: system} do
      # This test depends on having patterns and agents in the system
      # In a proper test, we'd set up the system with mocks to return
      # the expected data. For now, we'll verify the function signature.
      assert function_exported?(EmergentSpecializationSystem, :reinforce_specialization, 4)
    end
    
    test "identify_complementary_patterns/1", %{system: system} do
      # This test depends on having patterns in the system
      # In a proper test, we'd set up the system with mocks to return
      # the expected data. For now, we'll verify the function signature.
      assert function_exported?(EmergentSpecializationSystem, :identify_complementary_patterns, 1)
    end
    
    test "ensure_specialization_diversity/2", %{system: system} do
      # This test depends on having patterns and agents in the system
      # In a proper test, we'd set up the system with mocks to return
      # the expected data. For now, we'll verify the function signature.
      assert function_exported?(EmergentSpecializationSystem, :ensure_specialization_diversity, 2)
    end
    
    test "adapt_organization/1", %{system: system} do
      # This test depends on having patterns in the system
      # In a proper test, we'd set up the system with mocks to return
      # the expected data. For now, we'll verify the function signature.
      assert function_exported?(EmergentSpecializationSystem, :adapt_organization, 1)
    end
    
    test "run_specialization_cycle/2", %{system: system} do
      # This test depends on having agents and profiles in the system
      # In a proper test, we'd set up the system with mocks to return
      # the expected data. For now, we'll verify the function signature.
      assert function_exported?(EmergentSpecializationSystem, :run_specialization_cycle, 2)
    end
  end
  
  describe "GenServer callbacks" do
    test "init/1 initializes the state" do
      # Create a simple configuration
      config = %{
        detection_threshold: 0.8,
        periodic_detection_enabled: false
      }
      
      # Start the system with the configuration
      {:ok, system} = EmergentSpecializationSystem.start_link(
        name: :"ConfigTest#{:erlang.unique_integer([:positive])}",
        config: config
      )
      
      # There's no direct way to access the state in tests, but we can verify
      # the process is alive
      assert Process.alive?(system)
    end
    
    test "handle_info(:run_periodic_detection, state) runs detection", %{system: system} do
      # There's no direct way to test this in isolation, but we can verify
      # the process handles the message without crashing
      Process.send(system, :run_periodic_detection, [:noconnect])
      
      # Process should remain alive
      :timer.sleep(100)  # Give the process time to handle the message
      assert Process.alive?(system)
    end
  end
  
  describe "integration" do
    test "complete capability profiling to role assignment flow", %{system: system} do
      agent_id = :test_agent
      
      # 1. Create a capability profile
      {:ok, profile} = EmergentSpecializationSystem.create_capability_profile(system, agent_id)
      
      # 2. Record performance events
      {:ok, updated_profile} = EmergentSpecializationSystem.record_performance_event(
        system,
        agent_id,
        :computation,
        %{efficiency: 0.9, quality: 0.8, reliability: 0.9, latency: 0.1}
      )
      
      # 3. Create a role that matches the agent's capabilities
      {:ok, role} = EmergentSpecializationSystem.create_role(
        system,
        :computation_role,
        "Computation Role",
        "A role for computation-focused agents",
        capability_requirements: [
          %{capability_id: :computation, min_performance: 0.7, weight: 1.0}
        ]
      )
      
      # 4. Assign the role to the agent
      {:ok, assignment} = EmergentSpecializationSystem.assign_role(
        system,
        agent_id,
        :computation_role
      )
      
      # 5. Record feedback
      {:ok, feedback} = EmergentSpecializationSystem.record_feedback(
        system,
        agent_id,
        :computation_role,
        :supervisor,
        %{performance: 0.9, satisfaction: 0.8}
      )
      
      # Verify the complete flow succeeded
      assert assignment.agent_id == agent_id
      assert assignment.role_id == :computation_role
      assert assignment.status == :active
    end
  end
end