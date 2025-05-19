defmodule Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Sequence do
  @moduledoc """
  Sequence node for behavior trees.
  
  A sequence node executes its children in order until one fails or all succeed.
  If any child fails, the sequence fails. If all children succeed, the sequence succeeds.
  """
  
  use Automata.Infrastructure.AgentSystem.Types.BehaviorTree.NodeType
  require Logger
  
  @impl true
  def init(config) do
    state = %{
      status: :bh_fresh,
      current_child_index: 0,
      children_results: []
    }
    
    {:ok, state}
  end
  
  @impl true
  def evaluate(state, context) do
    # Get current status to determine action
    case state.status do
      :bh_fresh ->
        # Starting a new sequence
        if context.blackboard[:children] && length(context.blackboard[:children]) > 0 do
          # Children exist, evaluate first child
          evaluate_first_child(state, context)
        else
          # No children, sequence succeeds trivially
          {
            :bh_success,
            %{state | status: :bh_success},
            context.blackboard
          }
        end
        
      :bh_running ->
        # Continuing a sequence in progress
        evaluate_next_child(state, context)
        
      terminal_status when terminal_status in [:bh_success, :bh_failure] ->
        # Sequence already completed
        {
          terminal_status,
          state,
          context.blackboard
        }
    end
  end
  
  @impl true
  def reset(state) do
    {:ok, %{
      status: :bh_fresh,
      current_child_index: 0,
      children_results: []
    }}
  end
  
  # Private helpers
  
  defp evaluate_first_child(state, context) do
    # Start with first child
    children = context.blackboard[:children] || []
    
    if length(children) > 0 do
      child = Enum.at(children, 0)
      child_context = context
      
      case child.module.evaluate(child.state, child_context) do
        {:bh_success, updated_child_state, updated_blackboard} ->
          # Child succeeded, update its state
          updated_child = %{child | state: updated_child_state, status: :bh_success}
          updated_children = List.replace_at(children, 0, updated_child)
          
          # Check if there are more children
          if length(children) > 1 do
            # More children, move to next
            {
              :bh_running,
              %{state |
                status: :bh_running,
                current_child_index: 1,
                children_results: [:bh_success]
              },
              Map.put(updated_blackboard, :children, updated_children)
            }
          else
            # No more children, sequence succeeds
            {
              :bh_success,
              %{state |
                status: :bh_success,
                current_child_index: 1,
                children_results: [:bh_success]
              },
              Map.put(updated_blackboard, :children, updated_children)
            }
          end
          
        {:bh_running, updated_child_state, updated_blackboard} ->
          # Child is still running
          updated_child = %{child | state: updated_child_state, status: :bh_running}
          updated_children = List.replace_at(children, 0, updated_child)
          
          {
            :bh_running,
            %{state |
              status: :bh_running,
              current_child_index: 0,
              children_results: []
            },
            Map.put(updated_blackboard, :children, updated_children)
          }
          
        {_failure, updated_child_state, updated_blackboard} ->
          # Child failed, sequence fails
          updated_child = %{child | state: updated_child_state, status: :bh_failure}
          updated_children = List.replace_at(children, 0, updated_child)
          
          {
            :bh_failure,
            %{state |
              status: :bh_failure,
              current_child_index: 0,
              children_results: [:bh_failure]
            },
            Map.put(updated_blackboard, :children, updated_children)
          }
      end
    else
      # No children, sequence succeeds trivially
      {
        :bh_success,
        %{state | status: :bh_success},
        context.blackboard
      }
    end
  end
  
  defp evaluate_next_child(state, context) do
    # Get current child
    children = context.blackboard[:children] || []
    current_index = state.current_child_index
    
    if current_index < length(children) do
      child = Enum.at(children, current_index)
      child_context = context
      
      case child.module.evaluate(child.state, child_context) do
        {:bh_success, updated_child_state, updated_blackboard} ->
          # Child succeeded, update its state
          updated_child = %{child | state: updated_child_state, status: :bh_success}
          updated_children = List.replace_at(children, current_index, updated_child)
          
          # Update children results
          updated_results = state.children_results ++ [:bh_success]
          
          # Check if there are more children
          if current_index + 1 < length(children) do
            # More children, move to next
            {
              :bh_running,
              %{state |
                current_child_index: current_index + 1,
                children_results: updated_results
              },
              Map.put(updated_blackboard, :children, updated_children)
            }
          else
            # No more children, sequence succeeds
            {
              :bh_success,
              %{state |
                status: :bh_success,
                children_results: updated_results
              },
              Map.put(updated_blackboard, :children, updated_children)
            }
          end
          
        {:bh_running, updated_child_state, updated_blackboard} ->
          # Child is still running
          updated_child = %{child | state: updated_child_state, status: :bh_running}
          updated_children = List.replace_at(children, current_index, updated_child)
          
          {
            :bh_running,
            state,
            Map.put(updated_blackboard, :children, updated_children)
          }
          
        {_failure, updated_child_state, updated_blackboard} ->
          # Child failed, sequence fails
          updated_child = %{child | state: updated_child_state, status: :bh_failure}
          updated_children = List.replace_at(children, current_index, updated_child)
          
          # Update children results
          updated_results = state.children_results ++ [:bh_failure]
          
          {
            :bh_failure,
            %{state |
              status: :bh_failure,
              children_results: updated_results
            },
            Map.put(updated_blackboard, :children, updated_children)
          }
      end
    else
      # No more children, sequence succeeds
      {
        :bh_success,
        %{state | status: :bh_success},
        context.blackboard
      }
    end
  end
end