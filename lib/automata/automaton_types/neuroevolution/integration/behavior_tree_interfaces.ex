defmodule Automaton.Types.TWEANN.Integration.BehaviorTreeInterfaces do
  @moduledoc """
  Provides interfaces for integrating neural networks with behavior trees.
  
  This module facilitates the connection between evolved neural networks and
  the behavior tree decision-making system, enabling:
  
  - Neural-guided action selection
  - Neural condition evaluation
  - Neural modulation of behavior tree execution
  - Bidirectional feedback between neural networks and behavior trees
  """
  
  alias Automaton.Types.BT.BehaviorTree
  alias Automaton.Types.BT.Neural.NeuralSelector
  alias Automaton.Types.BT.Neural.NeuralAction
  alias Automaton.Types.BT.Neural.NeuralCondition
  alias Automaton.Types.BT.Neural.NeuralDecorator
  alias Automata.Reasoning.Cognitive.NeuroIntegration.PerceptionAdapter
  alias Automata.Reasoning.Cognitive.NeuroIntegration.NeuralDecisionMaker
  
  require Logger
  
  @doc """
  Creates a neural-guided selector node.
  
  This factory function creates a selector node that uses a neural network
  to decide which child to execute.
  
  ## Parameters
  - id: Unique identifier for the node
  - network_file: Path to neural network file
  - perception_adapter: Adapter for perception integration
  - blackboard: Shared blackboard for data access
  - children: List of child nodes
  
  ## Returns
  New neural selector node
  """
  def create_neural_selector(id, network_file, perception_adapter, blackboard, children) do
    NeuralSelector.new(id, network_file, perception_adapter, blackboard, children)
  end
  
  @doc """
  Creates a neural action node.
  
  This factory function creates an action node that uses a neural network
  to determine action parameters or to generate the action itself.
  
  ## Parameters
  - id: Unique identifier for the node
  - network_file: Path to neural network file
  - perception_adapter: Adapter for perception integration
  - blackboard: Shared blackboard for data access
  - action_mapping: How neural outputs map to actions
  
  ## Returns
  New neural action node
  """
  def create_neural_action(id, network_file, perception_adapter, blackboard, action_mapping) do
    NeuralAction.new(id, network_file, perception_adapter, blackboard, action_mapping)
  end
  
  @doc """
  Creates a neural condition node.
  
  This factory function creates a condition node that uses a neural network
  to evaluate whether a condition is satisfied.
  
  ## Parameters
  - id: Unique identifier for the node
  - network_file: Path to neural network file
  - perception_adapter: Adapter for perception integration
  - blackboard: Shared blackboard for data access
  - threshold: Activation threshold for success
  - output_index: Which neural output to check against threshold
  
  ## Returns
  New neural condition node
  """
  def create_neural_condition(id, network_file, perception_adapter, blackboard, threshold, output_index) do
    NeuralCondition.new(id, network_file, perception_adapter, blackboard, threshold, output_index)
  end
  
  @doc """
  Creates a neural decorator node.
  
  This factory function creates a decorator node that uses a neural network
  to modify how its child is executed.
  
  ## Parameters
  - id: Unique identifier for the node
  - network_file: Path to neural network file
  - perception_adapter: Adapter for perception integration
  - blackboard: Shared blackboard for data access
  - child: Child node to decorate
  - modifier_mapping: How neural outputs modify child execution
  
  ## Returns
  New neural decorator node
  """
  def create_neural_decorator(id, network_file, perception_adapter, blackboard, child, modifier_mapping) do
    NeuralDecorator.new(id, network_file, perception_adapter, blackboard, child, modifier_mapping)
  end
  
  @doc """
  Creates a behavior tree with neural components.
  
  This helper function creates a behavior tree with neural nodes for
  decision-making, actions, conditions, and decorators.
  
  ## Parameters
  - root_type: Type of the root node (:sequence, :selector, or :neural_selector)
  - network_file: Path to neural network file
  - perception_adapter: Adapter for perception integration
  - blackboard: Shared blackboard for data access
  - nodes_spec: Specification of nodes in the tree
  
  ## Returns
  New behavior tree with neural components
  """
  def create_neural_behavior_tree(root_type, network_file, perception_adapter, blackboard, nodes_spec) do
    # Create the root node based on type
    root = case root_type do
      :neural_selector ->
        create_neural_selector(
          :root, 
          network_file, 
          perception_adapter, 
          blackboard, 
          build_children(nodes_spec.children, network_file, perception_adapter, blackboard)
        )
        
      :selector ->
        Automaton.Types.BT.Composite.Selector.new(
          build_children(nodes_spec.children, network_file, perception_adapter, blackboard)
        )
        
      :sequence ->
        Automaton.Types.BT.Composite.Sequence.new(
          build_children(nodes_spec.children, network_file, perception_adapter, blackboard)
        )
    end
    
    # Initialize the tree
    BehaviorTree.init(root)
  end
  
  @doc """
  Provides feedback to neural components in a behavior tree.
  
  This function updates neural components in a behavior tree with feedback
  about execution results.
  
  ## Parameters
  - behavior_tree: The behavior tree with neural components
  - status: Execution status (:success, :failure, or :running)
  - perception_state: Current perception state
  - reward: Reward value for reinforcement learning
  
  ## Returns
  Updated behavior tree with feedback applied
  """
  def provide_feedback_to_neural_nodes(behavior_tree, status, perception_state, reward) do
    # Create feedback record
    feedback = %{
      status: status,
      perception_state: perception_state,
      reward: reward,
      timestamp: DateTime.utc_now()
    }
    
    # Store feedback in blackboard for access by neural nodes
    blackboard = Map.put(behavior_tree.blackboard, :neural_feedback, feedback)
    
    # Update the tree with the modified blackboard
    %{behavior_tree | blackboard: blackboard}
  end
  
  # Private helper functions
  
  defp build_children(children_spec, network_file, perception_adapter, blackboard) do
    Enum.map(children_spec, fn {type, id, params} ->
      build_node(type, id, params, network_file, perception_adapter, blackboard)
    end)
  end
  
  defp build_node(type, id, params, network_file, perception_adapter, blackboard) do
    case type do
      :neural_selector ->
        children = build_children(params.children, network_file, perception_adapter, blackboard)
        create_neural_selector(id, network_file, perception_adapter, blackboard, children)
        
      :neural_action ->
        create_neural_action(id, network_file, perception_adapter, blackboard, params.action_mapping)
        
      :neural_condition ->
        create_neural_condition(
          id, 
          network_file, 
          perception_adapter, 
          blackboard, 
          params.threshold, 
          params.output_index
        )
        
      :neural_decorator ->
        child = build_node(
          params.child_type, 
          :"#{id}_child", 
          params.child_params, 
          network_file, 
          perception_adapter, 
          blackboard
        )
        create_neural_decorator(id, network_file, perception_adapter, blackboard, child, params.modifier_mapping)
        
      :selector ->
        children = build_children(params.children, network_file, perception_adapter, blackboard)
        Automaton.Types.BT.Composite.Selector.new(children)
        
      :sequence ->
        children = build_children(params.children, network_file, perception_adapter, blackboard)
        Automaton.Types.BT.Composite.Sequence.new(children)
        
      :action ->
        Automaton.Types.BT.Action.new(params.action_fn)
        
      :condition ->
        Automaton.Types.BT.Condition.new(params.condition_fn)
    end
  end
end