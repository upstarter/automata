defmodule Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagerTest do
  use ExUnit.Case, async: false
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.Context
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.ContextManager
  
  describe "ContextManager" do
    setup do
      # Mock perceptory for testing
      mock_perceptory = %{get_active_perceptions: fn -> [] end}
      
      # Start context manager
      {:ok, manager} = ContextManager.start_link(mock_perceptory)
      
      # Create test contexts
      :ok = ContextManager.create_context(
        manager,
        :work_context,
        "Work Context",
        "Context for work-related activities",
        [],
        %{location: "office"},
        MapSet.new([{:activity, ["working"]}])
      )
      
      :ok = ContextManager.create_context(
        manager,
        :home_context,
        "Home Context",
        "Context for home-related activities",
        [],
        %{location: "home"},
        MapSet.new([{:activity, ["relaxing"]}])
      )
      
      # Child context
      :ok = ContextManager.create_context(
        manager,
        :meeting_context,
        "Meeting Context",
        "Context for meetings",
        [:work_context],  # Parent is work context
        %{activity: "discussion"},
        MapSet.new([{:activity, ["meeting"]}])
      )
      
      {:ok, manager: manager}
    end
    
    test "create_context/8 creates contexts properly", %{manager: manager} do
      # Verify contexts exist
      work_context = ContextManager.get_context(manager, :work_context)
      home_context = ContextManager.get_context(manager, :home_context)
      meeting_context = ContextManager.get_context(manager, :meeting_context)
      
      assert work_context != nil
      assert home_context != nil
      assert meeting_context != nil
      
      # Verify parent-child relationship
      assert :meeting_context in work_context.children
      assert meeting_context.parent_ids == [:work_context]
      
      # Try to create duplicate context
      result = ContextManager.create_context(
        manager,
        :work_context,
        "Duplicate",
        "Should fail",
        []
      )
      
      assert result == {:error, :context_exists}
    end
    
    test "get_context/2 retrieves contexts", %{manager: manager} do
      work_context = ContextManager.get_context(manager, :work_context)
      
      assert work_context.name == "Work Context"
      assert work_context.parameters.location == "office"
      
      # Non-existent context
      assert ContextManager.get_context(manager, :nonexistent) == nil
    end
    
    test "activate_context/3 activates contexts", %{manager: manager} do
      # Initially all contexts inactive
      active_contexts = ContextManager.get_active_contexts(manager)
      assert length(active_contexts) == 0
      
      # Activate work context
      :ok = ContextManager.activate_context(manager, :work_context, 0.8)
      
      active_contexts = ContextManager.get_active_contexts(manager)
      assert length(active_contexts) == 1
      assert hd(active_contexts).id == :work_context
      assert hd(active_contexts).activation == 0.8
      
      # Activate another context
      :ok = ContextManager.activate_context(manager, :home_context, 0.6)
      
      active_contexts = ContextManager.get_active_contexts(manager)
      assert length(active_contexts) == 2
      
      # Try to activate non-existent context
      result = ContextManager.activate_context(manager, :nonexistent, 1.0)
      assert result == {:error, :context_not_found}
    end
    
    test "deactivate_context/3 deactivates contexts", %{manager: manager} do
      # Activate contexts first
      :ok = ContextManager.activate_context(manager, :work_context, 0.8)
      :ok = ContextManager.activate_context(manager, :home_context, 0.7)
      
      active_contexts = ContextManager.get_active_contexts(manager)
      assert length(active_contexts) == 2
      
      # Deactivate one context
      :ok = ContextManager.deactivate_context(manager, :work_context, 0.9)
      
      active_contexts = ContextManager.get_active_contexts(manager)
      assert length(active_contexts) == 1
      assert hd(active_contexts).id == :home_context
      
      # Try to deactivate non-existent context
      result = ContextManager.deactivate_context(manager, :nonexistent, 1.0)
      assert result == {:error, :context_not_found}
    end
    
    test "update_context/2 updates context", %{manager: manager} do
      work_context = ContextManager.get_context(manager, :work_context)
      
      # Modify context
      updated_context = %{work_context | 
        description: "Updated description",
        parameters: Map.put(work_context.parameters, :new_param, "value")
      }
      
      :ok = ContextManager.update_context(manager, updated_context)
      
      # Verify update
      retrieved = ContextManager.get_context(manager, :work_context)
      assert retrieved.description == "Updated description"
      assert retrieved.parameters.new_param == "value"
      
      # Try to update non-existent context
      nonexistent = %Context{id: :nonexistent}
      result = ContextManager.update_context(manager, nonexistent)
      assert result == {:error, :context_not_found}
    end
    
    test "add_assertion/3 adds assertions to contexts", %{manager: manager} do
      :ok = ContextManager.add_assertion(manager, :work_context, {:task, ["complete report"]})
      
      work_context = ContextManager.get_context(manager, :work_context)
      assert MapSet.member?(work_context.assertions, {:task, ["complete report"]})
      
      # Try with non-existent context
      result = ContextManager.add_assertion(manager, :nonexistent, {:test, []})
      assert result == {:error, :context_not_found}
    end
    
    test "predict_context_activations/2 predicts based on percepts", %{manager: manager} do
      # Create test percepts
      work_percepts = [
        %{type: :location, value: "office", attributes: %{}, id: "loc1"},
        %{type: :activity, value: "working", attributes: %{}, id: "act1"}
      ]
      
      # Get predictions
      predictions = ContextManager.predict_context_activations(manager, work_percepts)
      
      # Work context should have higher prediction than home context
      assert predictions[:work_context] > predictions[:home_context]
    end
    
    test "switch_context_from_percepts/2 changes active contexts", %{manager: manager} do
      # Initially no active contexts
      assert length(ContextManager.get_active_contexts(manager)) == 0
      
      # Create work-related percepts
      work_percepts = [
        %{type: :location, value: "office", attributes: %{}, id: "loc1"},
        %{type: :activity, value: "working", attributes: %{}, id: "act1"}
      ]
      
      # Switch context based on percepts
      ContextManager.switch_context_from_percepts(manager, work_percepts)
      
      # Wait a moment for async processing
      :timer.sleep(100)
      
      # Work context should be active now
      active_contexts = ContextManager.get_active_contexts(manager)
      active_ids = Enum.map(active_contexts, & &1.id)
      assert :work_context in active_ids
      
      # Now switch to home percepts
      home_percepts = [
        %{type: :location, value: "home", attributes: %{}, id: "loc2"},
        %{type: :activity, value: "relaxing", attributes: %{}, id: "act2"}
      ]
      
      ContextManager.switch_context_from_percepts(manager, home_percepts)
      
      # Wait a moment for async processing
      :timer.sleep(100)
      
      # Home context should be active, work context deactivated
      active_contexts = ContextManager.get_active_contexts(manager)
      active_ids = Enum.map(active_contexts, & &1.id)
      assert :home_context in active_ids
      assert :work_context not in active_ids
    end
    
    test "enforce_max_active_contexts when too many contexts active", %{manager: manager} do
      # Create additional contexts to exceed the limit
      for i <- 1..6 do
        :ok = ContextManager.create_context(
          manager,
          String.to_atom("context_#{i}"),
          "Test Context #{i}",
          "Test context #{i}",
          [],
          %{}
        )
      end
      
      # Activate all contexts
      for i <- 1..6 do
        :ok = ContextManager.activate_context(manager, String.to_atom("context_#{i}"), 0.5 + i/10)
      end
      
      # Activate original contexts
      :ok = ContextManager.activate_context(manager, :work_context, 0.6)
      :ok = ContextManager.activate_context(manager, :home_context, 0.7)
      :ok = ContextManager.activate_context(manager, :meeting_context, 0.8)
      
      # The default max_active_contexts is 5, so only 5 should be active
      active_contexts = ContextManager.get_active_contexts(manager)
      assert length(active_contexts) == 5
      
      # The highest activation contexts should remain active
      active_ids = Enum.map(active_contexts, & &1.id)
      assert :meeting_context in active_ids  # Highest activation
      assert :home_context in active_ids     # Second highest
    end
    
    test "decay is applied to contexts over time", %{manager: manager} do
      # Activate a context
      :ok = ContextManager.activate_context(manager, :work_context, 1.0)
      
      work_context = ContextManager.get_context(manager, :work_context)
      assert work_context.activation == 1.0
      
      # Wait for decay to be applied
      :timer.sleep(1100)  # Decay interval is 1000ms
      
      # Context should have decayed
      work_context_after = ContextManager.get_context(manager, :work_context)
      assert work_context_after.activation < 1.0
    end
  end
end