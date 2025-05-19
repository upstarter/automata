defmodule Automata.Infrastructure.AgentSystem.Types.BehaviorTree.AgentType do
  @moduledoc """
  Behavior tree agent type implementation.
  
  This module implements the AgentType behavior for behavior tree agents.
  It provides the core functionality for managing behavior tree agents,
  including initialization, state management, and event handling.
  """
  
  @behaviour Automata.Infrastructure.AgentSystem.AgentType
  
  require Logger
  alias Automata.Infrastructure.Resilience.Logger, as: EnhancedLogger
  alias Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Schema
  alias Automata.Infrastructure.AgentSystem.Types.BehaviorTree.NodeType
  
  # Implementation of AgentType behavior
  
  @impl true
  def type, do: :behavior_tree
  
  @impl true
  def description do
    """
    Behavior tree agent type.
    
    Behavior trees represent agent behaviors as a hierarchical tree of nodes,
    where each node represents a behavior or decision. The tree is traversed
    from the root to determine the agent's behavior at each tick.
    """
  end
  
  @impl true
  def schema, do: Schema
  
  @impl true
  def validate_config(config) do
    Schema.validate(config)
  end
  
  @impl true
  def init(agent_id, world_id, config) do
    EnhancedLogger.info("Initializing behavior tree agent", %{
      agent_id: agent_id,
      world_id: world_id,
      node_type: config.node_type
    })
    
    # Create root node state based on node type
    with {:ok, root_node} <- create_node(config) do
      # Create the behavior tree implementation
      implementation = %{
        agent_id: agent_id,
        world_id: world_id,
        node_tree: root_node,
        blackboard: %{},
        status: :initializing,
        current_node: nil,
        traversal_path: [],
        tick_count: 0,
        last_status: nil,
        start_time: DateTime.utc_now()
      }
      
      {:ok, implementation}
    end
  end
  
  @impl true
  def handle_tick(implementation) do
    EnhancedLogger.debug("Ticking behavior tree agent", %{
      agent_id: implementation.agent_id,
      tick_count: implementation.tick_count
    })
    
    # Start with root node
    root_node = implementation.node_tree
    
    # Prepare for traversal
    context = %{
      agent_id: implementation.agent_id,
      world_id: implementation.world_id,
      blackboard: implementation.blackboard,
      tick_count: implementation.tick_count
    }
    
    # Evaluate the tree
    {status, updated_node, updated_blackboard} = evaluate_node(root_node, context)
    
    # Update implementation
    updated_implementation = %{implementation |
      node_tree: updated_node,
      blackboard: updated_blackboard,
      status: translate_status(status),
      last_status: status,
      tick_count: implementation.tick_count + 1
    }
    
    {:ok, updated_implementation}
  end
  
  @impl true
  def terminate(implementation, reason) do
    EnhancedLogger.info("Terminating behavior tree agent", %{
      agent_id: implementation.agent_id,
      reason: reason
    })
    
    # Clean up any resources
    
    :ok
  end
  
  @impl true
  def status(implementation) do
    implementation.status
  end
  
  @impl true
  def metadata(implementation) do
    %{
      agent_id: implementation.agent_id,
      world_id: implementation.world_id,
      tick_count: implementation.tick_count,
      last_status: implementation.last_status,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), implementation.start_time)
    }
  end
  
  @impl true
  def features do
    [:hierarchical, :composable, :reactive, :decision_making]
  end
  
  # Private helpers
  
  defp create_node(config) do
    try do
      # Create node based on node type
      node_type_module = NodeType.get_module(config.node_type)
      
      # Initialize node with configuration
      {:ok, node_state} = node_type_module.init(config)
      
      # Create node structure
      node = %{
        type: config.node_type,
        module: node_type_module,
        state: node_state,
        status: :bh_fresh,
        children: []
      }
      
      # Create child nodes if present
      node = if config.children && length(config.children) > 0 do
        children = Enum.map(config.children, fn child_config ->
          {:ok, child_node} = create_node(child_config)
          child_node
        end)
        
        %{node | children: children}
      else
        node
      end
      
      {:ok, node}
    rescue
      e ->
        EnhancedLogger.error("Error creating behavior tree node", %{
          node_type: config.node_type,
          error: Exception.message(e),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        
        {:error, {:node_creation_failed, config.node_type, e}}
    end
  end
  
  defp evaluate_node(node, context) do
    # Get node implementation module
    node_module = node.module
    
    # Evaluate node based on current status
    case node.status do
      :bh_fresh ->
        # Node is fresh, initialize and evaluate
        {status, updated_state, updated_blackboard} = node_module.evaluate(node.state, context)
        
        # Update node with new state and status
        updated_node = %{node |
          state: updated_state,
          status: status
        }
        
        {status, updated_node, updated_blackboard}
        
      :bh_running ->
        # Node is already running, continue evaluation
        {status, updated_state, updated_blackboard} = node_module.evaluate(node.state, context)
        
        # Update node with new state and status
        updated_node = %{node |
          state: updated_state,
          status: status
        }
        
        {status, updated_node, updated_blackboard}
        
      _completed_status ->
        # Node already completed (success or failure), reset and evaluate
        {status, updated_state, updated_blackboard} = node_module.reset_and_evaluate(node.state, context)
        
        # Update node with new state and status
        updated_node = %{node |
          state: updated_state,
          status: status
        }
        
        {status, updated_node, updated_blackboard}
    end
  end
  
  defp translate_status(:bh_running), do: :running
  defp translate_status(:bh_success), do: :ready
  defp translate_status(:bh_failure), do: :ready
  defp translate_status(:bh_aborted), do: :error
  defp translate_status(_), do: :initializing
end