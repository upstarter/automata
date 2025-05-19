defmodule Automata.Reasoning.Cognitive.ContextualReasoning.ContextualInferenceTest do
  use ExUnit.Case, async: false
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.InferenceEngine.ContextualInference
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.ContextManager
  
  describe "ContextualInference" do
    setup do
      # Mock perceptory for testing
      mock_perceptory = %{get_active_perceptions: fn -> [] end}
      
      # Start context manager
      {:ok, manager} = ContextManager.start_link(mock_perceptory)
      
      # Create test contexts with rules
      
      # Weather context with basic rules
      :ok = ContextManager.create_context(
        manager,
        :weather,
        "Weather Context",
        "Context for weather-related reasoning",
        [],
        %{},
        # Initial assertions
        MapSet.new([
          {:weather, ["sunny"]},
          {:temperature, ["warm"]},
          {:season, ["summer"]}
        ]),
        # Rules
        [
          {:weather_warm, [{:weather, ["sunny"]}, {:temperature, ["warm"]}], 
           {:condition, ["pleasant"]}, 0.9},
          {:summer_activity, [{:season, ["summer"]}, {:condition, ["pleasant"]}], 
           {:activity, ["swimming"]}, 0.8}
        ]
      )
      
      # Transportation context
      :ok = ContextManager.create_context(
        manager,
        :transportation,
        "Transportation Context",
        "Context for transportation-related reasoning",
        [],
        %{},
        # Initial assertions
        MapSet.new([
          {:destination, ["downtown"]},
          {:rush_hour, ["yes"]},
          {:distance, ["5km"]}
        ]),
        # Rules
        [
          {:short_distance, [{:distance, ["5km"]}], 
           {:transportation_option, ["bicycle"]}, 0.7},
          {:traffic_jam, [{:rush_hour, ["yes"]}, {:destination, ["downtown"]}], 
           {:traffic, ["heavy"]}, 0.9},
          {:avoid_traffic, [{:traffic, ["heavy"]}], 
           {:transportation_option, ["subway"]}, 0.8}
        ]
      )
      
      # Health context
      :ok = ContextManager.create_context(
        manager,
        :health,
        "Health Context",
        "Context for health-related reasoning",
        [],
        %{},
        # Initial assertions
        MapSet.new([
          {:exercise, ["moderate"]},
          {:diet, ["balanced"]},
          {:sleep, ["adequate"]}
        ]),
        # Rules
        [
          {:healthy_lifestyle, [
            {:exercise, ["moderate"]}, 
            {:diet, ["balanced"]}, 
            {:sleep, ["adequate"]}
          ], {:health_status, ["good"]}, 0.9},
          {:improve_fitness, [{:exercise, ["moderate"]}], 
           {:recommendation, ["increase_intensity"]}, 0.7}
        ]
      )
      
      # Activate specific contexts for each test
      :ok = ContextManager.activate_context(manager, :weather, 1.0)
      :ok = ContextManager.activate_context(manager, :transportation, 1.0)
      
      {:ok, manager: manager}
    end
    
    test "infer/3 derives assertions from active contexts", %{manager: manager} do
      # Infer all assertions
      {:ok, assertions} = ContextualInference.infer(manager, :all)
      
      # Should include original assertions and derived ones
      assert {:condition, ["pleasant"]} in assertions
      assert {:activity, ["swimming"]} in assertions
      assert {:transportation_option, ["bicycle"]} in assertions
      assert {:traffic, ["heavy"]} in assertions
      assert {:transportation_option, ["subway"]} in assertions
      
      # Should not include assertions from inactive contexts
      assert {:health_status, ["good"]} not in assertions
    end
    
    test "infer/3 with specific query pattern", %{manager: manager} do
      # Query for transportation options
      {:ok, options} = ContextualInference.infer(manager, {:transportation_option, :_})
      
      assert length(options) == 2
      assert {:transportation_option, ["bicycle"]} in options
      assert {:transportation_option, ["subway"]} in options
    end
    
    test "infer/3 with depth limit", %{manager: manager} do
      # Add a rule that requires multiple inference steps
      context = ContextManager.get_context(manager, :transportation)
      new_rule = {:alternative_route, 
        [{:transportation_option, ["subway"]}], 
        {:route, ["express_line"]}, 0.8}
      
      updated_context = %{context | rules: [new_rule | context.rules]}
      :ok = ContextManager.update_context(manager, updated_context)
      
      # With sufficient depth, should infer the deep conclusion
      {:ok, deep_results} = ContextualInference.infer(manager, :all, 3)
      assert {:route, ["express_line"]} in deep_results
      
      # With limited depth, shouldn't reach the deeper conclusion
      {:ok, shallow_results} = ContextualInference.infer(manager, :all, 1)
      assert {:route, ["express_line"]} not in shallow_results
    end
    
    test "prove/3 checks if a goal can be proven", %{manager: manager} do
      # Should be able to prove direct assertions
      {:ok, true, trace1} = ContextualInference.prove(manager, {:weather, ["sunny"]})
      assert length(trace1) == 1
      
      # Should be able to prove derived assertions
      {:ok, true, trace2} = ContextualInference.prove(manager, {:activity, ["swimming"]})
      assert length(trace2) > 1
      
      # Should not be able to prove false assertions
      {:ok, false, _} = ContextualInference.prove(manager, {:weather, ["rainy"]})
      
      # Should not be able to prove assertions from inactive contexts
      {:ok, false, _} = ContextualInference.prove(manager, {:health_status, ["good"]})
    end
    
    test "consistent?/2 checks consistency of assertions", %{manager: manager} do
      # Add a contradictory assertion
      context = ContextManager.get_context(manager, :weather)
      contradiction = {:not, [{:weather, ["sunny"]}]}
      assertions = MapSet.put(context.assertions, contradiction)
      updated_context = %{context | assertions: assertions}
      :ok = ContextManager.update_context(manager, updated_context)
      
      # Check consistency of the original assertion
      {consistent, conflicts} = ContextualInference.consistent?(manager, {:weather, ["sunny"]})
      
      assert consistent == false
      assert length(conflicts) > 0
      assert hd(conflicts) == contradiction
      
      # Check consistency of an unrelated assertion
      {consistent2, conflicts2} = ContextualInference.consistent?(manager, {:temperature, ["warm"]})
      
      assert consistent2 == true
      assert Enum.empty?(conflicts2)
    end
    
    test "apply_rule/3 applies a rule to a context", %{manager: manager} do
      # Create a new rule
      rule = {:prepare_for_rain, 
        [{:weather, ["cloudy"]}], 
        {:action, ["bring_umbrella"]}, 
        0.9}
      
      # First add the premise to the context
      context = ContextManager.get_context(manager, :weather)
      assertions = MapSet.put(context.assertions, {:weather, ["cloudy"]})
      updated_context = %{context | assertions: assertions}
      :ok = ContextManager.update_context(manager, updated_context)
      
      # Apply the rule
      :ok = ContextualInference.apply_rule(manager, :weather, rule)
      
      # Check if conclusion was added
      context_after = ContextManager.get_context(manager, :weather)
      assert MapSet.member?(context_after.assertions, {:action, ["bring_umbrella"]})
      
      # Try applying a rule with unsatisfied conditions
      unsatisfied_rule = {:winter_activity, 
        [{:season, ["winter"]}], 
        {:activity, ["skiing"]}, 
        0.9}
        
      result = ContextualInference.apply_rule(manager, :weather, unsatisfied_rule)
      assert result == {:error, :conditions_not_satisfied}
    end
    
    test "explain/2 provides explanation for assertions", %{manager: manager} do
      # Get explanation for a derived assertion
      {:ok, explanation} = ContextualInference.explain(manager, {:activity, ["swimming"]})
      
      # Check explanation structure
      assert explanation.assertion == {:activity, ["swimming"]}
      assert is_list(explanation.contexts)
      assert is_list(explanation.proof)
      assert explanation.confidence > 0.0 and explanation.confidence <= 1.0
      
      # Explanation should mention the relevant rules
      proof_string = Enum.join(explanation.proof)
      assert String.contains?(proof_string, "summer_activity")
      assert String.contains?(proof_string, "weather_warm")
      
      # Try explaining something that cannot be proven
      result = ContextualInference.explain(manager, {:weather, ["snowing"]})
      assert result == {:error, :not_provable}
    end
  end
end