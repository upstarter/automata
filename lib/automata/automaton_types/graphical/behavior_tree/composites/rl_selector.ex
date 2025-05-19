defmodule Automaton.Types.BT.Composite.RLSelector do
  @moduledoc """
  A reinforcement learning enhanced selector composite for behavior trees.
  
  The RLSelector uses a Multi-Armed Bandit algorithm to dynamically choose
  which child to execute, learning over time which children tend to succeed
  in different situations. This enables adaptive behavior that improves with
  experience, unlike the standard Selector which always tries children in
  a fixed left-to-right order.
  
  Key features:
  - Epsilon-greedy exploration/exploitation strategy
  - Learns which child nodes are more likely to succeed
  - Maintains reward statistics per child
  - Adapts to changing conditions over time with decay parameters
  - Integrates RL concepts into the behavior tree framework
  
  This implementation bridges the gap between structured behavior trees
  and adaptive reinforcement learning, enabling agents to combine the
  benefits of both approaches.
  """
  
  defmodule State do
    @moduledoc false
    
    defstruct [
      # Standard BT selector state
      status: :bh_fresh,
      parent: nil,
      control: 0,
      tick_freq: nil,
      
      # Child management
      workers: [],    # PIDs of child processes
      last_active: nil, # PID of the last active child
      
      # RL-specific state
      action_values: nil,    # Q-values for each child (Matrex)
      action_counts: nil,    # Number of times each child was selected
      total_reward: 0.0,     # Total accumulated reward
      epsilon: 0.3,          # Exploration rate (0.0-1.0)
      epsilon_decay: 0.995,  # Rate at which epsilon decreases over time
      min_epsilon: 0.05,     # Minimum exploration rate
      learning_rate: 0.1,    # Alpha parameter for Q-value updates
      reward_window: [],     # Recent rewards for tracking performance
      reward_window_size: 20 # Size of the sliding window for rewards
    ]
  end
  
  defmacro __using__(_opts) do
    quote do
      alias Matrex
      
      # Initialize RL state when the selector is first created
      def init_rl_state(%{workers: workers} = state) do
        num_children = length(workers)
        
        %{state |
          # Initialize Q-values for all children to 0.5 (moderate optimism)
          action_values: Matrex.fill(1, num_children, 0.5),
          # Initialize action counts to zeros
          action_counts: Matrex.zeros(1, num_children),
          # Reset other RL state
          total_reward: 0.0,
          reward_window: []
        }
      end
      
      # Standard BT on_init callback
      def on_init(state) do
        case state.status do
          :bh_fresh -> 
            # Initialize the RL state for a fresh execution
            init_rl_state(state)
          
          _ -> state
        end
      end
      
      # Main update function for the RL-Selector
      def update(%{workers: workers} = state) do
        if workers == [] do
          # No children to execute
          {:ok, %{state | status: :bh_failure, control: state.control + 1}}
        else
          # Select and execute a child based on RL policy
          {worker_index, selected_worker} = select_child(state)
          
          # Execute the selected child
          case tick_worker(selected_worker) do
            {:bh_success, _} = result ->
              # Child succeeded - update RL state with positive reward
              updated_state = update_rl_state(state, worker_index, 1.0, result)
              {:ok, %{updated_state | status: :bh_success, control: updated_state.control + 1}}
              
            {:bh_running, _} = result ->
              # Child is still running - no reward update yet
              updated_state = %{state | last_active: selected_worker}
              {:ok, %{updated_state | status: :bh_running, control: updated_state.control + 1}}
              
            {:bh_failure, _} ->
              # Child failed - try again with remaining workers if exploration is happening
              if :rand.uniform() < state.epsilon do
                # During exploration, try another child if available
                remaining_workers = workers -- [selected_worker]
                
                if remaining_workers == [] do
                  # No more children to try - update with negative reward
                  updated_state = update_rl_state(state, worker_index, -0.1, {:bh_failure, nil})
                  {:ok, %{updated_state | status: :bh_failure, control: updated_state.control + 1}}
                else
                  # Try another random child
                  update(%{state | workers: remaining_workers})
                end
              else
                # During exploitation, accept the failure and learn from it
                updated_state = update_rl_state(state, worker_index, -0.1, {:bh_failure, nil})
                {:ok, %{updated_state | status: :bh_failure, control: updated_state.control + 1}}
              end
              
            other ->
              # Unexpected result - treat as failure
              IO.inspect(["Unexpected result from child tick:", other])
              updated_state = update_rl_state(state, worker_index, -0.5, {:bh_failure, nil})
              {:ok, %{updated_state | status: :bh_failure, control: updated_state.control + 1}}
          end
        end
      end
      
      # Select a child based on epsilon-greedy policy
      def select_child(%{workers: workers, action_values: action_values, epsilon: epsilon} = _state) do
        if :rand.uniform() < epsilon do
          # Exploration - choose a random child
          index = :rand.uniform(length(workers)) - 1
          {index, Enum.at(workers, index)}
        else
          # Exploitation - choose the child with the highest action value
          best_index = Matrex.argmax(action_values) - 1  # Matrex is 1-indexed
          {best_index, Enum.at(workers, best_index)}
        end
      end
      
      # Tick a single worker and return its status
      def tick_worker(worker_pid) do
        try do
          status = GenServer.call(worker_pid, :tick, 10_000)
          {status, worker_pid}
        catch
          :exit, reason ->
            IO.inspect(["Worker failed during tick:", worker_pid, reason])
            {:bh_failure, worker_pid}
        end
      end
      
      # Update RL state based on execution results
      def update_rl_state(%{action_values: action_values, action_counts: action_counts, 
                            epsilon: epsilon, epsilon_decay: epsilon_decay, 
                            min_epsilon: min_epsilon, learning_rate: alpha} = state, 
                          child_index, reward, _result) do
        # Get current action index (0-based for Enum, 1-based for Matrex)
        matrex_index = child_index + 1
        
        # Update action count for this child
        new_count = Matrex.at(action_counts, 1, matrex_index) + 1
        updated_counts = Matrex.set(action_counts, 1, matrex_index, new_count)
        
        # Update action value using Q-learning update rule
        current_q = Matrex.at(action_values, 1, matrex_index)
        new_q = current_q + alpha * (reward - current_q)
        updated_values = Matrex.set(action_values, 1, matrex_index, new_q)
        
        # Update epsilon with decay
        new_epsilon = max(min_epsilon, epsilon * epsilon_decay)
        
        # Update reward window
        new_window = [reward | state.reward_window] |> Enum.take(state.reward_window_size)
        new_total = state.total_reward + reward
        
        # Return updated state
        %{state | 
          action_values: updated_values,
          action_counts: updated_counts,
          epsilon: new_epsilon,
          reward_window: new_window,
          total_reward: new_total
        }
      end
      
      # Terminate handler to perform any cleanup
      def on_terminate(state) do
        case state.status do
          :bh_running ->
            IO.inspect("RL-SELECTOR TERMINATED - RUNNING",
              label: Process.info(self())[:registered_name]
            )
            
          :bh_failure ->
            IO.inspect("RL-SELECTOR TERMINATED - FAILED",
              label: Process.info(self())[:registered_name]
            )
            
          :bh_success ->
            IO.inspect(["RL-SELECTOR TERMINATED - SUCCEEDED"],
              label: Process.info(self())[:registered_name]
            )
            
          :bh_aborted ->
            IO.inspect("RL-SELECTOR TERMINATED - ABORTED",
              label: Process.info(self())[:registered_name]
            )
            
          :bh_fresh ->
            IO.inspect("RL-SELECTOR TERMINATED - FRESH",
              label: Process.info(self())[:registered_name]
            )
        end
        
        # Return final status
        state.status
      end
      
      # Handle blackboard integration for persisting learning
      def persist_learning_state(state, blackboard_pid, node_id) do
        # Store action values and other RL state in blackboard for persistence
        # This allows learning to continue across multiple behavior tree executions
        Automaton.Blackboard.store_persistent(
          blackboard_pid,
          "rl_selector_#{node_id}",
          "action_values",
          Matrex.to_list(state.action_values)
        )
        
        Automaton.Blackboard.store_persistent(
          blackboard_pid,
          "rl_selector_#{node_id}",
          "action_counts",
          Matrex.to_list(state.action_counts)
        )
        
        Automaton.Blackboard.store_persistent(
          blackboard_pid,
          "rl_selector_#{node_id}",
          "total_reward",
          state.total_reward
        )
        
        state
      end
      
      # Load learning state from blackboard
      def load_learning_state(state, blackboard_pid, node_id) do
        # Try to retrieve previous learning state from blackboard
        case Automaton.Blackboard.get_persistent(blackboard_pid, "rl_selector_#{node_id}", "action_values") do
          {:ok, nil} ->
            # No previous state found, return as is
            state
            
          {:ok, action_values_list} ->
            # Convert list back to Matrex and restore state
            action_values = Matrex.from_list(action_values_list)
            
            {:ok, action_counts_list} = Automaton.Blackboard.get_persistent(
              blackboard_pid, "rl_selector_#{node_id}", "action_counts"
            )
            action_counts = Matrex.from_list(action_counts_list)
            
            {:ok, total_reward} = Automaton.Blackboard.get_persistent(
              blackboard_pid, "rl_selector_#{node_id}", "total_reward"
            )
            
            %{state | 
              action_values: action_values,
              action_counts: action_counts,
              total_reward: total_reward
            }
            
          {:error, _} ->
            # Error retrieving state, initialize fresh
            state
        end
      end
      
      # Calculate the average reward over the last N executions
      def average_reward(%{reward_window: window}) do
        if window == [] do
          0.0
        else
          Enum.sum(window) / length(window)
        end
      end
      
      # Get stats about the learning progress
      def get_learning_stats(state) do
        %{
          average_reward: average_reward(state),
          total_reward: state.total_reward,
          epsilon: state.epsilon,
          action_counts: Matrex.to_list(state.action_counts),
          action_values: Matrex.to_list(state.action_values)
        }
      end
    end
  end
end