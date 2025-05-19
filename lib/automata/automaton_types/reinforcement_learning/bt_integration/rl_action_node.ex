defmodule Automaton.Types.BT.Components.RLAction do
  @moduledoc """
  A reinforcement learning-enhanced action node for behavior trees.
  
  This specialized action node integrates with reinforcement learning components
  (MAB or DECPOMDP) to select actions based on learned policies. This creates an
  integration layer between the structured behavior tree system and the adaptive
  reinforcement learning system.
  
  Key capabilities:
  
  1. Environment observation - Captures current state for RL decision making
  2. Policy-based action selection - Selects actions using RL policy
  3. Reward processing - Provides feedback to the RL system about action outcomes
  4. Learning persistence - Maintains learning across behavior tree executions
  
  This component bridges the gap between symbolic reasoning (behavior trees)
  and statistical learning (reinforcement learning), creating a hybrid AI system.
  """
  
  defmodule State do
    @moduledoc false
    defstruct [
      # Standard BT action state
      status: :bh_fresh,
      parent: nil,
      control: 0,
      tick_freq: nil,
      
      # RL-specific state
      rl_type: :mab,             # Type of RL component (:mab or :decpomdp)
      rl_pid: nil,               # PID of the RL component
      agent_id: nil,             # Agent ID for DECPOMDP integration
      current_action: nil,       # Currently selected action
      current_observation: nil,  # Current observation of the environment
      last_reward: 0.0,          # Last received reward
      cumulative_reward: 0.0,    # Total reward accumulated
      success_reward: 1.0,       # Reward value for success
      failure_reward: -0.1,      # Reward value for failure
      parameters: %{}            # Additional parameters for action execution
    ]
  end
  
  defmacro __using__(opts) do
    quote do
      alias Automaton.Types.MAB
      alias Automaton.Types.DECPOMDP
      alias Automaton.Blackboard
      
      # Initialize RL action state
      def on_init(state) do
        # Initialize first time
        if state.status == :bh_fresh do
          # Set up RL component based on configuration
          rl_type = unquote(opts[:rl_type] || :mab)
          agent_id = unquote(opts[:agent_id] || "agent_1")
          success_reward = unquote(opts[:success_reward] || 1.0)
          failure_reward = unquote(opts[:failure_reward] || -0.1)
          
          # Get RL component PID 
          rl_pid = get_rl_component_pid(rl_type, unquote(opts[:rl_pid]))
          
          # Initialize with sensory observation
          current_observation = observe_environment()
          
          # Initialize action
          {current_action, _} = select_action(rl_type, rl_pid, agent_id, current_observation)
          
          # Return updated state
          %{state | 
            rl_type: rl_type,
            rl_pid: rl_pid,
            agent_id: agent_id,
            current_action: current_action,
            current_observation: current_observation,
            success_reward: success_reward,
            failure_reward: failure_reward
          }
        else
          # Already initialized, just update observation
          current_observation = observe_environment()
          %{state | current_observation: current_observation}
        end
      end
      
      # Main update function for the RL action node
      def update(state) do
        # Select an action if we don't have one yet
        {action, updated_state} = if state.current_action == nil do
          action = select_action(
            state.rl_type, 
            state.rl_pid, 
            state.agent_id, 
            state.current_observation
          )
          {action, %{state | current_action: action}}
        else
          {state.current_action, state}
        end
        
        # Execute the selected action
        result = execute_action(action, updated_state.parameters)
        
        case result do
          {:success, params} ->
            # Action succeeded, provide positive reward
            send_reward(updated_state.rl_type, updated_state.rl_pid, updated_state.success_reward)
            
            final_state = %{updated_state | 
              status: :bh_success, 
              current_action: nil,
              last_reward: updated_state.success_reward,
              cumulative_reward: updated_state.cumulative_reward + updated_state.success_reward,
              parameters: params,
              control: updated_state.control + 1
            }
            
            {:ok, final_state}
            
          {:failure, params} ->
            # Action failed, provide negative reward
            send_reward(updated_state.rl_type, updated_state.rl_pid, updated_state.failure_reward)
            
            final_state = %{updated_state | 
              status: :bh_failure, 
              current_action: nil,
              last_reward: updated_state.failure_reward,
              cumulative_reward: updated_state.cumulative_reward + updated_state.failure_reward,
              parameters: params,
              control: updated_state.control + 1
            }
            
            {:ok, final_state}
            
          {:running, params} ->
            # Action still running, no reward yet
            final_state = %{updated_state | 
              status: :bh_running,
              parameters: params,
              control: updated_state.control + 1
            }
            
            {:ok, final_state}
        end
      end
      
      # Clean up on action termination
      def on_terminate(state) do
        if state.status == :bh_running do
          # If we were interrupted while running, send a small negative reward
          send_reward(state.rl_type, state.rl_pid, state.failure_reward / 2)
        end
        
        state.status
      end
      
      # Get the PID of the appropriate RL component
      def get_rl_component_pid(rl_type, specified_pid) do
        cond do
          # Use the specified PID if provided
          specified_pid != nil ->
            specified_pid
            
          # Try to find the appropriate module based on type
          rl_type == :mab ->
            # Look for a MAB instance in the registry
            case Registry.lookup(Registry.default, "mab_agent") do
              [{pid, _}] -> pid
              _ -> nil
            end
            
          rl_type == :decpomdp ->
            # Look for a DECPOMDP instance in the registry
            case Registry.lookup(Registry.default, "decpomdp_agent") do
              [{pid, _}] -> pid
              _ -> nil
            end
            
          true ->
            nil
        end
      end
      
      # Select an action using the appropriate RL component
      def select_action(rl_type, rl_pid, agent_id, observation) do
        cond do
          rl_pid == nil ->
            # No RL component, use fallback action
            default_action = :default_action
            {default_action, nil}
            
          rl_type == :mab ->
            # Use MAB to select action
            # Call the MAB's epsilon-greedy policy to select an action
            action = GenServer.call(rl_pid, :follow_policy)
            {action, nil}
            
          rl_type == :decpomdp ->
            # Use DECPOMDP to select action based on current observation
            # First update the belief state with new observation
            action = DECPOMDP.bt_select_action(rl_pid, agent_id, observation)
            {action, nil}
            
          true ->
            # Unknown RL type, use fallback
            default_action = :default_action
            {default_action, nil}
        end
      end
      
      # Send reward to the RL component
      def send_reward(rl_type, rl_pid, reward) do
        if rl_pid != nil do
          case rl_type do
            :mab ->
              # Send reward to MAB
              GenServer.cast(rl_pid, {:reward, reward})
              
            :decpomdp ->
              # Send reward to DECPOMDP
              DECPOMDP.bt_update_reward(rl_pid, reward)
              
            _ ->
              nil
          end
        end
      end
      
      # Observe the current environment state
      def observe_environment do
        # In a real implementation, this would gather information from:
        # - Blackboard data
        # - Agent perception
        # - Environment state
        # - Other context information
        
        # For this example, create a simple observation
        %{
          position: {0, 0, 0},  # Example position
          targets: [],          # Example targets
          resources: 100,       # Example resource level
          health: 100,          # Example health level
          timestamp: :os.system_time(:millisecond)
        }
      end
      
      # Execute the selected action
      def execute_action(action, parameters) do
        # This method should be overridden in specific implementations
        # to provide actual action execution logic
        
        # For the base implementation, just return success
        {:success, parameters}
      end
      
      # Override this method in specific implementations to provide
      # action-specific execution logic
      defoverridable execute_action: 2
    end
  end
end