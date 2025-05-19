defmodule Automata.Reasoning.Cognitive.ContextualReasoning.KnowledgeRepresentation.SemanticNetwork do
  @moduledoc """
  Implements a semantic network for knowledge representation in contextual reasoning.
  
  The semantic network provides a graph-based knowledge representation that supports:
  - Concepts and relationships between concepts
  - Inheritance of properties
  - Context-sensitive relationships
  - Activation spreading for associative retrieval
  - Integration with the context system
  
  Each node in the network represents a concept, and edges represent relationships
  between concepts. Both nodes and edges can be associated with specific contexts.
  """
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.Context
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.ContextManager
  
  require Logger
  
  defstruct [
    :nodes,               # Map of node_id to node data
    :edges,               # Map of {source_id, target_id, relation} to edge data
    :node_edges,          # Map of node_id to lists of connected edges
    :context_manager,     # Reference to the context manager
    :activation_levels,   # Map of node_id to activation level
    :activation_threshold # Threshold for node activation
  ]
  
  # Node structure
  defmodule Node do
    @moduledoc "Represents a concept in the semantic network"
    
    defstruct [
      :id,           # Unique identifier
      :type,         # Node type (e.g., :concept, :entity, :property)
      :label,        # Human-readable label
      :properties,   # Map of properties
      :context_ids   # List of contexts where this node is relevant
    ]
  end
  
  # Edge structure
  defmodule Edge do
    @moduledoc "Represents a relationship between concepts in the semantic network"
    
    defstruct [
      :source_id,    # Source node ID
      :target_id,    # Target node ID
      :relation,     # Relationship type (e.g., :is_a, :has_part, :causes)
      :weight,       # Edge weight/strength (0.0 to 1.0)
      :properties,   # Map of edge properties
      :context_ids,  # List of contexts where this edge is relevant
      :bidirectional # Whether the relationship is bidirectional
    ]
  end
  
  @doc """
  Creates a new semantic network.
  
  ## Parameters
  - context_manager: Reference to the context manager
  
  ## Returns
  A new SemanticNetwork struct
  """
  def new(context_manager) do
    %__MODULE__{
      nodes: %{},
      edges: %{},
      node_edges: %{},
      context_manager: context_manager,
      activation_levels: %{},
      activation_threshold: 0.2  # Default activation threshold
    }
  end
  
  @doc """
  Adds a node to the semantic network.
  
  ## Parameters
  - network: The semantic network
  - id: Unique identifier for the node
  - type: Node type
  - label: Human-readable label
  - properties: Map of node properties
  - context_ids: List of contexts where this node is relevant
  
  ## Returns
  Updated network with the new node
  """
  def add_node(network, id, type, label, properties \\ %{}, context_ids \\ []) do
    case Map.has_key?(network.nodes, id) do
      true ->
        # Node already exists, update it
        existing_node = Map.get(network.nodes, id)
        updated_node = %Node{
          existing_node |
          type: type,
          label: label,
          properties: Map.merge(existing_node.properties, properties),
          context_ids: (existing_node.context_ids ++ context_ids) |> Enum.uniq()
        }
        
        %{network | nodes: Map.put(network.nodes, id, updated_node)}
        
      false ->
        # Create new node
        node = %Node{
          id: id,
          type: type,
          label: label,
          properties: properties,
          context_ids: context_ids
        }
        
        # Update network
        %{network | 
          nodes: Map.put(network.nodes, id, node),
          node_edges: Map.put(network.node_edges, id, [])
        }
    end
  end
  
  @doc """
  Adds an edge to the semantic network.
  
  ## Parameters
  - network: The semantic network
  - source_id: Source node ID
  - target_id: Target node ID
  - relation: Relationship type
  - weight: Edge weight/strength (default: 1.0)
  - properties: Map of edge properties
  - context_ids: List of contexts where this edge is relevant
  - bidirectional: Whether the relationship is bidirectional (default: false)
  
  ## Returns
  Updated network with the new edge
  """
  def add_edge(network, source_id, target_id, relation, weight \\ 1.0,
                properties \\ %{}, context_ids \\ [], bidirectional \\ false) do
    # Validate source and target nodes exist
    unless Map.has_key?(network.nodes, source_id) do
      raise ArgumentError, "Source node #{source_id} does not exist"
    end
    
    unless Map.has_key?(network.nodes, target_id) do
      raise ArgumentError, "Target node #{target_id} does not exist"
    end
    
    # Create edge
    edge = %Edge{
      source_id: source_id,
      target_id: target_id,
      relation: relation,
      weight: weight,
      properties: properties,
      context_ids: context_ids,
      bidirectional: bidirectional
    }
    
    # Create edge key
    edge_key = {source_id, target_id, relation}
    
    # Update network
    updated_network = %{network | 
      edges: Map.put(network.edges, edge_key, edge)
    }
    
    # Update node_edges for source
    source_edges = Map.get(network.node_edges, source_id, [])
    updated_network = %{updated_network |
      node_edges: Map.put(updated_network.node_edges, source_id, [edge_key | source_edges])
    }
    
    # Update node_edges for target if bidirectional
    if bidirectional do
      target_edges = Map.get(network.node_edges, target_id, [])
      %{updated_network |
        node_edges: Map.put(updated_network.node_edges, target_id, [edge_key | target_edges])
      }
    else
      # If not bidirectional, still track the incoming connection
      target_edges = Map.get(network.node_edges, target_id, [])
      %{updated_network |
        node_edges: Map.put(updated_network.node_edges, target_id, [edge_key | target_edges])
      }
    end
  end
  
  @doc """
  Retrieves a node by ID.
  
  ## Parameters
  - network: The semantic network
  - id: Node ID
  
  ## Returns
  The node or nil if not found
  """
  def get_node(network, id) do
    Map.get(network.nodes, id)
  end
  
  @doc """
  Retrieves an edge by source, target, and relation.
  
  ## Parameters
  - network: The semantic network
  - source_id: Source node ID
  - target_id: Target node ID
  - relation: Relationship type
  
  ## Returns
  The edge or nil if not found
  """
  def get_edge(network, source_id, target_id, relation) do
    Map.get(network.edges, {source_id, target_id, relation})
  end
  
  @doc """
  Gets all edges connected to a node.
  
  ## Parameters
  - network: The semantic network
  - node_id: Node ID
  - direction: :outgoing, :incoming, or :both (default: :both)
  
  ## Returns
  List of edges
  """
  def get_connected_edges(network, node_id, direction \\ :both) do
    # Get edge keys for the node
    edge_keys = Map.get(network.node_edges, node_id, [])
    
    # Filter by direction
    filtered_keys = case direction do
      :outgoing ->
        Enum.filter(edge_keys, fn {source, _, _} -> source == node_id end)
        
      :incoming ->
        Enum.filter(edge_keys, fn {_, target, _} -> target == node_id end)
        
      :both ->
        edge_keys
    end
    
    # Get the actual edges
    Enum.map(filtered_keys, fn key -> Map.get(network.edges, key) end)
    |> Enum.filter(&(&1 != nil))
  end
  
  @doc """
  Gets nodes connected to a given node.
  
  ## Parameters
  - network: The semantic network
  - node_id: Node ID
  - relation: Specific relation to filter by (optional)
  - direction: :outgoing, :incoming, or :both (default: :outgoing)
  
  ## Returns
  List of connected nodes
  """
  def get_connected_nodes(network, node_id, relation \\ nil, direction \\ :outgoing) do
    # Get edges
    edges = get_connected_edges(network, node_id, direction)
    
    # Filter by relation if specified
    filtered_edges = if relation do
      Enum.filter(edges, fn edge -> edge.relation == relation end)
    else
      edges
    end
    
    # Get connected node IDs
    connected_ids = Enum.map(filtered_edges, fn edge ->
      if edge.source_id == node_id do
        edge.target_id
      else
        edge.source_id
      end
    end)
    
    # Get the actual nodes
    Enum.map(connected_ids, fn id -> Map.get(network.nodes, id) end)
    |> Enum.filter(&(&1 != nil))
  end
  
  @doc """
  Activates a node and spreads activation to connected nodes.
  
  ## Parameters
  - network: The semantic network
  - node_id: Node ID to activate
  - activation_value: Initial activation value (default: 1.0)
  - spread_factor: Factor for spreading activation (default: 0.5)
  - max_depth: Maximum spreading depth (default: 3)
  
  ## Returns
  Updated network with new activation levels
  """
  def spread_activation(network, node_id, activation_value \\ 1.0, 
                        spread_factor \\ 0.5, max_depth \\ 3) do
    # Initialize activation for the starting node
    initial_activations = Map.put(network.activation_levels, node_id, activation_value)
    
    # Spread activation through the network
    updated_activations = do_spread_activation(
      network, 
      [{node_id, activation_value}], 
      initial_activations,
      spread_factor,
      max_depth,
      0,
      MapSet.new([node_id])  # Visited nodes
    )
    
    # Update network with new activation levels
    %{network | activation_levels: updated_activations}
  end
  
  @doc """
  Gets all active nodes based on the activation threshold.
  
  ## Parameters
  - network: The semantic network
  
  ## Returns
  List of active nodes
  """
  def get_active_nodes(network) do
    Enum.filter(network.activation_levels, fn {_, activation} ->
      activation >= network.activation_threshold
    end)
    |> Enum.map(fn {id, _} -> Map.get(network.nodes, id) end)
    |> Enum.filter(&(&1 != nil))
  end
  
  @doc """
  Filters the network to only include elements relevant to active contexts.
  
  ## Parameters
  - network: The semantic network
  
  ## Returns
  Filtered network with only context-relevant nodes and edges
  """
  def filter_by_active_contexts(network) do
    # Get active contexts
    active_contexts = ContextManager.get_active_contexts(network.context_manager)
    active_context_ids = Enum.map(active_contexts, fn context -> context.id end)
    
    # Filter nodes
    filtered_nodes = Enum.filter(network.nodes, fn {_, node} ->
      # Node is relevant if:
      # 1. It has no specific contexts (globally relevant)
      # 2. Any of its contexts are active
      Enum.empty?(node.context_ids) or
      Enum.any?(node.context_ids, fn context_id ->
        context_id in active_context_ids
      end)
    end) |> Map.new()
    
    # Filter edges
    filtered_edges = Enum.filter(network.edges, fn {_, edge} ->
      # Edge is relevant if:
      # 1. It has no specific contexts (globally relevant)
      # 2. Any of its contexts are active
      # 3. Both source and target nodes are in the filtered nodes
      (Enum.empty?(edge.context_ids) or
       Enum.any?(edge.context_ids, fn context_id ->
         context_id in active_context_ids
       end)) and
      Map.has_key?(filtered_nodes, edge.source_id) and
      Map.has_key?(filtered_nodes, edge.target_id)
    end) |> Map.new()
    
    # Rebuild node_edges map
    filtered_node_edges = Enum.reduce(filtered_edges, %{}, fn {{source, target, relation}, _}, acc ->
      source_edges = Map.get(acc, source, [])
      target_edges = Map.get(acc, target, [])
      edge_key = {source, target, relation}
      
      acc = Map.put(acc, source, [edge_key | source_edges])
      Map.put(acc, target, [edge_key | target_edges])
    end)
    
    # Return filtered network
    %{network |
      nodes: filtered_nodes,
      edges: filtered_edges,
      node_edges: filtered_node_edges
    }
  end
  
  @doc """
  Converts network knowledge to assertions for the inference engine.
  
  ## Parameters
  - network: The semantic network
  
  ## Returns
  Set of assertions representing the network knowledge
  """
  def to_assertions(network) do
    # Start with node assertions
    node_assertions = Enum.flat_map(network.nodes, fn {id, node} ->
      # Create assertion for the node itself
      node_assertion = {:node, [id, node.type]}
      
      # Create assertions for properties
      property_assertions = Enum.map(node.properties, fn {key, value} ->
        {:property, [id, key, value]}
      end)
      
      [node_assertion | property_assertions]
    end)
    
    # Add edge assertions
    edge_assertions = Enum.map(network.edges, fn {_, edge} ->
      {:relation, [edge.source_id, edge.relation, edge.target_id, edge.weight]}
    end)
    
    # Combine all assertions
    (node_assertions ++ edge_assertions) |> MapSet.new()
  end
  
  # Private helper functions
  
  defp do_spread_activation(_, [], activations, _, _, _, _), do: activations
  
  defp do_spread_activation(_, _, activations, _, _, max_depth, _) when max_depth <= 0, do: activations
  
  defp do_spread_activation(network, [{node_id, activation} | rest], activations, 
                           spread_factor, max_depth, current_depth, visited) do
    # Get connected edges
    edges = get_connected_edges(network, node_id)
    
    # Calculate activation to spread to neighbors
    spread_activation = activation * spread_factor
    
    # Determine neighbors to spread activation to
    {new_activations, new_to_spread, new_visited} = Enum.reduce(
      edges,
      {activations, rest, visited},
      fn edge, {act_acc, spread_acc, visit_acc} ->
        # Determine target node
        target_id = if edge.source_id == node_id do
          edge.target_id
        else
          edge.source_id
        end
        
        # Skip if already visited
        if MapSet.member?(visit_acc, target_id) do
          {act_acc, spread_acc, visit_acc}
        else
          # Calculate new activation
          target_activation = spread_activation * edge.weight
          current_activation = Map.get(act_acc, target_id, 0)
          new_activation = current_activation + target_activation
          
          # Update accumulators
          updated_activations = Map.put(act_acc, target_id, new_activation)
          updated_to_spread = [{target_id, target_activation} | spread_acc]
          updated_visited = MapSet.put(visit_acc, target_id)
          
          {updated_activations, updated_to_spread, updated_visited}
        end
      end
    )
    
    # Continue spreading
    do_spread_activation(
      network,
      new_to_spread,
      new_activations,
      spread_factor,
      max_depth,
      current_depth + 1,
      new_visited
    )
  end
end