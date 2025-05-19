defmodule Automata.Reasoning.Cognitive.ContextualReasoning do
  @moduledoc """
  Main entry point for the Contextual Reasoning Framework.
  
  The ContextualReasoning module provides a unified interface to the various
  components of the framework, including:
  
  - Context management (creation, activation, relationships)
  - Contextual inference (reasoning within specific contexts)
  - Knowledge representation (semantic networks with context sensitivity)
  - Memory integration (context-aware memory systems)
  
  This framework enables context-sensitive reasoning that can adapt to different
  situations, manage conflicting information across contexts, and provide
  more relevant and accurate inferences based on the current active contexts.
  """
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.Context
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.ContextManager
  alias Automata.Reasoning.Cognitive.ContextualReasoning.InferenceEngine.ContextualInference
  alias Automata.Reasoning.Cognitive.ContextualReasoning.KnowledgeRepresentation.SemanticNetwork
  alias Automata.Reasoning.Cognitive.ContextualReasoning.MemoryIntegration.ContextMemory
  alias Automata.Reasoning.Cognitive.Perceptory.EnhancedPerceptory
  
  require Logger
  
  @type context_id :: atom() | String.t()
  @type assertion :: {atom(), [any()]}
  
  defstruct [
    :context_manager,      # Context management system
    :inference_engine,     # Contextual inference engine
    :semantic_network,     # Semantic network for knowledge representation
    :context_memory,       # Context-sensitive memory system
    :perceptory            # Reference to the perception system
  ]
  
  @doc """
  Creates a new contextual reasoning system.
  
  ## Parameters
  - perceptory: Reference to the perception system
  - perception_memory: Reference to the perception memory system
  - associative_memory: Reference to the associative memory system
  
  ## Returns
  A new ContextualReasoning struct
  """
  def new(perceptory, perception_memory, associative_memory) do
    # Start the context manager
    {:ok, context_manager} = ContextManager.start_link(perceptory)
    
    # Create the semantic network
    semantic_network = SemanticNetwork.new(context_manager)
    
    # Create the context memory
    context_memory = ContextMemory.new(context_manager, perception_memory, associative_memory)
    
    %__MODULE__{
      context_manager: context_manager,
      inference_engine: nil,  # Will be initialized on first use
      semantic_network: semantic_network,
      context_memory: context_memory,
      perceptory: perceptory
    }
  end
  
  @doc """
  Creates a new context in the system.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - id: Unique identifier for the context
  - name: Human-readable name
  - description: Description of the context
  - parent_ids: List of parent context IDs
  - parameters: Initial parameters map
  - assertions: Initial assertions set
  - rules: Initial rules list
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  def create_context(reasoning, id, name, description, parent_ids \\ [], 
                    parameters \\ %{}, assertions \\ MapSet.new(), rules \\ []) do
    ContextManager.create_context(
      reasoning.context_manager,
      id,
      name,
      description,
      parent_ids,
      parameters,
      assertions,
      rules
    )
  end
  
  @doc """
  Activates a context.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - context_id: ID of the context to activate
  - activation_value: Value to increase activation by (default: 1.0)
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  def activate_context(reasoning, context_id, activation_value \\ 1.0) do
    ContextManager.activate_context(
      reasoning.context_manager,
      context_id,
      activation_value
    )
  end
  
  @doc """
  Gets all currently active contexts.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  
  ## Returns
  List of active contexts
  """
  def get_active_contexts(reasoning) do
    ContextManager.get_active_contexts(reasoning.context_manager)
  end
  
  @doc """
  Performs inference within the active contexts.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - query: The query assertion or pattern
  - max_depth: Maximum inference depth
  
  ## Returns
  List of derived assertions matching the query
  """
  def infer(reasoning, query, max_depth \\ 10) do
    ContextualInference.infer(reasoning.context_manager, query, max_depth)
  end
  
  @doc """
  Adds an assertion to a context.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - context_id: ID of the context to modify
  - assertion: The assertion to add
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  def add_assertion(reasoning, context_id, assertion) do
    ContextManager.add_assertion(reasoning.context_manager, context_id, assertion)
  end
  
  @doc """
  Adds a node to the semantic network.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - id: Unique identifier for the node
  - type: Node type
  - label: Human-readable label
  - properties: Map of node properties
  - context_ids: List of contexts where this node is relevant
  
  ## Returns
  Updated reasoning system with the new node
  """
  def add_semantic_node(reasoning, id, type, label, properties \\ %{}, context_ids \\ []) do
    updated_network = SemanticNetwork.add_node(
      reasoning.semantic_network,
      id,
      type,
      label,
      properties,
      context_ids
    )
    
    %{reasoning | semantic_network: updated_network}
  end
  
  @doc """
  Adds an edge to the semantic network.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - source_id: Source node ID
  - target_id: Target node ID
  - relation: Relationship type
  - weight: Edge weight/strength (default: 1.0)
  - properties: Map of edge properties
  - context_ids: List of contexts where this edge is relevant
  - bidirectional: Whether the relationship is bidirectional (default: false)
  
  ## Returns
  Updated reasoning system with the new edge
  """
  def add_semantic_edge(reasoning, source_id, target_id, relation, weight \\ 1.0,
                properties \\ %{}, context_ids \\ [], bidirectional \\ false) do
    updated_network = SemanticNetwork.add_edge(
      reasoning.semantic_network,
      source_id,
      target_id,
      relation,
      weight,
      properties,
      context_ids,
      bidirectional
    )
    
    %{reasoning | semantic_network: updated_network}
  end
  
  @doc """
  Performs activation spreading in the semantic network.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - node_id: Node ID to activate
  - activation_value: Initial activation value (default: 1.0)
  - spread_factor: Factor for spreading activation (default: 0.5)
  - max_depth: Maximum spreading depth (default: 3)
  
  ## Returns
  Updated reasoning system with new activation levels
  """
  def spread_semantic_activation(reasoning, node_id, activation_value \\ 1.0, 
                                spread_factor \\ 0.5, max_depth \\ 3) do
    updated_network = SemanticNetwork.spread_activation(
      reasoning.semantic_network,
      node_id,
      activation_value,
      spread_factor,
      max_depth
    )
    
    %{reasoning | semantic_network: updated_network}
  end
  
  @doc """
  Stores a memory item in the context memory system.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - content: Memory content
  - context_ids: List of context IDs to associate with the memory
  - confidence: Confidence level (default: 1.0)
  - metadata: Additional memory metadata
  
  ## Returns
  Updated reasoning system with the new memory item
  """
  def store_memory(reasoning, content, context_ids \\ [], confidence \\ 1.0, metadata \\ %{}) do
    updated_memory = ContextMemory.store(
      reasoning.context_memory,
      content,
      context_ids,
      confidence,
      metadata
    )
    
    %{reasoning | context_memory: updated_memory}
  end
  
  @doc """
  Retrieves memories relevant to the active contexts.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - query: Query pattern to filter memories (optional)
  - limit: Maximum number of memories to return (default: 10)
  
  ## Returns
  Tuple of {memories, updated_reasoning}
  """
  def retrieve_memories(reasoning, query \\ nil, limit \\ 10) do
    {memories, updated_memory} = ContextMemory.retrieve(
      reasoning.context_memory,
      query,
      limit
    )
    
    {memories, %{reasoning | context_memory: updated_memory}}
  end
  
  @doc """
  Processes perceptions and updates the contextual reasoning system.
  
  This function:
  1. Updates context activations based on perceptions
  2. Integrates perception memories into context memory
  3. Updates the semantic network with perception-related nodes
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - perceptions: Current perceptions
  
  ## Returns
  Updated reasoning system
  """
  def process_perceptions(reasoning, perceptions) do
    # Update context activations based on perceptions
    ContextManager.switch_context_from_percepts(reasoning.context_manager, perceptions)
    
    # Get perception memories from perceptory
    percept_memories = EnhancedPerceptory.get_active_percept_memories(reasoning.perceptory)
    
    # Integrate perception memories into context memory
    updated_context_memory = ContextMemory.integrate_perception_memories(
      reasoning.context_memory,
      percept_memories
    )
    
    # Update semantic network with perception-related nodes
    updated_semantic_network = add_perception_nodes(
      reasoning.semantic_network,
      perceptions
    )
    
    # Return updated reasoning system
    %{reasoning | 
      context_memory: updated_context_memory,
      semantic_network: updated_semantic_network
    }
  end
  
  @doc """
  Explains the reasoning for a particular assertion across contexts.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  - assertion: The assertion to explain
  
  ## Returns
  Explanation structure with reasoning steps
  """
  def explain(reasoning, assertion) do
    ContextualInference.explain(reasoning.context_manager, assertion)
  end
  
  @doc """
  Applies decay to context activations and memories.
  
  ## Parameters
  - reasoning: The contextual reasoning system
  
  ## Returns
  Updated reasoning system with decayed activations and memories
  """
  def apply_decay(reasoning) do
    # Apply decay to context memories
    updated_context_memory = ContextMemory.apply_decay(reasoning.context_memory)
    
    # Return updated reasoning system
    %{reasoning | context_memory: updated_context_memory}
  end
  
  # Private helper functions
  
  defp add_perception_nodes(semantic_network, perceptions) do
    # Add perception-related nodes to the semantic network
    # This is a simplified implementation
    Enum.reduce(perceptions, semantic_network, fn perception, network ->
      # Create node for perception type if it doesn't exist
      perception_type_id = String.to_atom("percept_type_#{perception.type}")
      
      network = if SemanticNetwork.get_node(network, perception_type_id) == nil do
        SemanticNetwork.add_node(
          network,
          perception_type_id,
          :perception_type,
          Atom.to_string(perception.type),
          %{system_type: :perception}
        )
      else
        network
      end
      
      # Create node for specific perception
      perception_id = String.to_atom("percept_#{perception.id}")
      
      network = SemanticNetwork.add_node(
        network,
        perception_id,
        :perception,
        "Perception #{perception.id}",
        %{
          perception_type: perception.type,
          value: perception.value,
          attributes: perception.attributes,
          activation: perception.activation
        }
      )
      
      # Connect perception to its type
      SemanticNetwork.add_edge(
        network,
        perception_id,
        perception_type_id,
        :instance_of,
        1.0,
        %{},
        [],
        false
      )
    end)
  end
end