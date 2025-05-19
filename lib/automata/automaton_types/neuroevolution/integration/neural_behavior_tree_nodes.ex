defmodule Automaton.Types.BT.Neural do
  @moduledoc """
  Neural network-enhanced nodes for behavior trees.
  
  This module provides behavior tree nodes that integrate with neural networks,
  allowing for neural decision-making within the behavior tree framework.
  
  Key components:
  - NeuralSelector: Selection node that uses neural network for child selection
  - NeuralAction: Action node with neural processing of inputs
  - NeuralCondition: Condition node that uses neural network for evaluation
  - NeuralDecorator: Modifies child execution based on neural processing
  """
  
  alias Automaton.Types.BT.BehaviorTree
  alias Automaton.Types.BT.Composite.Selector
  alias Automaton.Types.BT.Action
  alias Automaton.Types.BT.Condition
  alias Automaton.Types.BT.Decorator
  alias Automaton.Types.TWEANN.ExoSelf
  alias Automata.Reasoning.Cognitive.NeuroIntegration.PerceptionAdapter
  
  require Logger
  
  @doc """
  A selector node that uses a neural network to choose which child to execute.
  
  Unlike a standard selector which tries children in order, this node uses a
  neural network to evaluate all children and select the most promising one.
  
  ## Fields
  - network_file: Path to the neural network file
  - perception_adapter: Adapter for perception system integration
  - blackboard: Shared blackboard for data access
  - children: List of child nodes
  - current_selection: Currently selected child index
  """
  defmodule NeuralSelector do
    @behaviour BehaviorTree.Composite
    
    defstruct [
      :id,
      :network_file,
      :perception_adapter,
      :blackboard,
      :children,
      :current_selection,
      :cortex_pid,
      :active
    ]
    
    @doc """
    Creates a new neural selector node.
    
    ## Parameters
    - id: Unique identifier for the node
    - network_file: Path to the neural network file
    - perception_adapter: Adapter for perception system integration
    - blackboard: Shared blackboard for data access
    - children: List of child nodes
    
    ## Returns
    A new NeuralSelector struct
    """
    def new(id, network_file, perception_adapter, blackboard, children) do
      %__MODULE__{
        id: id,
        network_file: network_file,
        perception_adapter: perception_adapter,
        blackboard: blackboard,
        children: children,
        current_selection: nil,
        cortex_pid: nil,
        active: false
      }
    end
    
    @doc """
    Initializes the neural selector.
    
    ## Parameters
    - selector: The neural selector to initialize
    
    ## Returns
    Initialized selector
    """
    def init(selector) do
      # Initialize the neural network
      {:ok, cortex_pid} = load_neural_network(selector.network_file)
      
      %{selector | cortex_pid: cortex_pid, active: true}
    end
    
    @doc """
    Executes the neural selector node.
    
    ## Parameters
    - selector: The neural selector to execute
    - blackboard: Current blackboard state
    
    ## Returns
    Tuple of {status, updated_selector, updated_blackboard}
    """
    def tick(selector, blackboard) do
      if selector.active do
        # Get perception state from blackboard
        perception_state = get_perception_state(blackboard)
        
        # Use neural network to select child
        child_index = select_child_with_network(
          selector.cortex_pid,
          selector.perception_adapter,
          perception_state,
          length(selector.children)
        )
        
        # Execute selected child
        selected_child = Enum.at(selector.children, child_index)
        {status, updated_child, updated_blackboard} = BehaviorTree.tick(selected_child, blackboard)
        
        # Update children list with updated child
        updated_children = List.replace_at(selector.children, child_index, updated_child)
        
        # Update selector
        updated_selector = %{selector | 
          children: updated_children,
          current_selection: child_index
        }
        
        {status, updated_selector, updated_blackboard}
      else
        # Fall back to standard selector if neural network is not active
        Selector.tick(%Selector{children: selector.children}, blackboard)
      end
    end
    
    @doc """
    Resets the neural selector node.
    
    ## Parameters
    - selector: The neural selector to reset
    
    ## Returns
    Reset selector
    """
    def reset(selector) do
      # Reset all children
      reset_children = Enum.map(selector.children, &BehaviorTree.reset/1)
      
      %{selector | 
        children: reset_children, 
        current_selection: nil
      }
    end
    
    # Private helper functions
    
    defp load_neural_network(network_file) do
      # Use ExoSelf to load the neural network
      Task.async(fn -> ExoSelf.map(network_file) end)
      |> Task.await(:infinity)
      
      # ExoSelf.map returns the cortex PID
      {:ok, Process.whereis(:cortex)}
    end
    
    defp get_perception_state(blackboard) do
      # Extract perception state from blackboard
      Map.get(blackboard, :perception_state, %{})
    end
    
    defp select_child_with_network(cortex_pid, perception_adapter, perception_state, child_count) do
      # Convert perceptions to neural inputs
      neural_inputs = PerceptionAdapter.map_perceptions_to_neural_inputs(
        perception_adapter, 
        perception_state
      )
      
      # Send inputs to neural network
      neural_outputs = send_to_network(cortex_pid, neural_inputs)
      
      # Select child based on neural outputs
      # Typically we'd get child selection outputs from specific output nodes
      selection_outputs = Enum.take(neural_outputs, child_count)
      
      # Choose child with highest activation
      selection_index = Enum.with_index(selection_outputs)
      |> Enum.max_by(fn {value, _index} -> value end)
      |> elem(1)
      
      selection_index
    end
    
    defp send_to_network(cortex_pid, inputs) do
      # Send inputs to neural network and wait for response
      send(cortex_pid, {:process_inputs, inputs})
      
      receive do
        {:neural_outputs, outputs} ->
          outputs
      after
        5000 ->
          Logger.error("Timeout waiting for neural network response")
          []
      end
    end
  end
  
  @doc """
  An action node that uses a neural network for execution.
  
  This action node processes inputs through a neural network to determine
  parameters for action execution or to generate the action itself.
  
  ## Fields
  - id: Unique identifier for the node
  - network_file: Path to the neural network file
  - perception_adapter: Adapter for perception system integration
  - blackboard: Shared blackboard for data access
  - action_mapping: How neural outputs map to actions
  - cortex_pid: PID of the neural network cortex
  - active: Whether the neural network is active
  """
  defmodule NeuralAction do
    @behaviour BehaviorTree.Action
    
    defstruct [
      :id,
      :network_file,
      :perception_adapter,
      :blackboard,
      :action_mapping,
      :cortex_pid,
      :active
    ]
    
    @doc """
    Creates a new neural action node.
    
    ## Parameters
    - id: Unique identifier for the node
    - network_file: Path to the neural network file
    - perception_adapter: Adapter for perception system integration
    - blackboard: Shared blackboard for data access
    - action_mapping: How neural outputs map to actions
    
    ## Returns
    A new NeuralAction struct
    """
    def new(id, network_file, perception_adapter, blackboard, action_mapping) do
      %__MODULE__{
        id: id,
        network_file: network_file,
        perception_adapter: perception_adapter,
        blackboard: blackboard,
        action_mapping: action_mapping,
        cortex_pid: nil,
        active: false
      }
    end
    
    @doc """
    Initializes the neural action.
    
    ## Parameters
    - action: The neural action to initialize
    
    ## Returns
    Initialized action
    """
    def init(action) do
      # Initialize the neural network
      {:ok, cortex_pid} = load_neural_network(action.network_file)
      
      %{action | cortex_pid: cortex_pid, active: true}
    end
    
    @doc """
    Executes the neural action node.
    
    ## Parameters
    - action: The neural action to execute
    - blackboard: Current blackboard state
    
    ## Returns
    Tuple of {status, updated_action, updated_blackboard}
    """
    def tick(action, blackboard) do
      if action.active do
        # Get perception state from blackboard
        perception_state = get_perception_state(blackboard)
        
        # Process through neural network
        execution_result = execute_with_network(
          action.cortex_pid,
          action.perception_adapter,
          perception_state,
          action.action_mapping
        )
        
        # Update blackboard with results
        updated_blackboard = Map.put(
          blackboard, 
          :neural_action_result, 
          execution_result
        )
        
        # Return success if execution produced valid results
        if valid_execution?(execution_result) do
          {:success, action, updated_blackboard}
        else
          {:failure, action, updated_blackboard}
        end
      else
        # Fail if neural network is not active
        {:failure, action, blackboard}
      end
    end
    
    @doc """
    Resets the neural action node.
    
    ## Parameters
    - action: The neural action to reset
    
    ## Returns
    Reset action
    """
    def reset(action) do
      action
    end
    
    # Private helper functions
    
    defp load_neural_network(network_file) do
      # Use ExoSelf to load the neural network
      Task.async(fn -> ExoSelf.map(network_file) end)
      |> Task.await(:infinity)
      
      # ExoSelf.map returns the cortex PID
      {:ok, Process.whereis(:cortex)}
    end
    
    defp get_perception_state(blackboard) do
      # Extract perception state from blackboard
      Map.get(blackboard, :perception_state, %{})
    end
    
    defp execute_with_network(cortex_pid, perception_adapter, perception_state, action_mapping) do
      # Convert perceptions to neural inputs
      neural_inputs = PerceptionAdapter.map_perceptions_to_neural_inputs(
        perception_adapter, 
        perception_state
      )
      
      # Send inputs to neural network
      neural_outputs = send_to_network(cortex_pid, neural_inputs)
      
      # Map neural outputs to actions using the action mapping
      map_outputs_to_actions(neural_outputs, action_mapping)
    end
    
    defp send_to_network(cortex_pid, inputs) do
      # Send inputs to neural network and wait for response
      send(cortex_pid, {:process_inputs, inputs})
      
      receive do
        {:neural_outputs, outputs} ->
          outputs
      after
        5000 ->
          Logger.error("Timeout waiting for neural network response")
          []
      end
    end
    
    defp map_outputs_to_actions(neural_outputs, action_mapping) do
      # Convert neural outputs to action commands
      Enum.with_index(neural_outputs)
      |> Enum.flat_map(fn {output_value, index} ->
        case Map.get(action_mapping, index) do
          nil -> 
            # No mapping for this output
            []
            
          {action_type, threshold} when output_value >= threshold ->
            # Output exceeds threshold, trigger action
            [%{type: action_type, value: output_value}]
            
          {action_type, threshold, params} when output_value >= threshold ->
            # Output exceeds threshold with additional parameters
            [%{type: action_type, value: output_value, params: params}]
            
          _ ->
            # Output below threshold or invalid mapping
            []
        end
      end)
    end
    
    defp valid_execution?(execution_result) do
      # Check if execution produced valid results
      is_list(execution_result) and length(execution_result) > 0
    end
  end
  
  @doc """
  A condition node that uses a neural network for evaluation.
  
  This condition node processes inputs through a neural network to determine
  whether a condition is satisfied.
  
  ## Fields
  - id: Unique identifier for the node
  - network_file: Path to the neural network file
  - perception_adapter: Adapter for perception system integration
  - blackboard: Shared blackboard for data access
  - threshold: Activation threshold for success
  - output_index: Which neural output to check against threshold
  - cortex_pid: PID of the neural network cortex
  - active: Whether the neural network is active
  """
  defmodule NeuralCondition do
    @behaviour BehaviorTree.Condition
    
    defstruct [
      :id,
      :network_file,
      :perception_adapter,
      :blackboard,
      :threshold,
      :output_index,
      :cortex_pid,
      :active
    ]
    
    @doc """
    Creates a new neural condition node.
    
    ## Parameters
    - id: Unique identifier for the node
    - network_file: Path to the neural network file
    - perception_adapter: Adapter for perception system integration
    - blackboard: Shared blackboard for data access
    - threshold: Activation threshold for success
    - output_index: Which neural output to check against threshold
    
    ## Returns
    A new NeuralCondition struct
    """
    def new(id, network_file, perception_adapter, blackboard, threshold, output_index) do
      %__MODULE__{
        id: id,
        network_file: network_file,
        perception_adapter: perception_adapter,
        blackboard: blackboard,
        threshold: threshold,
        output_index: output_index,
        cortex_pid: nil,
        active: false
      }
    end
    
    @doc """
    Initializes the neural condition.
    
    ## Parameters
    - condition: The neural condition to initialize
    
    ## Returns
    Initialized condition
    """
    def init(condition) do
      # Initialize the neural network
      {:ok, cortex_pid} = load_neural_network(condition.network_file)
      
      %{condition | cortex_pid: cortex_pid, active: true}
    end
    
    @doc """
    Evaluates the neural condition node.
    
    ## Parameters
    - condition: The neural condition to evaluate
    - blackboard: Current blackboard state
    
    ## Returns
    Tuple of {status, updated_condition, updated_blackboard}
    """
    def tick(condition, blackboard) do
      if condition.active do
        # Get perception state from blackboard
        perception_state = get_perception_state(blackboard)
        
        # Evaluate with neural network
        result = evaluate_with_network(
          condition.cortex_pid,
          condition.perception_adapter,
          perception_state,
          condition.output_index,
          condition.threshold
        )
        
        # Return result
        if result do
          {:success, condition, blackboard}
        else
          {:failure, condition, blackboard}
        end
      else
        # Fail if neural network is not active
        {:failure, condition, blackboard}
      end
    end
    
    @doc """
    Resets the neural condition node.
    
    ## Parameters
    - condition: The neural condition to reset
    
    ## Returns
    Reset condition
    """
    def reset(condition) do
      condition
    end
    
    # Private helper functions
    
    defp load_neural_network(network_file) do
      # Use ExoSelf to load the neural network
      Task.async(fn -> ExoSelf.map(network_file) end)
      |> Task.await(:infinity)
      
      # ExoSelf.map returns the cortex PID
      {:ok, Process.whereis(:cortex)}
    end
    
    defp get_perception_state(blackboard) do
      # Extract perception state from blackboard
      Map.get(blackboard, :perception_state, %{})
    end
    
    defp evaluate_with_network(cortex_pid, perception_adapter, perception_state, output_index, threshold) do
      # Convert perceptions to neural inputs
      neural_inputs = PerceptionAdapter.map_perceptions_to_neural_inputs(
        perception_adapter, 
        perception_state
      )
      
      # Send inputs to neural network
      neural_outputs = send_to_network(cortex_pid, neural_inputs)
      
      # Check if the specified output exceeds threshold
      output_value = Enum.at(neural_outputs, output_index, 0.0)
      output_value >= threshold
    end
    
    defp send_to_network(cortex_pid, inputs) do
      # Send inputs to neural network and wait for response
      send(cortex_pid, {:process_inputs, inputs})
      
      receive do
        {:neural_outputs, outputs} ->
          outputs
      after
        5000 ->
          Logger.error("Timeout waiting for neural network response")
          []
      end
    end
  end
  
  @doc """
  A decorator node that modifies child execution based on neural processing.
  
  This decorator processes inputs through a neural network to determine
  how to modify the execution of its child node.
  
  ## Fields
  - id: Unique identifier for the node
  - network_file: Path to the neural network file
  - perception_adapter: Adapter for perception system integration
  - blackboard: Shared blackboard for data access
  - child: Child node to decorate
  - modifier_mapping: How neural outputs modify child execution
  - cortex_pid: PID of the neural network cortex
  - active: Whether the neural network is active
  """
  defmodule NeuralDecorator do
    @behaviour BehaviorTree.Decorator
    
    defstruct [
      :id,
      :network_file,
      :perception_adapter,
      :blackboard,
      :child,
      :modifier_mapping,
      :cortex_pid,
      :active
    ]
    
    @doc """
    Creates a new neural decorator node.
    
    ## Parameters
    - id: Unique identifier for the node
    - network_file: Path to the neural network file
    - perception_adapter: Adapter for perception system integration
    - blackboard: Shared blackboard for data access
    - child: Child node to decorate
    - modifier_mapping: How neural outputs modify child execution
    
    ## Returns
    A new NeuralDecorator struct
    """
    def new(id, network_file, perception_adapter, blackboard, child, modifier_mapping) do
      %__MODULE__{
        id: id,
        network_file: network_file,
        perception_adapter: perception_adapter,
        blackboard: blackboard,
        child: child,
        modifier_mapping: modifier_mapping,
        cortex_pid: nil,
        active: false
      }
    end
    
    @doc """
    Initializes the neural decorator.
    
    ## Parameters
    - decorator: The neural decorator to initialize
    
    ## Returns
    Initialized decorator
    """
    def init(decorator) do
      # Initialize the neural network
      {:ok, cortex_pid} = load_neural_network(decorator.network_file)
      
      # Initialize child
      initialized_child = BehaviorTree.init(decorator.child)
      
      %{decorator | 
        cortex_pid: cortex_pid, 
        active: true,
        child: initialized_child
      }
    end
    
    @doc """
    Executes the neural decorator node.
    
    ## Parameters
    - decorator: The neural decorator to execute
    - blackboard: Current blackboard state
    
    ## Returns
    Tuple of {status, updated_decorator, updated_blackboard}
    """
    def tick(decorator, blackboard) do
      if decorator.active do
        # Get perception state from blackboard
        perception_state = get_perception_state(blackboard)
        
        # Determine modifiers with neural network
        modifiers = determine_modifiers(
          decorator.cortex_pid,
          decorator.perception_adapter,
          perception_state,
          decorator.modifier_mapping
        )
        
        # Apply modifiers to blackboard
        modified_blackboard = apply_modifiers(blackboard, modifiers)
        
        # Execute child with modified blackboard
        {status, updated_child, child_blackboard} = BehaviorTree.tick(decorator.child, modified_blackboard)
        
        # Apply neural modification to result if specified
        {modified_status, final_blackboard} = modify_result(status, child_blackboard, modifiers)
        
        # Update decorator
        updated_decorator = %{decorator | child: updated_child}
        
        {modified_status, updated_decorator, final_blackboard}
      else
        # Fall back to normal execution if neural network is not active
        {status, updated_child, updated_blackboard} = BehaviorTree.tick(decorator.child, blackboard)
        updated_decorator = %{decorator | child: updated_child}
        {status, updated_decorator, updated_blackboard}
      end
    end
    
    @doc """
    Resets the neural decorator node.
    
    ## Parameters
    - decorator: The neural decorator to reset
    
    ## Returns
    Reset decorator
    """
    def reset(decorator) do
      # Reset child
      reset_child = BehaviorTree.reset(decorator.child)
      
      %{decorator | child: reset_child}
    end
    
    # Private helper functions
    
    defp load_neural_network(network_file) do
      # Use ExoSelf to load the neural network
      Task.async(fn -> ExoSelf.map(network_file) end)
      |> Task.await(:infinity)
      
      # ExoSelf.map returns the cortex PID
      {:ok, Process.whereis(:cortex)}
    end
    
    defp get_perception_state(blackboard) do
      # Extract perception state from blackboard
      Map.get(blackboard, :perception_state, %{})
    end
    
    defp determine_modifiers(cortex_pid, perception_adapter, perception_state, modifier_mapping) do
      # Convert perceptions to neural inputs
      neural_inputs = PerceptionAdapter.map_perceptions_to_neural_inputs(
        perception_adapter, 
        perception_state
      )
      
      # Send inputs to neural network
      neural_outputs = send_to_network(cortex_pid, neural_inputs)
      
      # Map neural outputs to modifiers
      map_outputs_to_modifiers(neural_outputs, modifier_mapping)
    end
    
    defp send_to_network(cortex_pid, inputs) do
      # Send inputs to neural network and wait for response
      send(cortex_pid, {:process_inputs, inputs})
      
      receive do
        {:neural_outputs, outputs} ->
          outputs
      after
        5000 ->
          Logger.error("Timeout waiting for neural network response")
          []
      end
    end
    
    defp map_outputs_to_modifiers(neural_outputs, modifier_mapping) do
      # Convert neural outputs to modifiers
      Enum.with_index(neural_outputs)
      |> Enum.flat_map(fn {output_value, index} ->
        case Map.get(modifier_mapping, index) do
          nil -> 
            # No mapping for this output
            []
            
          {modifier_type, threshold} when output_value >= threshold ->
            # Output exceeds threshold, apply modifier
            [%{type: modifier_type, value: output_value}]
            
          {modifier_type, threshold, params} when output_value >= threshold ->
            # Output exceeds threshold with additional parameters
            [%{type: modifier_type, value: output_value, params: params}]
            
          _ ->
            # Output below threshold or invalid mapping
            []
        end
      end)
    end
    
    defp apply_modifiers(blackboard, modifiers) do
      # Apply modifiers to blackboard
      Enum.reduce(modifiers, blackboard, fn modifier, acc ->
        case modifier do
          %{type: :add_parameter, params: %{key: key, value: value}} ->
            Map.put(acc, key, value)
            
          %{type: :multiply_parameter, params: %{key: key, factor: factor}} ->
            current = Map.get(acc, key, 0)
            Map.put(acc, key, current * factor)
            
          %{type: :set_context, params: context} ->
            Map.put(acc, :context, context)
            
          _ ->
            # Unknown modifier
            acc
        end
      end)
    end
    
    defp modify_result(status, blackboard, modifiers) do
      # Check if any modifiers apply to result
      status_modifier = Enum.find(modifiers, fn m -> m.type == :modify_status end)
      
      case status_modifier do
        %{params: %{success: :invert}} when status == :success ->
          {:failure, blackboard}
          
        %{params: %{failure: :invert}} when status == :failure ->
          {:success, blackboard}
          
        %{params: %{running: :invert}} when status == :running ->
          {:success, blackboard}
          
        %{params: %{force: forced_status}} ->
          {forced_status, blackboard}
          
        _ ->
          # No status modification
          {status, blackboard}
      end
    end
  end
end