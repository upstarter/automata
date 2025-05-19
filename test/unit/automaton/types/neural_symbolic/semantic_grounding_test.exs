defmodule Automaton.Types.NeuralSymbolic.SemanticGroundingTest do
  use ExUnit.Case, async: true
  
  alias Automata.Reasoning.Cognitive.NeuralSymbolic.SemanticGrounding
  alias Automata.Reasoning.Cognitive.NeuralSymbolic.SemanticGrounding.{
    ConceptGrounding,
    SymbolEmergence,
    GroundingVerification
  }

  describe "ground_concept/3" do
    test "grounds a concept across multiple modalities" do
      concept = :test_concept
      sensory_data = [
        %{modality: :visual, data: [0.1, 0.2, 0.3], metadata: %{}},
        %{modality: :semantic, data: "test concept data", metadata: %{}}
      ]
      
      grounding = SemanticGrounding.ground_concept(concept, sensory_data)
      
      assert is_map(grounding)
      assert grounding.concept == concept
      assert is_map(grounding.groundings)
      assert Map.has_key?(grounding.groundings, :visual)
      assert Map.has_key?(grounding.groundings, :semantic)
      assert is_float(grounding.confidence)
      assert is_float(grounding.stability)
    end
    
    test "respects modality options" do
      concept = :test_concept
      sensory_data = [
        %{modality: :visual, data: [0.1, 0.2, 0.3], metadata: %{}},
        %{modality: :semantic, data: "test concept data", metadata: %{}},
        %{modality: :proprioceptive, data: [0.4, 0.5, 0.6], metadata: %{}}
      ]
      
      grounding = SemanticGrounding.ground_concept(concept, sensory_data)
      
      assert is_map(grounding)
      assert map_size(grounding.groundings) == 3
    end
  end
  
  describe "identify_symbols/2" do
    test "identifies emergent symbols from patterns" do
      patterns = [
        %{features: [0.1, 0.2, 0.3], context: :context1},
        %{features: [0.15, 0.25, 0.35], context: :context1},
        %{features: [0.7, 0.8, 0.9], context: :context2}
      ]
      
      symbols = SemanticGrounding.identify_symbols(patterns)
      
      assert is_list(symbols)
      assert length(symbols) > 0
      
      Enum.each(symbols, fn symbol ->
        assert is_map(symbol)
        assert is_atom(symbol.symbol) or is_binary(symbol.symbol)
        assert is_map(symbol.pattern)
        assert is_float(symbol.confidence)
        assert is_float(symbol.stability)
      end)
    end
  end
  
  describe "track_symbol_evolution/3" do
    test "tracks evolution of symbols over time" do
      # Previous symbols
      previous_symbols = [
        %{
          symbol: :concept_1,
          pattern: %{features: [0.1, 0.2, 0.3]},
          confidence: 0.8,
          stability: 0.7
        }
      ]
      
      # New patterns
      new_patterns = [
        %{features: [0.12, 0.22, 0.32], context: :context1},
        %{features: [0.7, 0.8, 0.9], context: :context2}
      ]
      
      updated_symbols = SemanticGrounding.track_symbol_evolution(
        previous_symbols,
        new_patterns
      )
      
      assert is_list(updated_symbols)
      assert length(updated_symbols) >= length(previous_symbols)
      
      Enum.each(updated_symbols, fn symbol ->
        assert is_map(symbol)
        assert is_atom(symbol.symbol) or is_binary(symbol.symbol)
        assert is_map(symbol.pattern)
        assert is_float(symbol.confidence)
        assert is_float(symbol.stability)
      end)
    end
  end
  
  describe "verify_grounding/2" do
    test "verifies quality of concept groundings" do
      # Create a grounding to verify
      concept = :test_concept
      sensory_data = [
        %{modality: :visual, data: [0.1, 0.2, 0.3], metadata: %{}},
        %{modality: :semantic, data: "test concept data", metadata: %{}}
      ]
      
      grounding = SemanticGrounding.ground_concept(concept, sensory_data)
      
      # Verify the grounding
      verification = SemanticGrounding.verify_grounding(grounding)
      
      assert is_map(verification)
      assert Map.has_key?(verification, :valid)
      assert is_boolean(verification.valid)
      assert Map.has_key?(verification, :score)
      assert is_float(verification.score)
      assert Map.has_key?(verification, :issues)
      assert is_list(verification.issues)
      assert Map.has_key?(verification, :confidence)
      assert is_float(verification.confidence)
    end
    
    test "respects environment option" do
      # Create a grounding to verify
      concept = :test_concept
      sensory_data = [
        %{modality: :visual, data: [0.1, 0.2, 0.3], metadata: %{}},
        %{modality: :semantic, data: "test concept data", metadata: %{}}
      ]
      
      grounding = SemanticGrounding.ground_concept(concept, sensory_data)
      
      # Verify with environment
      environment = %{
        objects: [:object1, :object2],
        relations: [{:object1, :near, :object2}]
      }
      
      verification = SemanticGrounding.verify_grounding(grounding, [environment: environment])
      
      assert is_map(verification)
      assert Map.has_key?(verification, :valid)
    end
  end
  
  describe "verify_symbol_emergence/2" do
    test "verifies quality of emergent symbols" do
      # Create patterns for symbol emergence
      patterns = [
        %{features: [0.1, 0.2, 0.3], context: :context1},
        %{features: [0.15, 0.25, 0.35], context: :context1}
      ]
      
      # Identify emergent symbols
      [symbol | _] = SemanticGrounding.identify_symbols(patterns)
      
      # Verify the emergent symbol
      verification = SemanticGrounding.verify_symbol_emergence(symbol)
      
      assert is_map(verification)
      assert Map.has_key?(verification, :valid)
      assert is_boolean(verification.valid)
      assert Map.has_key?(verification, :score)
      assert is_float(verification.score)
      assert Map.has_key?(verification, :issues)
      assert is_list(verification.issues)
      assert Map.has_key?(verification, :confidence)
      assert is_float(verification.confidence)
    end
    
    test "respects existing symbols option" do
      # Create patterns for symbol emergence
      patterns = [
        %{features: [0.1, 0.2, 0.3], context: :context1},
        %{features: [0.15, 0.25, 0.35], context: :context1}
      ]
      
      # Identify emergent symbols
      [symbol | _] = SemanticGrounding.identify_symbols(patterns)
      
      # Existing symbols
      existing_symbols = [
        %{
          symbol: :existing_concept,
          pattern: %{features: [0.7, 0.8, 0.9]},
          confidence: 0.8,
          stability: 0.7
        }
      ]
      
      # Verify with existing symbols
      verification = SemanticGrounding.verify_symbol_emergence(
        symbol,
        [existing_symbols: existing_symbols]
      )
      
      assert is_map(verification)
      assert Map.has_key?(verification, :valid)
    end
  end
  
  describe "integrate_concept/3" do
    test "provides end-to-end integration of a concept" do
      concept = :test_concept
      sensory_data = [
        %{modality: :visual, data: [0.1, 0.2, 0.3], metadata: %{}},
        %{modality: :semantic, data: "test concept data", metadata: %{}}
      ]
      
      result = SemanticGrounding.integrate_concept(concept, sensory_data)
      
      assert is_map(result)
      assert result.concept == concept
      assert Map.has_key?(result, :grounding)
      assert Map.has_key?(result, :verification)
      assert Map.has_key?(result, :symbolic)
      assert Map.has_key?(result, :neural)
      assert is_boolean(result.valid)
      assert is_float(result.confidence)
    end
  end
  
  describe "ConceptGrounding.ground_concept/3" do
    test "grounds a concept in multiple modalities" do
      concept = :test_concept
      sensory_data = [
        %{modality: :visual, data: [0.1, 0.2, 0.3], metadata: %{}},
        %{modality: :auditory, data: [0.4, 0.5, 0.6], metadata: %{}}
      ]
      
      result = ConceptGrounding.ground_concept(concept, sensory_data)
      
      assert is_map(result)
      assert result.concept == concept
      assert Map.has_key?(result.groundings, :visual)
      assert Map.has_key?(result.groundings, :auditory)
      assert is_float(result.confidence)
      assert is_float(result.stability)
    end
  end
  
  describe "SymbolEmergence.identify_symbols/2" do
    test "identifies symbols from pattern clusters" do
      patterns = [
        %{features: [0.1, 0.2, 0.3], context: :context1},
        %{features: [0.15, 0.25, 0.35], context: :context1},
        %{features: [0.7, 0.8, 0.9], context: :context2}
      ]
      
      symbols = SymbolEmergence.identify_symbols(patterns)
      
      assert is_list(symbols)
      assert length(symbols) > 0
      
      Enum.each(symbols, fn symbol ->
        assert is_map(symbol)
        assert is_atom(symbol.symbol)
        assert is_map(symbol.pattern)
        assert is_float(symbol.confidence)
        assert is_float(symbol.stability)
      end)
    end
  end
  
  describe "GroundingVerification.verify_grounding/2" do
    test "verifies cross-modal consistency of groundings" do
      # Create a grounding to verify
      concept = :test_concept
      sensory_data = [
        %{modality: :visual, data: [0.1, 0.2, 0.3], metadata: %{}},
        %{modality: :semantic, data: "test concept data", metadata: %{}}
      ]
      
      grounding = ConceptGrounding.ground_concept(concept, sensory_data)
      
      # Verify the grounding
      verification = GroundingVerification.verify_grounding(grounding)
      
      assert is_map(verification)
      assert Map.has_key?(verification, :valid)
      assert is_boolean(verification.valid)
      assert Map.has_key?(verification, :score)
      assert is_float(verification.score)
      assert Map.has_key?(verification, :issues)
      assert is_list(verification.issues)
      assert Map.has_key?(verification, :confidence)
      assert is_float(verification.confidence)
    end
  end
  
  describe "weighted_average/2" do
    test "calculates weighted average correctly" do
      values = [0.2, 0.4, 0.6]
      weights = [0.5, 0.3, 0.2]
      
      result = SemanticGrounding.weighted_average(values, weights)
      
      # Expected: 0.2*0.5 + 0.4*0.3 + 0.6*0.2 = 0.1 + 0.12 + 0.12 = 0.34
      assert_in_delta result, 0.34, 0.0001
    end
  end
end