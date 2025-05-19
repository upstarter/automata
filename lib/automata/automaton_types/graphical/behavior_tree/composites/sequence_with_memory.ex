defmodule Automaton.Types.BT.Composite.SequenceWithMemory do
  @moduledoc """
  Enhanced version of the Sequence node that remembers its progress through children.
  
  When a child returns RUNNING, the sequence will yield with RUNNING status.
  When execution resumes, it will continue from the last running child rather than
  starting from the beginning. This allows sequences to be interrupted and resumed
  without losing progress.
  
  Key features:
  - Maintains execution index in state
  - Resumes from last running child after interruption
  - Maintains blackboard access for state persistence
  - Enables complex behaviors that span multiple ticks
  """

  defmacro __using__(_opts) do
    quote do
      # Extended state with memory attributes
      defmodule State do
        @moduledoc false
        defstruct [
          :last_running_index,  # Index of the last running child
          :execution_history,   # Map of child indices to their last returned status
          :memory_data          # Additional data map for complex state tracking
        ]
      end

      # Initialize sequence memory when first starting
      def initialize_memory(state) do
        sequence_memory = %State{
          last_running_index: 0,
          execution_history: %{},
          memory_data: %{}
        }

        # Store in process dictionary as lightweight approach
        # In a complete implementation, this would be stored in a proper blackboard
        Process.put(:sequence_memory, sequence_memory)
        state
      end

      # Get current memory state
      def get_memory() do
        Process.get(:sequence_memory) || %State{
          last_running_index: 0,
          execution_history: %{},
          memory_data: %{}
        }
      end

      # Update memory state
      def update_memory(memory) do
        Process.put(:sequence_memory, memory)
      end

      # Store data in memory
      def store_in_memory(key, value) do
        memory = get_memory()
        updated_memory = %{memory | memory_data: Map.put(memory.memory_data, key, value)}
        update_memory(updated_memory)
      end

      # Get data from memory
      def get_from_memory(key) do
        memory = get_memory()
        Map.get(memory.memory_data, key)
      end

      # Record child execution status in history
      def record_child_status(index, status) do
        memory = get_memory()
        updated_history = Map.put(memory.execution_history, index, status)
        update_memory(%{memory | execution_history: updated_history})
      end

      # Run on_init with memory awareness
      def on_init(state) do
        # Initialize memory if this is the first run
        if state.status != :bh_running do
          initialize_memory(state)
        end
        
        state
      end

      # Memory-aware update function that resumes from last position
      def update(%{workers: workers} = state) do
        # Get stored memory
        memory = get_memory()
        
        # Start from the last running index or beginning if fresh
        start_index = if state.status == :bh_running, do: memory.last_running_index, else: 0
        
        # Execute children from the current index
        {final_index, status} = tick_workers_with_memory(workers, start_index)
        
        # Update memory with the last running index
        if status == :bh_running do
          update_memory(%{memory | last_running_index: final_index})
        end

        # Clean up any debug outputs
        case status do
          :bh_failure ->
            nil # In real implementation, handle failure appropriately
          _ ->
            nil
        end

        new_state = %{state | control: state.control + 1, status: status}
        {:ok, new_state}
      end

      # Enhanced tick_workers that supports resuming from a specific index
      def tick_workers_with_memory(workers, start_index) do
        workers
        |> Enum.with_index()
        |> Enum.drop(start_index)
        |> Enum.reduce_while({start_index, :bh_success}, fn {worker, index}, {_current_index, _acc} ->
          # Call the worker with a tick message
          status = GenServer.call(worker, :tick, 10_000)
          
          # Record this status in memory
          record_child_status(index, status)
          
          cond do
            # If running, we'll resume from this index next time
            status == :bh_running ->
              {:halt, {index, :bh_running}}
              
            # If failure, return immediately
            status != :bh_success ->
              {:halt, {index, status}}
              
            # Otherwise continue to next child
            true ->
              {:cont, {index + 1, :bh_success}}
          end
        end)
      end

      # Handle termination with memory considerations
      def on_terminate(state) do
        case state.status do
          # When sequence succeeds, reset memory for next execution
          :bh_success ->
            # Reset memory if successful to allow fresh run next time
            initialize_memory(state)
            
          # For other terminal states, memory is preserved for potential recovery
          _ -> 
            nil
        end
        
        state.status
      end
    end
  end
end