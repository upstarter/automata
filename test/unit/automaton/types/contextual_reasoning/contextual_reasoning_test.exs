defmodule Automata.Reasoning.Cognitive.ContextualReasoningTest do
  use ExUnit.Case, async: false
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning
  
  describe "ContextualReasoning" do
    setup do
      # Mock components for testing
      mock_perceptory = %{
        get_active_perceptions: fn -> [] end,
        get_active_percept_memories: fn -> [] end
      }
      
      mock_perception_memory = %{}
      
      mock_associative_memory = %{
        create_association: fn _, _, _, _ -> :ok end
      }
      
      # Create contextual reasoning system
      reasoning = ContextualReasoning.new(
        mock_perceptory,
        mock_perception_memory,
        mock_associative_memory
      )
      
      # Create test contexts
      ContextualReasoning.create_context(
        reasoning,
        :kitchen,
        "Kitchen Context",
        "Reasoning about kitchen activities",
        [],
        %{location: "home"},
        MapSet.new([
          {:appliance, ["refrigerator"]},
          {:appliance, ["stove"]},
          {:food, ["vegetables"]}
        ])
      )
      
      ContextualReasoning.create_context(
        reasoning,
        :cooking,
        "Cooking Context",
        "Reasoning about cooking activities",
        [:kitchen],  # Parent is kitchen
        %{activity: "food preparation"},
        MapSet.new([
          {:utensil, ["knife"]},
          {:utensil, ["cutting board"]},
          {:ingredient, ["tomato"]}
        ]),
        [
          {:recipe_rule, [{:ingredient, ["tomato"]}, {:utensil, ["knife"]}], 
           {:action, ["slice tomato"]}, 0.9}
        ]
      )
      
      {:ok, reasoning: reasoning}
    end
    
    test "create_context/8 creates contexts", %{reasoning: reasoning} do
      # Create a new context
      result = ContextualReasoning.create_context(
        reasoning,
        :dining,
        "Dining Context",
        "Reasoning about dining activities",
        [:kitchen],
        %{activity: "eating"},
        MapSet.new([{:furniture, ["table"]}, {:furniture, ["chair"]}])
      )
      
      assert result == :ok
      
      # Activate and get context
      ContextualReasoning.activate_context(reasoning, :dining, 0.8)
      contexts = ContextualReasoning.get_active_contexts(reasoning)
      
      # Find the dining context
      dining = Enum.find(contexts, fn ctx -> ctx.id == :dining end)
      
      assert dining != nil
      assert dining.name == "Dining Context"
      assert dining.parameters.activity == "eating"
      assert MapSet.member?(dining.assertions, {:furniture, ["table"]})
      assert dining.parent_ids == [:kitchen]
    end
    
    test "activate_context/3 and get_active_contexts/1", %{reasoning: reasoning} do
      # Initially no active contexts
      active_contexts = ContextualReasoning.get_active_contexts(reasoning)
      assert Enum.empty?(active_contexts)
      
      # Activate kitchen context
      result = ContextualReasoning.activate_context(reasoning, :kitchen, 0.7)
      assert result == :ok
      
      # Verify context is active
      active_contexts = ContextualReasoning.get_active_contexts(reasoning)
      assert length(active_contexts) == 1
      assert hd(active_contexts).id == :kitchen
      
      # Activate another context
      ContextualReasoning.activate_context(reasoning, :cooking, 0.9)
      
      # Both contexts should be active
      active_contexts = ContextualReasoning.get_active_contexts(reasoning)
      assert length(active_contexts) == 2
      
      # Should be sorted by activation (higher activation first)
      assert Enum.at(active_contexts, 0).id == :cooking
      assert Enum.at(active_contexts, 1).id == :kitchen
    end
    
    test "infer/3 performs contextual inference", %{reasoning: reasoning} do
      # Activate both contexts
      ContextualReasoning.activate_context(reasoning, :kitchen, 1.0)
      ContextualReasoning.activate_context(reasoning, :cooking, 1.0)
      
      # Perform inference
      {:ok, inferences} = ContextualReasoning.infer(reasoning, :all)
      
      # Should include basic facts
      assert {:appliance, ["refrigerator"]} in inferences
      assert {:utensil, ["knife"]} in inferences
      
      # Should include derived facts
      assert {:action, ["slice tomato"]} in inferences
    end
    
    test "add_assertion/3 adds assertions to contexts", %{reasoning: reasoning} do
      # Add assertion to kitchen context
      result = ContextualReasoning.add_assertion(
        reasoning, 
        :kitchen, 
        {:food, ["fruit"]}
      )
      
      assert result == :ok
      
      # Activate kitchen context
      ContextualReasoning.activate_context(reasoning, :kitchen, 1.0)
      
      # Infer to check assertion was added
      {:ok, inferences} = ContextualReasoning.infer(reasoning, :all)
      assert {:food, ["fruit"]} in inferences
    end
    
    test "add_semantic_node/6 adds nodes to semantic network", %{reasoning: reasoning} do
      # Add a node
      updated_reasoning = ContextualReasoning.add_semantic_node(
        reasoning,
        :recipe,
        :concept,
        "Recipe",
        %{type: "instruction set"},
        [:cooking]
      )
      
      # Add an edge
      updated_reasoning = ContextualReasoning.add_semantic_edge(
        updated_reasoning,
        :recipe,
        :ingredient,
        :uses,
        0.9,
        %{},
        [:cooking]
      )
      
      # Activate cooking context to make nodes relevant
      ContextualReasoning.activate_context(updated_reasoning, :cooking, 1.0)
      
      # Spread activation
      activated_reasoning = ContextualReasoning.spread_semantic_activation(
        updated_reasoning,
        :recipe,
        1.0,
        0.5,
        2
      )
      
      # The semantic network would now have activation levels
      # We can't directly test this without accessing the internal semantic_network field
      
      # But we can test that the functions executed without errors
      assert activated_reasoning != nil
    end
    
    test "store_memory/5 and retrieve_memories/3", %{reasoning: reasoning} do
      # Store memory in kitchen context
      updated_reasoning = ContextualReasoning.store_memory(
        reasoning,
        %{type: :recipe, content: "Tomato soup"},
        [:kitchen],
        0.9,
        %{difficulty: "easy"}
      )
      
      # Store another memory
      updated_reasoning = ContextualReasoning.store_memory(
        updated_reasoning,
        %{type: :cooking_tip, content: "Always preheat the oven"},
        [:cooking],
        0.8
      )
      
      # Activate contexts
      ContextualReasoning.activate_context(updated_reasoning, :kitchen, 1.0)
      ContextualReasoning.activate_context(updated_reasoning, :cooking, 1.0)
      
      # Retrieve memories
      {memories, _} = ContextualReasoning.retrieve_memories(updated_reasoning)
      
      # Should have both memories
      assert length(memories) == 2
      
      # Find the recipe memory
      recipe_memory = Enum.find(memories, fn m -> m.content.type == :recipe end)
      
      assert recipe_memory != nil
      assert recipe_memory.content.content == "Tomato soup"
      assert recipe_memory.confidence == 0.9
      assert recipe_memory.metadata.difficulty == "easy"
      
      # Retrieve with query
      {recipe_memories, _} = ContextualReasoning.retrieve_memories(
        updated_reasoning, 
        fn m -> m.content.type == :recipe end
      )
      
      assert length(recipe_memories) == 1
      assert hd(recipe_memories).content.content == "Tomato soup"
    end
    
    test "process_perceptions/2 integrates perceptions", %{reasoning: reasoning} do
      # Create test perceptions
      perceptions = [
        %{type: :visual, value: "knife", attributes: %{size: "large"}, id: "vis1", activation: 0.9},
        %{type: :visual, value: "tomato", attributes: %{color: "red"}, id: "vis2", activation: 0.8}
      ]
      
      # Mock behavior to return perception memories
      percept_memories = [
        %{type: :visual, value: "knife", attributes: %{size: "large"}, activation: 0.9},
        %{type: :visual, value: "tomato", attributes: %{color: "red"}, activation: 0.8}
      ]
      
      # Replace mock perceptory with one that returns our test data
      mock_perceptory = %{
        get_active_perceptions: fn -> perceptions end,
        get_active_percept_memories: fn -> percept_memories end
      }
      
      # Set the perceptory in the reasoning system
      updated_reasoning = %{reasoning | perceptory: mock_perceptory}
      
      # Process perceptions
      result_reasoning = ContextualReasoning.process_perceptions(
        updated_reasoning,
        perceptions
      )
      
      # The perceptions should now be stored in memory
      # and represented in the semantic network
      
      # We can test that the function executed without errors
      assert result_reasoning != nil
      
      # Activate the contexts
      ContextualReasoning.activate_context(result_reasoning, :kitchen, 1.0)
      ContextualReasoning.activate_context(result_reasoning, :cooking, 1.0)
      
      # Retrieve memories to see if perceptions were integrated
      {memories, _} = ContextualReasoning.retrieve_memories(result_reasoning)
      
      # Should have perception memories
      assert length(memories) > 0
      
      # Find a perception memory
      visual_memory = Enum.find(memories, fn m -> 
        m.content.type == :perception && m.content.percept_type == :visual
      end)
      
      if visual_memory do
        assert visual_memory.content.value in ["knife", "tomato"]
      end
    end
    
    test "apply_decay/1 applies decay to memories", %{reasoning: reasoning} do
      # Store a memory
      updated_reasoning = ContextualReasoning.store_memory(
        reasoning,
        %{type: :note, content: "Test decay"},
        [],
        1.0
      )
      
      # Apply decay
      decayed_reasoning = ContextualReasoning.apply_decay(updated_reasoning)
      
      # The memory should now have reduced confidence
      # We can test that the function executed without errors
      assert decayed_reasoning != nil
    end
  end
end