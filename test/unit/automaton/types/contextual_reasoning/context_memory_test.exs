defmodule Automata.Reasoning.Cognitive.ContextualReasoning.ContextMemoryTest do
  use ExUnit.Case, async: false
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.MemoryIntegration.ContextMemory
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.ContextManager
  
  describe "ContextMemory" do
    setup do
      # Mock perceptory for testing
      mock_perceptory = %{get_active_perceptions: fn -> [] end}
      
      # Mock perception memory
      mock_perception_memory = %{}
      
      # Mock associative memory
      mock_associative_memory = %{
        create_association: fn _, _, _, _ -> :ok end
      }
      
      # Start context manager
      {:ok, manager} = ContextManager.start_link(mock_perceptory)
      
      # Create contexts for testing
      :ok = ContextManager.create_context(
        manager,
        :work,
        "Work Context",
        "Work-related memories",
        []
      )
      
      :ok = ContextManager.create_context(
        manager,
        :home,
        "Home Context",
        "Home-related memories",
        []
      )
      
      # Create context memory system
      memory = ContextMemory.new(manager, mock_perception_memory, mock_associative_memory)
      
      # Activate contexts
      :ok = ContextManager.activate_context(manager, :work, 1.0)
      :ok = ContextManager.activate_context(manager, :home, 1.0)
      
      {:ok, memory: memory, manager: manager}
    end
    
    test "store/5 stores memory items", %{memory: memory} do
      # Store memory in global memory (no context)
      memory1 = ContextMemory.store(
        memory,
        %{type: :thought, content: "Generic idea"},
        [],
        0.9,
        %{importance: "medium"}
      )
      
      # Store memory in work context
      memory2 = ContextMemory.store(
        memory1,
        %{type: :task, content: "Complete report"},
        [:work],
        0.8,
        %{deadline: "tomorrow"}
      )
      
      # Store memory in home context
      memory3 = ContextMemory.store(
        memory2,
        %{type: :reminder, content: "Buy groceries"},
        [:home],
        0.7,
        %{priority: "high"}
      )
      
      # Store memory in multiple contexts
      memory4 = ContextMemory.store(
        memory3,
        %{type: :reminder, content: "Call Mom"},
        [:home, :work],
        0.6,
        %{priority: "medium"}
      )
      
      # Global memory should have one item
      assert MapSet.size(memory4.global_memory) == 1
      
      # Work context should have two items
      work_memories = Map.get(memory4.context_memories, :work, MapSet.new())
      assert MapSet.size(work_memories) == 2
      
      # Home context should have two items
      home_memories = Map.get(memory4.context_memories, :home, MapSet.new())
      assert MapSet.size(home_memories) == 2
      
      # Verify memory attributes
      global_memory = Enum.at(MapSet.to_list(memory4.global_memory), 0)
      assert global_memory.content.type == :thought
      assert global_memory.content.content == "Generic idea"
      assert global_memory.confidence == 0.9
      assert global_memory.metadata.importance == "medium"
      
      # Verify work memory
      work_memory = Enum.find(MapSet.to_list(work_memories), fn m -> 
        m.content.content == "Complete report" 
      end)
      assert work_memory != nil
      assert work_memory.content.type == :task
      assert work_memory.confidence == 0.8
      assert work_memory.metadata.deadline == "tomorrow"
      
      {:ok, memory: memory4}
    end
    
    test "retrieve/3 retrieves relevant memories", %{memory: memory} do
      # Store various memories
      memory = memory
      |> ContextMemory.store(%{type: :task, content: "Task 1"}, [:work], 0.9)
      |> ContextMemory.store(%{type: :task, content: "Task 2"}, [:work], 0.8)
      |> ContextMemory.store(%{type: :reminder, content: "Reminder 1"}, [:home], 0.7)
      |> ContextMemory.store(%{type: :reminder, content: "Reminder 2"}, [:home], 0.6)
      |> ContextMemory.store(%{type: :note, content: "Shared note"}, [:work, :home], 0.8)
      |> ContextMemory.store(%{type: :thought, content: "Random thought"}, [], 0.5)
      
      # Retrieve all memories
      {memories, _} = ContextMemory.retrieve(memory)
      
      # Should retrieve from active contexts and global
      assert length(memories) == 6
      
      # Retrieve with limit
      {limited, _} = ContextMemory.retrieve(memory, nil, 3)
      assert length(limited) == 3
      
      # Retrieve with query - by type
      {tasks, _} = ContextMemory.retrieve(memory, fn item -> 
        item.content.type == :task 
      end)
      
      assert length(tasks) == 2
      assert Enum.all?(tasks, fn m -> m.content.type == :task end)
      
      # Retrieve with map query
      {reminders, _} = ContextMemory.retrieve(memory, %{
        content: %{type: :reminder}
      })
      
      assert length(reminders) == 2
      assert Enum.all?(reminders, fn m -> m.content.type == :reminder end)
    end
    
    test "associate_with_context/3 associates memory with context", %{memory: memory} do
      # Store memory in global memory
      memory = ContextMemory.store(
        memory,
        %{type: :note, content: "Important note"},
        [],
        0.9
      )
      
      # Get the memory ID
      global_memory = Enum.at(MapSet.to_list(memory.global_memory), 0)
      memory_id = global_memory.id
      
      # Associate with work context
      {:ok, updated} = ContextMemory.associate_with_context(memory, memory_id, :work)
      
      # Should now be in work context
      work_memories = Map.get(updated.context_memories, :work, MapSet.new())
      work_memory = Enum.find(MapSet.to_list(work_memories), fn m -> m.id == memory_id end)
      
      assert work_memory != nil
      assert work_memory.content.content == "Important note"
      assert :work in work_memory.context_ids
      
      # Should still be in global memory
      assert Enum.any?(MapSet.to_list(updated.global_memory), fn m -> m.id == memory_id end)
    end
    
    test "associate_memories/4 creates associations between memories", %{memory: memory} do
      # Store two memories
      memory = memory
      |> ContextMemory.store(%{type: :task, content: "Write report"}, [:work], 0.9)
      |> ContextMemory.store(%{type: :document, content: "Report template"}, [:work], 0.8)
      
      # Get memory IDs
      work_memories = Map.get(memory.context_memories, :work, MapSet.new())
      [memory1, memory2] = Enum.take(MapSet.to_list(work_memories), 2)
      
      # Create association
      {:ok, updated} = ContextMemory.associate_memories(memory, memory1.id, memory2.id, true)
      
      # Get updated memories
      updated_work_memories = Map.get(updated.context_memories, :work, MapSet.new())
      updated_memory1 = Enum.find(MapSet.to_list(updated_work_memories), fn m -> m.id == memory1.id end)
      updated_memory2 = Enum.find(MapSet.to_list(updated_work_memories), fn m -> m.id == memory2.id end)
      
      # Check that associations were created
      assert memory2.id in updated_memory1.associations
      assert memory1.id in updated_memory2.associations
    end
    
    test "consolidate_memories/2 merges similar memories", %{memory: memory} do
      # Store similar memories in different contexts
      memory = memory
      |> ContextMemory.store(%{type: :reminder, content: "Buy milk"}, [:home], 0.7)
      |> ContextMemory.store(%{type: :reminder, content: "Buy milk"}, [:work], 0.8)
      
      # Consolidate memories
      consolidated = ContextMemory.consolidate_memories(memory, 1.0)
      
      # Check home context
      home_memories = Map.get(consolidated.context_memories, :home, MapSet.new())
      home_reminder = Enum.find(MapSet.to_list(home_memories), fn m -> 
        m.content.type == :reminder && m.content.content == "Buy milk"
      end)
      
      # Check work context
      work_memories = Map.get(consolidated.context_memories, :work, MapSet.new())
      work_reminder = Enum.find(MapSet.to_list(work_memories), fn m -> 
        m.content.type == :reminder && m.content.content == "Buy milk"
      end)
      
      # Should be the same memory in both contexts
      assert home_reminder != nil
      assert work_reminder != nil
      assert home_reminder.id == work_reminder.id
      
      # Should have both contexts in context_ids
      assert :home in home_reminder.context_ids
      assert :work in home_reminder.context_ids
      
      # Should have increased confidence
      assert home_reminder.confidence > 0.8
    end
    
    test "apply_decay/2 reduces confidence over time", %{memory: memory} do
      # Store memory
      memory = ContextMemory.store(
        memory,
        %{type: :note, content: "Test decay"},
        [:work],
        1.0
      )
      
      # Get original memory
      work_memories = Map.get(memory.context_memories, :work, MapSet.new())
      original = Enum.at(MapSet.to_list(work_memories), 0)
      assert original.confidence == 1.0
      
      # Apply decay
      decayed = ContextMemory.apply_decay(memory)
      
      # Get decayed memory
      decayed_work_memories = Map.get(decayed.context_memories, :work, MapSet.new())
      decayed_memory = Enum.at(MapSet.to_list(decayed_work_memories), 0)
      
      # Confidence should be reduced
      assert decayed_memory.confidence < original.confidence
      
      # Simulate passage of time
      time_in_future = DateTime.add(DateTime.utc_now(), 86400, :second)  # 1 day later
      severely_decayed = ContextMemory.apply_decay(memory, time_in_future)
      
      # Get severely decayed memory
      severely_decayed_work_memories = Map.get(severely_decayed.context_memories, :work, MapSet.new())
      severely_decayed_memory = Enum.at(MapSet.to_list(severely_decayed_work_memories), 0)
      
      # Confidence should be significantly reduced
      assert severely_decayed_memory.confidence < decayed_memory.confidence
      assert severely_decayed_memory.confidence < 0.95  # Should decay significantly after a day
    end
    
    test "integrate_perception_memories/3 integrates percept memories", %{memory: memory} do
      # Create mock perception memories
      percept_memories = [
        %{type: :visual, value: "red object", attributes: %{size: "large"}, activation: 0.9},
        %{type: :auditory, value: "loud sound", attributes: %{pitch: "high"}, activation: 0.8}
      ]
      
      # Integrate with active contexts
      integrated = ContextMemory.integrate_perception_memories(memory, percept_memories)
      
      # Check work context
      work_memories = Map.get(integrated.context_memories, :work, MapSet.new())
      assert MapSet.size(work_memories) == 2
      
      # Verify visual percept was integrated
      visual_memory = Enum.find(MapSet.to_list(work_memories), fn m -> 
        m.content.percept_type == :visual
      end)
      
      assert visual_memory != nil
      assert visual_memory.content.value == "red object"
      assert visual_memory.content.attributes.size == "large"
      assert visual_memory.confidence == 0.9
      assert :work in visual_memory.context_ids
      
      # Verify auditory percept was integrated
      auditory_memory = Enum.find(MapSet.to_list(work_memories), fn m -> 
        m.content.percept_type == :auditory
      end)
      
      assert auditory_memory != nil
      assert auditory_memory.content.value == "loud sound"
      assert auditory_memory.content.attributes.pitch == "high"
      assert auditory_memory.confidence == 0.8
      assert :work in auditory_memory.context_ids
      
      # Integrate with specific context
      specific_integrated = ContextMemory.integrate_perception_memories(memory, percept_memories, :home)
      
      # Check home context
      home_memories = Map.get(specific_integrated.context_memories, :home, MapSet.new())
      assert MapSet.size(home_memories) == 2
      
      # Work context should be empty
      work_memories_specific = Map.get(specific_integrated.context_memories, :work, MapSet.new())
      assert MapSet.size(work_memories_specific) == 0
    end
  end
end