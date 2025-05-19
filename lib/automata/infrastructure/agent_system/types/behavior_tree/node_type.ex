defmodule Automata.Infrastructure.AgentSystem.Types.BehaviorTree.NodeType do
  @moduledoc """
  Behavior for behavior tree node types.
  
  This module defines the behavior that all behavior tree node types must implement.
  It provides the interface for initializing, evaluating, and resetting nodes.
  """
  
  @typedoc """
  The state of a behavior tree node.
  """
  @type state :: map()
  
  @typedoc """
  The context for node evaluation.
  """
  @type context :: %{
    agent_id: String.t(),
    world_id: String.t(),
    blackboard: map(),
    tick_count: integer()
  }
  
  @typedoc """
  The status of a behavior tree node.
  """
  @type status :: :bh_fresh | :bh_running | :bh_success | :bh_failure | :bh_aborted
  
  @doc """
  Initializes a node with the given configuration.
  """
  @callback init(config :: map()) :: {:ok, state()} | {:error, term()}
  
  @doc """
  Evaluates a node, updating its state based on the current context.
  """
  @callback evaluate(state :: state(), context :: context()) :: {status(), state(), map()}
  
  @doc """
  Resets a node to its initial state and then evaluates it.
  """
  @callback reset_and_evaluate(state :: state(), context :: context()) :: {status(), state(), map()}
  
  @doc """
  Gets the module for a node type.
  """
  def get_module(node_type) do
    case node_type do
      :sequence -> Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Sequence
      :selector -> Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Selector
      :parallel -> Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Parallel
      :action -> Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Action
      :condition -> Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Condition
      :decorator -> Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Decorator
      _ -> raise "Unknown node type: #{inspect(node_type)}"
    end
  end
  
  @doc """
  Creates a new node type implementation.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      
      @impl true
      def reset_and_evaluate(state, context) do
        {:ok, initial_state} = reset(state)
        evaluate(initial_state, context)
      end
      
      # Reset a node to its initial state
      def reset(state) do
        {:ok, %{state | status: :bh_fresh}}
      end
      
      defoverridable reset_and_evaluate: 2, reset: 1
    end
  end
end