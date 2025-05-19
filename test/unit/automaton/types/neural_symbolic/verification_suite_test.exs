defmodule Automaton.Types.NeuralSymbolic.VerificationSuiteTest do
  use ExUnit.Case, async: true
  
  alias Automata.Reasoning.Cognitive.NeuralSymbolic.VerificationSuite
  alias Automata.Reasoning.Cognitive.NeuralSymbolic.TranslationFramework

  describe "verify_neural_output/2" do
    test "verifies neural output for logical consistency" do
      neural_output = %{
        vector: List.duplicate(0.1, 64),
        metadata: %{source: :test}
      }
      
      result = VerificationSuite.verify_neural_output(neural_output)
      
      assert is_map(result)
      assert Map.has_key?(result, :valid)
      assert is_boolean(result.valid)
      assert Map.has_key?(result, :consistency_score)
      assert is_float(result.consistency_score)
      assert Map.has_key?(result, :violations)
      assert is_list(result.violations)
      assert Map.has_key?(result, :confidence)
      assert is_float(result.confidence)
    end
    
    test "respects verification options" do
      neural_output = %{
        vector: List.duplicate(0.1, 64),
        metadata: %{source: :test}
      }
      
      options = [domain_constraints: []]
      
      result = VerificationSuite.verify_neural_output(neural_output, options)
      
      assert is_map(result)
      assert Map.has_key?(result, :valid)
    end
  end
  
  describe "verify_symbolic_reasoning/3" do
    test "verifies symbolic reasoning using neural anomaly detection" do
      symbolic_result = %{type: :answer, content: "test result"}
      reasoning_trace = [
        {:init, %{type: :query, content: "test query"}},
        {:final, symbolic_result}
      ]
      
      result = VerificationSuite.verify_symbolic_reasoning(symbolic_result, reasoning_trace)
      
      assert is_map(result)
      assert Map.has_key?(result, :valid)
      assert is_boolean(result.valid)
      assert Map.has_key?(result, :anomaly_score)
      assert is_float(result.anomaly_score)
      assert Map.has_key?(result, :anomalies)
      assert is_list(result.anomalies)
      assert Map.has_key?(result, :confidence)
      assert is_float(result.confidence)
    end
  end
  
  describe "verify_hybrid_reasoning/4" do
    test "verifies reasoning using both symbolic and neural techniques" do
      symbolic_result = %{type: :answer, content: "test result"}
      neural_result = %{
        vector: List.duplicate(0.1, 64),
        metadata: %{source: :test}
      }
      reasoning_trace = [
        {:init, %{type: :query, content: "test query"}},
        {:final, symbolic_result}
      ]
      
      result = VerificationSuite.verify_hybrid_reasoning(
        symbolic_result,
        neural_result,
        reasoning_trace
      )
      
      assert is_map(result)
      assert Map.has_key?(result, :valid)
      assert is_boolean(result.valid)
      assert Map.has_key?(result, :score)
      assert is_float(result.score)
      assert Map.has_key?(result, :issues)
      assert is_list(result.issues)
      assert Map.has_key?(result, :confidence)
      assert is_float(result.confidence)
    end
  end
  
  describe "verify_under_adversarial_conditions/3" do
    test "tests reasoning robustness under adversarial conditions" do
      reasoning_result = %{type: :answer, content: "test result"}
      reasoning_trace = [
        {:init, %{type: :query, content: "test query"}},
        {:final, reasoning_result}
      ]
      
      result = VerificationSuite.verify_under_adversarial_conditions(
        reasoning_result,
        reasoning_trace
      )
      
      assert is_map(result)
      assert Map.has_key?(result, :valid)
      assert is_boolean(result.valid)
      assert Map.has_key?(result, :score)
      assert is_float(result.score)
      assert Map.has_key?(result, :issues)
      assert is_list(result.issues)
      assert Map.has_key?(result, :confidence)
      assert is_float(result.confidence)
    end
    
    test "respects robustness threshold option" do
      reasoning_result = %{type: :answer, content: "test result"}
      reasoning_trace = [
        {:init, %{type: :query, content: "test query"}},
        {:final, reasoning_result}
      ]
      
      options = [robustness_threshold: 0.8]
      
      result = VerificationSuite.verify_under_adversarial_conditions(
        reasoning_result,
        reasoning_trace,
        options
      )
      
      assert is_map(result)
      assert Map.has_key?(result, :valid)
    end
  end
  
  describe "weighted_average/2" do
    test "calculates weighted average correctly" do
      values = [0.2, 0.4, 0.6]
      weights = [0.5, 0.3, 0.2]
      
      result = VerificationSuite.weighted_average(values, weights)
      
      # Expected: 0.2*0.5 + 0.4*0.3 + 0.6*0.2 = 0.1 + 0.12 + 0.12 = 0.34
      assert_in_delta result, 0.34, 0.0001
    end
  end
  
  describe "mean/1" do
    test "calculates mean correctly" do
      numbers = [1, 2, 3, 4, 5]
      
      result = VerificationSuite.mean(numbers)
      
      # Expected: (1+2+3+4+5)/5 = 15/5 = 3
      assert_in_delta result, 3.0, 0.0001
    end
  end
  
  describe "integration with TranslationFramework" do
    test "verifies outputs from translation framework" do
      # Create a symbolic representation
      symbolic = %{name: "test_concept", attributes: []}
      
      # Translate to neural
      {neural, _} = TranslationFramework.symbolic_to_neural(symbolic)
      
      # Verify the neural output
      result = VerificationSuite.verify_neural_output(neural)
      
      assert is_map(result)
      assert Map.has_key?(result, :valid)
      
      # Translate back to symbolic
      {symbolic_back, _} = TranslationFramework.neural_to_symbolic(neural)
      
      # Create a mock reasoning trace
      reasoning_trace = [
        {:init, %{type: :query, content: "test query"}},
        {:final, symbolic_back}
      ]
      
      # Verify the symbolic reasoning
      result2 = VerificationSuite.verify_symbolic_reasoning(symbolic_back, reasoning_trace)
      
      assert is_map(result2)
      assert Map.has_key?(result2, :valid)
      
      # Verify using hybrid approach
      result3 = VerificationSuite.verify_hybrid_reasoning(
        symbolic_back,
        neural,
        reasoning_trace
      )
      
      assert is_map(result3)
      assert Map.has_key?(result3, :valid)
    end
  end
end