defmodule Automaton.Types.NeuralSymbolic.TranslationFrameworkTest do
  use ExUnit.Case, async: true
  
  alias Automata.Reasoning.Cognitive.NeuralSymbolic.TranslationFramework
  alias Automata.Reasoning.Cognitive.NeuralSymbolic.TranslationFramework.{Encoder, Decoder, Metrics}

  describe "symbolic_to_neural/2" do
    test "converts symbolic representation to neural with confidence" do
      symbolic = %{name: "test_concept", attributes: []}
      
      {neural, confidence} = TranslationFramework.symbolic_to_neural(symbolic)
      
      assert is_map(neural)
      assert Map.has_key?(neural, :vector)
      assert is_list(neural.vector)
      assert Map.has_key?(neural, :metadata)
      assert is_map(neural.metadata)
      assert is_float(confidence)
      assert confidence >= 0.0 and confidence <= 1.0
    end
    
    test "respects encoder options" do
      symbolic = %{name: "test_concept", attributes: []}
      options = [dimensions: 128, normalization: :l2]
      
      {neural, _confidence} = TranslationFramework.symbolic_to_neural(symbolic, options)
      
      assert length(neural.vector) == 128
      
      # Check if normalized (length should be very close to 1.0)
      vector_length = :math.sqrt(Enum.sum(Enum.map(neural.vector, fn x -> x * x end)))
      assert_in_delta vector_length, 1.0, 0.0001
    end
  end
  
  describe "neural_to_symbolic/2" do
    test "converts neural representation to symbolic with confidence" do
      neural = %{
        vector: List.duplicate(0.1, 64),
        metadata: %{source: :test}
      }
      
      {symbolic, confidence} = TranslationFramework.neural_to_symbolic(neural)
      
      assert is_map(symbolic) or is_list(symbolic) or is_tuple(symbolic) or is_atom(symbolic) or is_binary(symbolic)
      assert is_float(confidence)
      assert confidence >= 0.0 and confidence <= 1.0
    end
    
    test "respects decoder options" do
      neural = %{
        vector: List.duplicate(0.1, 64),
        metadata: %{source: :test}
      }
      options = [output_type: :map, threshold: 0.3]
      
      {symbolic, _confidence} = TranslationFramework.neural_to_symbolic(neural, options)
      
      assert is_map(symbolic)
    end
  end
  
  describe "refine_translation/3" do
    test "refines translations using feedback" do
      original = %{name: "test_concept", attributes: []}
      feedback = %{accuracy: 0.7, suggestions: [:add_detail]}
      options = [iterations: 1, learning_rate: 0.1]
      
      {refined, confidence} = TranslationFramework.refine_translation(original, feedback, options)
      
      assert is_map(refined) or is_list(refined) or is_tuple(refined) or is_atom(refined) or is_binary(refined)
      assert is_float(confidence)
      assert confidence >= 0.0 and confidence <= 1.0
    end
  end
  
  describe "evaluate_framework/1" do
    test "evaluates framework on test pairs" do
      test_pairs = [
        {
          %{name: "concept_a", attributes: []},
          %{vector: [0.1, 0.2, 0.3], metadata: %{}}
        },
        {
          %{name: "concept_b", attributes: []},
          %{vector: [0.4, 0.5, 0.6], metadata: %{}}
        }
      ]
      
      metrics = TranslationFramework.evaluate_framework(test_pairs)
      
      assert is_map(metrics)
      assert Map.has_key?(metrics, :mean_forward_error)
      assert Map.has_key?(metrics, :mean_forward_confidence)
      assert Map.has_key?(metrics, :mean_backward_similarity)
      assert Map.has_key?(metrics, :mean_backward_confidence)
      assert Map.has_key?(metrics, :mean_roundtrip_fidelity)
    end
  end
  
  describe "Encoder.encode/2" do
    test "encodes different symbolic input types" do
      test_data = [
        %{name: "map_input"},
        ["list", "input"],
        {"tuple", "input"},
        :atom_input,
        "string_input"
      ]
      
      for input <- test_data do
        {output, confidence} = Encoder.encode(input)
        
        assert is_map(output)
        assert Map.has_key?(output, :vector)
        assert is_list(output.vector)
        assert Map.has_key?(output, :metadata)
        assert is_map(output.metadata)
        assert is_float(confidence)
        assert confidence >= 0.0 and confidence <= 1.0
      end
    end
    
    test "applies different normalization methods" do
      input = %{name: "test_input"}
      
      # L2 normalization
      {output_l2, _} = Encoder.encode(input, [normalization: :l2])
      l2_length = :math.sqrt(Enum.sum(Enum.map(output_l2.vector, fn x -> x * x end)))
      assert_in_delta l2_length, 1.0, 0.0001
      
      # L1 normalization
      {output_l1, _} = Encoder.encode(input, [normalization: :l1])
      l1_sum = Enum.sum(Enum.map(output_l1.vector, &abs/1))
      assert_in_delta l1_sum, 1.0, 0.0001
      
      # MinMax normalization
      {output_minmax, _} = Encoder.encode(input, [normalization: :minmax])
      assert Enum.all?(output_minmax.vector, fn x -> x >= 0.0 and x <= 1.0 end)
    end
  end
  
  describe "Decoder.decode/2" do
    test "decodes to different output types" do
      neural_input = %{
        vector: List.duplicate(0.1, 64),
        metadata: %{source: :test}
      }
      
      output_types = [:map, :list, :tuple, :atom, :string]
      
      for output_type <- output_types do
        {output, confidence} = Decoder.decode(neural_input, [output_type: output_type])
        
        assert is_float(confidence)
        assert confidence >= 0.0 and confidence <= 1.0
        
        case output_type do
          :map -> assert is_map(output)
          :list -> assert is_list(output)
          :tuple -> assert is_tuple(output)
          :atom -> assert is_atom(output)
          :string -> assert is_binary(output)
        end
      end
    end
    
    test "respects confidence threshold" do
      neural_input = %{
        vector: List.duplicate(0.1, 64),
        metadata: %{source: :test}
      }
      
      # With default threshold
      {output1, _confidence1} = Decoder.decode(neural_input)
      
      # With high threshold - should still return something but might affect confidence
      {output2, confidence2} = Decoder.decode(neural_input, [threshold: 0.9])
      
      assert not is_nil(output1)
      assert not is_nil(output2)
      assert confidence2 >= 0.0 and confidence2 <= 1.0
    end
  end
  
  describe "Metrics.measure_roundtrip_fidelity/3" do
    test "measures translation fidelity with roundtrip conversion" do
      original = %{name: "test_concept", attributes: []}
      
      fidelity = Metrics.measure_roundtrip_fidelity(original)
      
      assert is_float(fidelity)
      assert fidelity >= 0.0 and fidelity <= 1.0
    end
    
    test "respects encoder and decoder options" do
      original = %{name: "test_concept", attributes: []}
      encoder_options = [dimensions: 128]
      decoder_options = [output_type: :map]
      
      fidelity = Metrics.measure_roundtrip_fidelity(original, encoder_options, decoder_options)
      
      assert is_float(fidelity)
      assert fidelity >= 0.0 and fidelity <= 1.0
    end
  end
  
  describe "Metrics.confidence_interval/2" do
    test "calculates confidence interval" do
      confidence = 0.8
      sample_size = 10
      
      {lower, upper} = Metrics.confidence_interval(confidence, sample_size)
      
      assert lower < confidence
      assert upper > confidence
      assert lower >= 0.0
      assert upper <= 1.0
    end
  end
end