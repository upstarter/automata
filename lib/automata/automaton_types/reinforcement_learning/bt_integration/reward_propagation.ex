defmodule Automaton.Types.BT.Components.RewardPropagator do
  @moduledoc """
  A utility component for behavior trees that propagates rewards
  through the tree structure.
  
  This decorator-like component calculates and distributes rewards
  to reinforcement learning components based on the execution results
  of its child subtree. It enables credit assignment throughout the
  behavior tree hierarchy.
  
  Key features:
  - Propagates rewards through the behavior tree hierarchy
  - Calculates rewards based on execution results and custom metrics
  - Integrates with blackboard for reward sharing
  - Supports temporal credit assignment with delayed rewards
  - Provides success and failure reward modulation
  
  This enables behavior trees to provide proper feedback to RL components,
  creating an integrated learning system.
  """
  
  defmodule State do
    @moduledoc false
    defstruct [
      # Standard BT state
      status: :bh_fresh,
      parent: nil,
      control: 0,
      tick_freq: nil,
      child_pid: nil,           # The child node that this decorator wraps
      
      # Reward parameters
      base_success_reward: 1.0,  # Base reward for successful completion
      base_failure_reward: -0.1, # Base reward for failure
      time_penalty: 0.01,        # Penalty per time unit of execution
      reward_decay: 0.9,         # Decay factor for propagating rewards
      reward_priority: :success, # Whether to prioritize success or efficiency
      
      # Execution tracking
      start_time: nil,          # When execution started
      execution_time: 0,        # Total execution time
      execution_count: 0,       # Number of times executed
      success_count: 0,         # Number of successful executions
      failure_count: 0,         # Number of failed executions
      
      # Reward tracking
      last_reward: 0.0,         # Last calculated reward
      total_reward: 0.0,        # Cumulative reward
      reward_recipients: [],    # List of RL components to notify
      
      # Custom metrics
      custom_metrics: %{}       # Additional metrics for reward calculation
    ]
  end
  
  defmacro __using__(opts) do
    quote do
      alias Automaton.Blackboard
      
      # Initialize the reward propagator
      def on_init(state) do
        # Configure reward parameters from options
        base_success_reward = unquote(opts[:success_reward] || 1.0)
        base_failure_reward = unquote(opts[:failure_reward] || -0.1)
        time_penalty = unquote(opts[:time_penalty] || 0.01)
        reward_decay = unquote(opts[:reward_decay] || 0.9)
        reward_priority = unquote(opts[:reward_priority] || :success)
        
        # Find reward recipients (RLAction nodes that should receive rewards)
        recipients = find_reward_recipients(unquote(opts[:reward_recipients]))
        
        now = :os.system_time(:millisecond)
        
        # Initialize the child
        if state.child_pid && Process.alive?(state.child_pid) do
          GenServer.cast(state.child_pid, {:initialize, self()})
        end
        
        %{state | 
          base_success_reward: base_success_reward,
          base_failure_reward: base_failure_reward,
          time_penalty: time_penalty,
          reward_decay: reward_decay,
          reward_priority: reward_priority,
          start_time: now,
          reward_recipients: recipients
        }
      end
      
      # Main update function for the reward propagator
      def update(%{child_pid: child_pid} = state) when is_pid(child_pid) do
        # Tick the child node
        case GenServer.call(child_pid, :tick, 10_000) do
          :bh_success ->
            # Child succeeded - calculate reward and propagate
            {reward, metrics} = calculate_success_reward(state)
            propagate_reward(state.reward_recipients, reward, metrics)
            
            # Update state with success
            now = :os.system_time(:millisecond)
            execution_time = now - (state.start_time || now)
            
            updated_state = %{state | 
              status: :bh_success,
              execution_time: execution_time,
              execution_count: state.execution_count + 1,
              success_count: state.success_count + 1,
              last_reward: reward,
              total_reward: state.total_reward + reward,
              start_time: nil,
              control: state.control + 1,
              custom_metrics: metrics
            }
            
            {:ok, updated_state}
            
          :bh_failure ->
            # Child failed - calculate reward and propagate
            {reward, metrics} = calculate_failure_reward(state)
            propagate_reward(state.reward_recipients, reward, metrics)
            
            # Update state with failure
            now = :os.system_time(:millisecond)
            execution_time = now - (state.start_time || now)
            
            updated_state = %{state | 
              status: :bh_failure,
              execution_time: execution_time,
              execution_count: state.execution_count + 1,
              failure_count: state.failure_count + 1,
              last_reward: reward,
              total_reward: state.total_reward + reward,
              start_time: nil,
              control: state.control + 1,
              custom_metrics: metrics
            }
            
            {:ok, updated_state}
            
          :bh_running ->
            # Child is still running - no reward yet
            {:ok, %{state | status: :bh_running, control: state.control + 1}}
            
          unexpected ->
            # Unexpected status - treat as failure
            IO.inspect(["Unexpected status from child:", unexpected])
            {:ok, %{state | status: :bh_failure, control: state.control + 1}}
        end
      end
      
      # No child node
      def update(state) do
        {:ok, %{state | status: :bh_failure, control: state.control + 1}}
      end
      
      # Clean up on termination
      def on_terminate(state) do
        if state.status == :bh_running do
          # If we were running, calculate a partial failure reward
          {reward, metrics} = calculate_interrupted_reward(state)
          propagate_reward(state.reward_recipients, reward, metrics)
        end
        
        state.status
      end
      
      # Calculate reward for successful execution
      def calculate_success_reward(state) do
        now = :os.system_time(:millisecond)
        execution_time = now - (state.start_time || now)
        
        # Base reward for success
        base_reward = state.base_success_reward
        
        # Adjust based on execution time if efficiency is important
        time_factor =
          if state.reward_priority == :efficiency do
            # Longer execution times reduce reward
            max(0.1, 1.0 - (execution_time * state.time_penalty / 1000))
          else
            # Success priority means time matters less
            max(0.5, 1.0 - (execution_time * state.time_penalty / 2000))
          end
        
        # Adjust based on execution history
        history_factor =
          if state.execution_count > 0 do
            success_rate = state.success_count / state.execution_count
            0.5 + success_rate / 2  # Range from 0.5 to 1.0 based on success rate
          else
            1.0  # No history yet
          end
        
        # Calculate final reward
        final_reward = base_reward * time_factor * history_factor
        
        # Collect metrics for debugging and analysis
        metrics = %{
          success: true,
          execution_time: execution_time,
          time_factor: time_factor,
          history_factor: history_factor,
          success_rate: if(state.execution_count > 0, do: state.success_count / state.execution_count, else: 0),
          base_reward: base_reward
        }
        
        {final_reward, metrics}
      end
      
      # Calculate reward for failed execution
      def calculate_failure_reward(state) do
        now = :os.system_time(:millisecond)
        execution_time = now - (state.start_time || now)
        
        # Base reward for failure
        base_reward = state.base_failure_reward
        
        # Adjust based on execution time - longer failures are worse
        time_factor = max(0.5, 1.0 + (execution_time * state.time_penalty / 1000))
        
        # Adjust based on execution history - frequent failures are worse
        history_factor =
          if state.execution_count > 0 do
            failure_rate = state.failure_count / state.execution_count
            0.5 + failure_rate / 2  # Range from 0.5 to 1.0 based on failure rate
          else
            0.5  # No history yet
          end
        
        # Calculate final reward - more negative for persistent failures
        final_reward = base_reward * time_factor * history_factor
        
        # Collect metrics for debugging and analysis
        metrics = %{
          success: false,
          execution_time: execution_time,
          time_factor: time_factor,
          history_factor: history_factor,
          failure_rate: if(state.execution_count > 0, do: state.failure_count / state.execution_count, else: 0),
          base_reward: base_reward
        }
        
        {final_reward, metrics}
      end
      
      # Calculate reward for interrupted execution
      def calculate_interrupted_reward(state) do
        now = :os.system_time(:millisecond)
        execution_time = now - (state.start_time || now)
        
        # Base reward for interruption (partial failure)
        base_reward = state.base_failure_reward / 2
        
        # Adjust based on execution time
        time_factor = max(0.5, 1.0 + (execution_time * state.time_penalty / 2000))
        
        # Calculate final reward
        final_reward = base_reward * time_factor
        
        # Collect metrics for debugging and analysis
        metrics = %{
          success: false,
          interrupted: true,
          execution_time: execution_time,
          time_factor: time_factor,
          base_reward: base_reward
        }
        
        {final_reward, metrics}
      end
      
      # Find the RL components that should receive rewards
      def find_reward_recipients(specified_recipients) do
        if specified_recipients do
          # Use the specifically provided recipient list
          specified_recipients
        else
          # In a real implementation, would scan the behavior tree
          # for RL-enabled nodes or query a registry
          []
        end
      end
      
      # Propagate reward to all recipients
      def propagate_reward(recipients, reward, metrics) do
        # Write reward to blackboard for global access
        blackboard_pid = get_blackboard_pid()
        
        if blackboard_pid do
          Automaton.Blackboard.store_persistent(
            blackboard_pid,
            "reward_propagator",
            "last_reward",
            %{reward: reward, metrics: metrics, timestamp: :os.system_time(:millisecond)}
          )
        end
        
        # Send reward to each recipient
        Enum.each(recipients, fn
          {pid, type} when is_pid(pid) ->
            send_reward_to_component(pid, type, reward)
            
          pid when is_pid(pid) ->
            # Assume MAB if type not specified
            send_reward_to_component(pid, :mab, reward)
            
          other ->
            IO.inspect(["Invalid reward recipient:", other])
        end)
      end
      
      # Send reward to a specific RL component
      def send_reward_to_component(pid, type, reward) do
        case type do
          :mab ->
            # Send reward to MAB
            GenServer.cast(pid, {:reward, reward})
            
          :decpomdp ->
            # Send reward to DECPOMDP
            GenServer.cast(pid, {:update_reward, reward})
            
          :rl_action ->
            # Send reward to RLAction
            GenServer.cast(pid, {:set_reward, reward})
            
          _ ->
            # Unknown type, use generic message
            GenServer.cast(pid, {:reward, reward})
        end
      end
      
      # Get the blackboard PID for this node
      def get_blackboard_pid do
        # Try to find a registered blackboard
        case Registry.lookup(Registry.default, "global_blackboard") do
          [{pid, _}] -> pid
          _ -> nil
        end
      end
    end
  end
end