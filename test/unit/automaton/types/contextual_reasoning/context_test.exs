defmodule Automata.Reasoning.Cognitive.ContextualReasoning.ContextTest do
  use ExUnit.Case, async: true
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.Context
  
  describe "Context" do
    setup do
      context = Context.new(
        :test_context,
        "Test Context",
        "A context for testing purposes",
        [],
        %{test_param: "value"},
        MapSet.new([{:test_fact, ["data"]}]),
        [{:test_rule, [{:condition, ["met"]}], {:conclusion, ["valid"]}, 0.9}]
      )
      
      {:ok, context: context}
    end
    
    test "new/8 creates a context with proper values", %{context: context} do
      assert context.id == :test_context
      assert context.name == "Test Context"
      assert context.description == "A context for testing purposes"
      assert context.parent_ids == []
      assert context.parameters == %{test_param: "value"}
      assert MapSet.member?(context.assertions, {:test_fact, ["data"]})
      assert hd(context.rules) == {:test_rule, [{:condition, ["met"]}], {:conclusion, ["valid"]}, 0.9}
      assert context.activation == 0.0
      assert context.children == []
      assert context.activation_threshold == 0.5
      assert context.decay_rate == 0.05
    end
    
    test "activate/2 increases context activation", %{context: context} do
      activated = Context.activate(context, 0.7)
      assert activated.activation == 0.7
      
      # Activation should be capped at 1.0
      fully_activated = Context.activate(activated, 0.5)
      assert fully_activated.activation == 1.0
      
      # Metadata should be updated
      assert fully_activated.metadata.activation_count == 2
      assert fully_activated.metadata.last_activated != nil
    end
    
    test "deactivate/2 decreases context activation", %{context: context} do
      # First activate it
      activated = Context.activate(context, 0.8)
      assert activated.activation == 0.8
      
      # Then deactivate partially
      partially_deactivated = Context.deactivate(activated, 0.3)
      assert partially_deactivated.activation == 0.5
      
      # Deactivate fully
      fully_deactivated = Context.deactivate(activated, 1.0)
      assert fully_deactivated.activation == 0.0
    end
    
    test "apply_decay/1 reduces activation over time", %{context: context} do
      # Activate first
      activated = Context.activate(context, 1.0)
      assert activated.activation == 1.0
      
      # Apply decay
      decayed = Context.apply_decay(activated)
      
      # Activation should be reduced
      assert decayed.activation < activated.activation
      assert decayed.activation == 1.0 * (1.0 - context.decay_rate)
    end
    
    test "active?/1 checks if context is above activation threshold", %{context: context} do
      # Initially inactive
      assert Context.active?(context) == false
      
      # Activate below threshold
      below_threshold = Context.activate(context, 0.4)
      assert Context.active?(below_threshold) == false
      
      # Activate at threshold
      at_threshold = Context.activate(context, 0.5)
      assert Context.active?(at_threshold) == true
      
      # Activate above threshold
      above_threshold = Context.activate(context, 0.7)
      assert Context.active?(above_threshold) == true
    end
    
    test "add_child/2 adds a child context ID", %{context: context} do
      updated = Context.add_child(context, :child_context)
      assert updated.children == [:child_context]
      
      # Adding the same child again should not duplicate
      updated_again = Context.add_child(updated, :child_context)
      assert updated_again.children == [:child_context]
      
      # Add another child
      with_second_child = Context.add_child(updated, :another_child)
      assert :child_context in with_second_child.children
      assert :another_child in with_second_child.children
      assert length(with_second_child.children) == 2
    end
    
    test "add_assertion/2 adds an assertion to the context", %{context: context} do
      updated = Context.add_assertion(context, {:new_fact, ["info"]})
      
      assert MapSet.member?(updated.assertions, {:test_fact, ["data"]})
      assert MapSet.member?(updated.assertions, {:new_fact, ["info"]})
      assert MapSet.size(updated.assertions) == 2
    end
    
    test "remove_assertion/2 removes an assertion from the context", %{context: context} do
      updated = Context.remove_assertion(context, {:test_fact, ["data"]})
      
      assert MapSet.size(updated.assertions) == 0
      assert not MapSet.member?(updated.assertions, {:test_fact, ["data"]})
      
      # Removing non-existent assertion should be a no-op
      same = Context.remove_assertion(updated, {:nonexistent, []})
      assert MapSet.size(same.assertions) == 0
    end
    
    test "add_rule/2 adds a rule to the context", %{context: context} do
      rule = {:new_rule, [{:premise, ["data"]}], {:conclusion, ["result"]}, 0.8}
      updated = Context.add_rule(context, rule)
      
      assert length(updated.rules) == 2
      assert Enum.at(updated.rules, 0) == rule
    end
    
    test "remove_rule/2 removes a rule from the context", %{context: context} do
      updated = Context.remove_rule(context, :test_rule)
      
      assert length(updated.rules) == 0
      
      # Removing non-existent rule should be a no-op
      same = Context.remove_rule(updated, :nonexistent_rule)
      assert length(same.rules) == 0
    end
    
    test "set_parameter/3 sets a parameter value", %{context: context} do
      updated = Context.set_parameter(context, :new_param, 42)
      
      assert updated.parameters.test_param == "value"
      assert updated.parameters.new_param == 42
      
      # Overwrite existing parameter
      overwritten = Context.set_parameter(updated, :test_param, "new value")
      assert overwritten.parameters.test_param == "new value"
    end
    
    test "get_parameter/3 retrieves a parameter value", %{context: context} do
      assert Context.get_parameter(context, :test_param) == "value"
      assert Context.get_parameter(context, :nonexistent) == nil
      assert Context.get_parameter(context, :nonexistent, "default") == "default"
    end
    
    test "merge/2 combines two contexts", %{context: context} do
      other_context = Context.new(
        :other_context,
        "Other Context",
        "Another context",
        [:parent_context],
        %{other_param: 123},
        MapSet.new([{:other_fact, ["more data"]}]),
        [{:other_rule, [{:condition, ["test"]}], {:result, ["output"]}, 0.7}]
      )
      
      merged = Context.merge(context, other_context)
      
      # Parameters should be merged
      assert merged.parameters.test_param == "value"
      assert merged.parameters.other_param == 123
      
      # Assertions should be merged
      assert MapSet.member?(merged.assertions, {:test_fact, ["data"]})
      assert MapSet.member?(merged.assertions, {:other_fact, ["more data"]})
      
      # Rules should be combined
      assert length(merged.rules) == 2
      
      # Parent IDs should be merged and deduplicated
      assert merged.parent_ids == [:parent_context]
      
      # Children should be merged and deduplicated
      assert merged.children == []
    end
  end
end