defmodule Automata.DistributedCognition.EmergentSpecialization.CapabilityProfilingTest do
  use ExUnit.Case, async: true
  
  alias Automata.DistributedCognition.EmergentSpecialization.CapabilityProfiling
  alias CapabilityProfiling.CapabilityProfile
  alias CapabilityProfiling.CapabilityDiscovery
  alias CapabilityProfiling.PerformanceMonitoring
  alias CapabilityProfiling.ComparativeEvaluation
  
  describe "CapabilityProfile" do
    test "creates a new capability profile" do
      agent_id = :agent1
      
      profile = CapabilityProfile.new(agent_id)
      
      assert profile.agent_id == agent_id
      assert is_map(profile.capabilities)
      assert is_map(profile.capability_history)
      assert is_list(profile.specializations)
    end
    
    test "creates a new capability profile with initial capabilities" do
      agent_id = :agent1
      initial_capabilities = %{
        computation: %{
          efficiency: 0.8,
          quality: 0.7,
          reliability: 0.9,
          latency: 0.2
        }
      }
      
      profile = CapabilityProfile.new(agent_id, initial_capabilities)
      
      assert profile.agent_id == agent_id
      assert profile.capabilities == initial_capabilities
      assert Map.has_key?(profile.capability_history, :computation)
      assert is_list(profile.specializations)
    end
    
    test "updates a capability's performance metrics" do
      agent_id = :agent1
      initial_capabilities = %{
        computation: %{
          efficiency: 0.8,
          quality: 0.7,
          reliability: 0.9,
          latency: 0.2
        }
      }
      
      profile = CapabilityProfile.new(agent_id, initial_capabilities)
      
      # Update computation capability
      new_metrics = %{
        efficiency: 0.9,
        quality: 0.8
      }
      
      updated_profile = CapabilityProfile.update_capability(profile, :computation, new_metrics)
      
      # The updated values should be merged with existing ones
      assert updated_profile.capabilities.computation.efficiency == 0.9
      assert updated_profile.capabilities.computation.quality == 0.8
      assert updated_profile.capabilities.computation.reliability == 0.9
      assert updated_profile.capabilities.computation.latency == 0.2
      
      # History should be updated
      assert length(updated_profile.capability_history.computation) == 2
    end
    
    test "identifies specializations based on capability performance" do
      agent_id = :agent1
      initial_capabilities = %{
        computation: %{
          efficiency: 0.9,
          quality: 0.8,
          reliability: 0.9,
          latency: 0.1
        },
        planning: %{
          efficiency: 0.7,
          quality: 0.7,
          reliability: 0.8,
          latency: 0.3
        },
        communication: %{
          efficiency: 0.5,
          quality: 0.6,
          reliability: 0.7,
          latency: 0.4
        }
      }
      
      profile = CapabilityProfile.new(agent_id, initial_capabilities)
      
      # Identify specializations with default threshold (0.8)
      updated_profile = CapabilityProfile.identify_specializations(profile)
      
      # Only computation should be identified as a specialization
      assert :computation in updated_profile.specializations
      assert :planning not in updated_profile.specializations
      assert :communication not in updated_profile.specializations
      
      # Identify specializations with lower threshold (0.7)
      updated_profile_lower = CapabilityProfile.identify_specializations(profile, 0.7)
      
      # Both computation and planning should be identified as specializations
      assert :computation in updated_profile_lower.specializations
      assert :planning in updated_profile_lower.specializations
      assert :communication not in updated_profile_lower.specializations
    end
    
    test "calculates the overall performance of an agent for a specific capability" do
      agent_id = :agent1
      initial_capabilities = %{
        computation: %{
          efficiency: 0.9,
          quality: 0.8,
          reliability: 0.9,
          latency: 0.1
        }
      }
      
      profile = CapabilityProfile.new(agent_id, initial_capabilities)
      
      performance = CapabilityProfile.capability_performance(profile, :computation)
      
      # Expected performance calculation:
      # (0.9 * 0.3) + (0.8 * 0.3) + (0.9 * 0.3) + ((1.0 - 0.1) * 0.1) = 0.27 + 0.24 + 0.27 + 0.09 = 0.87
      assert_in_delta performance, 0.87, 0.001
      
      # Non-existent capability should return 0.0
      assert CapabilityProfile.capability_performance(profile, :nonexistent) == 0.0
    end
    
    test "gets a time series of performance for a capability" do
      agent_id = :agent1
      initial_capabilities = %{
        computation: %{
          efficiency: 0.8,
          quality: 0.7,
          reliability: 0.9,
          latency: 0.2
        }
      }
      
      profile = CapabilityProfile.new(agent_id, initial_capabilities)
      
      # Add a few more performance entries
      profile = CapabilityProfile.update_capability(profile, :computation, %{
        efficiency: 0.85,
        quality: 0.75,
        reliability: 0.9,
        latency: 0.15
      })
      
      profile = CapabilityProfile.update_capability(profile, :computation, %{
        efficiency: 0.9,
        quality: 0.8,
        reliability: 0.95,
        latency: 0.1
      })
      
      # Get history
      history = CapabilityProfile.capability_history(profile, :computation)
      
      # Should have 3 entries
      assert length(history) == 3
      
      # First entry should be most recent (highest performance)
      assert_in_delta Enum.at(history, 0), 0.895, 0.001
      
      # Non-existent capability should return empty list
      assert CapabilityProfile.capability_history(profile, :nonexistent) == []
    end
  end
  
  describe "CapabilityDiscovery" do
    # These tests verify the functionality of the CapabilityDiscovery module
    
    test "discover_through_observation exists" do
      assert function_exported?(CapabilityDiscovery, :discover_through_observation, 3)
    end
    
    test "discover_through_self_reporting exists" do
      assert function_exported?(CapabilityDiscovery, :discover_through_self_reporting, 1)
    end
    
    test "discover_through_testing exists" do
      assert function_exported?(CapabilityDiscovery, :discover_through_testing, 2)
    end
    
    test "comprehensive_discovery exists" do
      assert function_exported?(CapabilityDiscovery, :comprehensive_discovery, 2)
    end
  end
  
  describe "PerformanceMonitoring" do
    # These tests verify the functionality of the PerformanceMonitoring module
    
    test "record_performance_event exists" do
      assert function_exported?(PerformanceMonitoring, :record_performance_event, 3)
    end
    
    test "analyze_performance_trend exists" do
      assert function_exported?(PerformanceMonitoring, :analyze_performance_trend, 3)
    end
    
    test "compare_agent_performance exists" do
      assert function_exported?(PerformanceMonitoring, :compare_agent_performance, 2)
    end
    
    test "detect_performance_changes exists" do
      assert function_exported?(PerformanceMonitoring, :detect_performance_changes, 3)
    end
  end
  
  describe "ComparativeEvaluation" do
    # These tests verify the functionality of the ComparativeEvaluation module
    
    test "evaluate_relative_capabilities exists" do
      assert function_exported?(ComparativeEvaluation, :evaluate_relative_capabilities, 2)
    end
    
    test "competitive_evaluation exists" do
      assert function_exported?(ComparativeEvaluation, :competitive_evaluation, 3)
    end
    
    test "cooperative_evaluation exists" do
      assert function_exported?(ComparativeEvaluation, :cooperative_evaluation, 3)
    end
    
    test "identify_comparative_advantages exists" do
      assert function_exported?(ComparativeEvaluation, :identify_comparative_advantages, 2)
    end
  end
end