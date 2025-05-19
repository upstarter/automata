defmodule Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeRepresentation do
  @moduledoc """
  Implements advanced knowledge representation mechanisms for collective intelligence.
  
  This module provides a unified framework for representing knowledge at multiple levels
  of abstraction, from raw data to high-level concepts, enabling effective integration
  and synthesis of knowledge from distributed sources.
  """
  
  defmodule KnowledgeAtom do
    @moduledoc """
    Represents an atomic unit of knowledge with associated metadata.
    
    Knowledge atoms are the basic building blocks of the knowledge representation system,
    capturing discrete facts or assertions with provenance, confidence, and other metadata.
    """
    
    @type t :: %__MODULE__{
      id: String.t(),
      content: term(),
      confidence: float(),
      source: term(),
      timestamp: DateTime.t(),
      metadata: map(),
      context: map()
    }
    
    defstruct [
      :id,
      :content,
      :confidence,
      :source,
      :timestamp,
      :metadata,
      :context
    ]
    
    @doc """
    Creates a new knowledge atom.
    """
    def new(content, source, opts \\ []) do
      id = Keyword.get(opts, :id, generate_id())
      confidence = Keyword.get(opts, :confidence, 1.0)
      metadata = Keyword.get(opts, :metadata, %{})
      context = Keyword.get(opts, :context, %{})
      
      %__MODULE__{
        id: id,
        content: content,
        confidence: confidence,
        source: source,
        timestamp: DateTime.utc_now(),
        metadata: metadata,
        context: context
      }
    end
    
    @doc """
    Updates a knowledge atom's confidence based on new evidence.
    """
    def update_confidence(atom, new_confidence) do
      # Simple weighted average for confidence update
      alpha = 0.7  # Weight for existing confidence
      updated_confidence = alpha * atom.confidence + (1 - alpha) * new_confidence
      
      %{atom | 
        confidence: updated_confidence,
        timestamp: DateTime.utc_now()
      }
    end
    
    @doc """
    Adds metadata to a knowledge atom.
    """
    def add_metadata(atom, key, value) do
      updated_metadata = Map.put(atom.metadata, key, value)
      
      %{atom | 
        metadata: updated_metadata,
        timestamp: DateTime.utc_now()
      }
    end
    
    @doc """
    Adds context information to a knowledge atom.
    """
    def add_context(atom, key, value) do
      updated_context = Map.put(atom.context, key, value)
      
      %{atom | 
        context: updated_context,
        timestamp: DateTime.utc_now()
      }
    end
    
    # Private functions
    
    defp generate_id do
      "ka_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    end
  end
  
  defmodule KnowledgeTriple do
    @moduledoc """
    Represents a knowledge triple (subject-predicate-object) with additional metadata.
    
    Knowledge triples express relationships between entities, forming the basis for
    semantic networks and knowledge graphs.
    """
    
    @type t :: %__MODULE__{
      id: String.t(),
      subject: term(),
      predicate: term(),
      object: term(),
      confidence: float(),
      source: term(),
      timestamp: DateTime.t(),
      metadata: map(),
      context: map()
    }
    
    defstruct [
      :id,
      :subject,
      :predicate,
      :object,
      :confidence,
      :source,
      :timestamp,
      :metadata,
      :context
    ]
    
    @doc """
    Creates a new knowledge triple.
    """
    def new(subject, predicate, object, source, opts \\ []) do
      id = Keyword.get(opts, :id, generate_id())
      confidence = Keyword.get(opts, :confidence, 1.0)
      metadata = Keyword.get(opts, :metadata, %{})
      context = Keyword.get(opts, :context, %{})
      
      %__MODULE__{
        id: id,
        subject: subject,
        predicate: predicate,
        object: object,
        confidence: confidence,
        source: source,
        timestamp: DateTime.utc_now(),
        metadata: metadata,
        context: context
      }
    end
    
    @doc """
    Updates a triple's confidence based on new evidence.
    """
    def update_confidence(triple, new_confidence) do
      # Simple weighted average for confidence update
      alpha = 0.7  # Weight for existing confidence
      updated_confidence = alpha * triple.confidence + (1 - alpha) * new_confidence
      
      %{triple | 
        confidence: updated_confidence,
        timestamp: DateTime.utc_now()
      }
    end
    
    @doc """
    Creates an inverse triple (with subject and object swapped).
    """
    def inverse(triple, inverse_predicate \\ nil) do
      pred = inverse_predicate || infer_inverse_predicate(triple.predicate)
      
      %__MODULE__{
        id: generate_id(),
        subject: triple.object,
        predicate: pred,
        object: triple.subject,
        confidence: triple.confidence,
        source: triple.source,
        timestamp: DateTime.utc_now(),
        metadata: triple.metadata,
        context: triple.context
      }
    end
    
    # Private functions
    
    defp generate_id do
      "kt_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    end
    
    defp infer_inverse_predicate(predicate) do
      # Map common predicates to their inverses
      case predicate do
        :contains -> :contained_in
        :parent_of -> :child_of
        :part_of -> :has_part
        :causes -> :caused_by
        :before -> :after
        :greater_than -> :less_than
        :above -> :below
        pred when is_binary(pred) ->
          cond do
            String.contains?(pred, "contains") -> String.replace(pred, "contains", "contained in")
            String.contains?(pred, "parent") -> String.replace(pred, "parent", "child")
            String.contains?(pred, "causes") -> String.replace(pred, "causes", "caused by")
            true -> "inverse_of_#{pred}"
          end
        _ -> :"inverse_of_#{predicate}"
      end
    end
  end
  
  defmodule KnowledgeFrame do
    @moduledoc """
    Represents a structured frame of knowledge with slots and values.
    
    Knowledge frames organize information about concepts or entities in a template-like
    structure, with named slots containing values or default values.
    """
    
    @type t :: %__MODULE__{
      id: String.t(),
      name: String.t(),
      slots: %{atom() => slot()},
      parent: String.t() | nil,
      confidence: float(),
      source: term(),
      timestamp: DateTime.t(),
      metadata: map()
    }
    
    @type slot :: %{
      value: term(),
      default: term() | nil,
      constraints: list(term()),
      confidence: float()
    }
    
    defstruct [
      :id,
      :name,
      :slots,
      :parent,
      :confidence,
      :source,
      :timestamp,
      :metadata
    ]
    
    @doc """
    Creates a new knowledge frame.
    """
    def new(name, slots \\ %{}, opts \\ []) do
      id = Keyword.get(opts, :id, generate_id())
      parent = Keyword.get(opts, :parent, nil)
      confidence = Keyword.get(opts, :confidence, 1.0)
      source = Keyword.get(opts, :source, :system)
      metadata = Keyword.get(opts, :metadata, %{})
      
      # Ensure slots have the correct structure
      formatted_slots = Enum.map(slots, fn {key, value} ->
        {key, format_slot(value)}
      end)
      |> Enum.into(%{})
      
      %__MODULE__{
        id: id,
        name: name,
        slots: formatted_slots,
        parent: parent,
        confidence: confidence,
        source: source,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }
    end
    
    @doc """
    Gets a slot value from a frame.
    """
    def get_slot(frame, slot_name) do
      case Map.get(frame.slots, slot_name) do
        nil -> nil
        slot -> slot.value
      end
    end
    
    @doc """
    Sets a slot value in a frame.
    """
    def set_slot(frame, slot_name, value, confidence \\ 1.0) do
      case Map.get(frame.slots, slot_name) do
        nil ->
          # Create a new slot
          slot = %{
            value: value,
            default: nil,
            constraints: [],
            confidence: confidence
          }
          
          updated_slots = Map.put(frame.slots, slot_name, slot)
          %{frame | slots: updated_slots, timestamp: DateTime.utc_now()}
          
        existing_slot ->
          # Update existing slot
          if valid_value?(value, existing_slot.constraints) do
            updated_slot = %{existing_slot | value: value, confidence: confidence}
            updated_slots = Map.put(frame.slots, slot_name, updated_slot)
            %{frame | slots: updated_slots, timestamp: DateTime.utc_now()}
          else
            {:error, :constraint_violation}
          end
      end
    end
    
    @doc """
    Adds a constraint to a slot.
    """
    def add_constraint(frame, slot_name, constraint) do
      case Map.get(frame.slots, slot_name) do
        nil ->
          {:error, :slot_not_found}
          
        slot ->
          updated_constraints = [constraint | slot.constraints]
          updated_slot = %{slot | constraints: updated_constraints}
          
          # Revalidate current value
          if valid_value?(slot.value, updated_constraints) do
            updated_slots = Map.put(frame.slots, slot_name, updated_slot)
            %{frame | slots: updated_slots, timestamp: DateTime.utc_now()}
          else
            # Reset to default if constraint violation
            updated_slot = %{updated_slot | value: slot.default}
            updated_slots = Map.put(frame.slots, slot_name, updated_slot)
            %{frame | slots: updated_slots, timestamp: DateTime.utc_now()}
          end
      end
    end
    
    @doc """
    Merges two frames, combining their slots.
    """
    def merge(frame1, frame2) do
      # Merge slots, favoring higher confidence values
      merged_slots = Map.merge(frame1.slots, frame2.slots, fn _k, slot1, slot2 ->
        if slot1.confidence >= slot2.confidence do
          slot1
        else
          slot2
        end
      end)
      
      # Calculate average confidence
      avg_confidence = (frame1.confidence + frame2.confidence) / 2
      
      # Create merged frame
      %__MODULE__{
        id: generate_id(),
        name: "#{frame1.name}_and_#{frame2.name}",
        slots: merged_slots,
        parent: nil,  # No parent for merged frame
        confidence: avg_confidence,
        source: [frame1.source, frame2.source],
        timestamp: DateTime.utc_now(),
        metadata: Map.merge(frame1.metadata, frame2.metadata)
      }
    end
    
    # Private functions
    
    defp generate_id do
      "kf_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    end
    
    defp format_slot(value) when is_map(value) do
      # Handle case when value is already a slot
      if Map.has_key?(value, :value) and Map.has_key?(value, :confidence) do
        defaults = %{default: nil, constraints: []}
        Map.merge(defaults, value)
      else
        # Treat map as value
        %{
          value: value,
          default: nil,
          constraints: [],
          confidence: 1.0
        }
      end
    end
    
    defp format_slot(value) do
      # Simple value
      %{
        value: value,
        default: nil,
        constraints: [],
        confidence: 1.0
      }
    end
    
    defp valid_value?(_value, []), do: true
    
    defp valid_value?(value, constraints) do
      Enum.all?(constraints, fn constraint ->
        case constraint do
          {:type, type} -> 
            case type do
              :string -> is_binary(value)
              :number -> is_number(value)
              :integer -> is_integer(value)
              :float -> is_float(value)
              :boolean -> is_boolean(value)
              :list -> is_list(value)
              :map -> is_map(value)
              _ -> true
            end
            
          {:range, min, max} when is_number(value) -> 
            value >= min and value <= max
            
          {:enum, values} -> 
            value in values
            
          {:regex, pattern} when is_binary(value) ->
            Regex.match?(pattern, value)
            
          {:length, min, max} when is_binary(value) or is_list(value) ->
            len = if is_binary(value), do: String.length(value), else: length(value)
            len >= min and len <= max
            
          {:custom, func} when is_function(func, 1) ->
            func.(value)
            
          _ -> true
        end
      end)
    end
  end
  
  defmodule KnowledgeGraph do
    @moduledoc """
    Represents a knowledge graph composed of entities and relationships.
    
    Knowledge graphs provide a network representation of knowledge, with entities
    as nodes and relationships as directed edges, enabling complex queries and inference.
    """
    
    @type t :: %__MODULE__{
      id: String.t(),
      name: String.t(),
      entities: map(),  # Map of entity IDs to entities
      relationships: map(),  # Map of relationship IDs to relationships
      metadata: map(),
      timestamp: DateTime.t()
    }
    
    @type entity :: %{
      id: String.t(),
      type: atom() | String.t(),
      properties: map(),
      confidence: float()
    }
    
    @type relationship :: %{
      id: String.t(),
      type: atom() | String.t(),
      from: String.t(),
      to: String.t(),
      properties: map(),
      confidence: float()
    }
    
    defstruct [
      :id,
      :name,
      :entities,
      :relationships,
      :metadata,
      :timestamp
    ]
    
    @doc """
    Creates a new knowledge graph.
    """
    def new(name, opts \\ []) do
      id = Keyword.get(opts, :id, generate_id())
      metadata = Keyword.get(opts, :metadata, %{})
      
      %__MODULE__{
        id: id,
        name: name,
        entities: %{},
        relationships: %{},
        metadata: metadata,
        timestamp: DateTime.utc_now()
      }
    end
    
    @doc """
    Adds an entity to the graph.
    """
    def add_entity(graph, type, properties, opts \\ []) do
      id = Keyword.get(opts, :id, generate_entity_id(type))
      confidence = Keyword.get(opts, :confidence, 1.0)
      
      entity = %{
        id: id,
        type: type,
        properties: properties,
        confidence: confidence
      }
      
      updated_entities = Map.put(graph.entities, id, entity)
      
      %{graph | 
        entities: updated_entities,
        timestamp: DateTime.utc_now()
      }
    end
    
    @doc """
    Adds a relationship between two entities.
    """
    def add_relationship(graph, type, from_id, to_id, properties \\ %{}, opts \\ []) do
      # Ensure entities exist
      unless Map.has_key?(graph.entities, from_id) and Map.has_key?(graph.entities, to_id) do
        {:error, :entities_not_found}
      else
        id = Keyword.get(opts, :id, generate_relationship_id(type))
        confidence = Keyword.get(opts, :confidence, 1.0)
        
        relationship = %{
          id: id,
          type: type,
          from: from_id,
          to: to_id,
          properties: properties,
          confidence: confidence
        }
        
        updated_relationships = Map.put(graph.relationships, id, relationship)
        
        %{graph | 
          relationships: updated_relationships,
          timestamp: DateTime.utc_now()
        }
      end
    end
    
    @doc """
    Gets all relationships for an entity.
    """
    def get_entity_relationships(graph, entity_id) do
      # Get outgoing relationships
      outgoing = Enum.filter(graph.relationships, fn {_id, rel} ->
        rel.from == entity_id
      end)
      |> Enum.map(fn {id, rel} -> {id, Map.put(rel, :direction, :outgoing)} end)
      |> Enum.into(%{})
      
      # Get incoming relationships
      incoming = Enum.filter(graph.relationships, fn {_id, rel} ->
        rel.to == entity_id
      end)
      |> Enum.map(fn {id, rel} -> {id, Map.put(rel, :direction, :incoming)} end)
      |> Enum.into(%{})
      
      # Combine relationships
      Map.merge(outgoing, incoming)
    end
    
    @doc """
    Finds paths between two entities.
    """
    def find_paths(graph, from_id, to_id, max_depth \\ 3) do
      # Check if entities exist
      unless Map.has_key?(graph.entities, from_id) and Map.has_key?(graph.entities, to_id) do
        {:error, :entities_not_found}
      else
        # Run breadth-first search to find paths
        paths = bfs_paths(graph, from_id, to_id, max_depth)
        
        {:ok, paths}
      end
    end
    
    @doc """
    Merges two knowledge graphs.
    """
    def merge(graph1, graph2) do
      # Merge entities, keeping higher confidence versions
      merged_entities = Map.merge(graph1.entities, graph2.entities, fn _k, e1, e2 ->
        if e1.confidence >= e2.confidence, do: e1, else: e2
      end)
      
      # Merge relationships, handling conflicts
      merged_relationships = Map.merge(graph1.relationships, graph2.relationships, fn _k, r1, r2 ->
        if r1.confidence >= r2.confidence, do: r1, else: r2
      end)
      
      # Create merged graph
      %__MODULE__{
        id: generate_id(),
        name: "#{graph1.name}_and_#{graph2.name}",
        entities: merged_entities,
        relationships: merged_relationships,
        metadata: Map.merge(graph1.metadata, graph2.metadata),
        timestamp: DateTime.utc_now()
      }
    end
    
    # Private functions
    
    defp generate_id do
      "kg_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    end
    
    defp generate_entity_id(type) do
      type_str = if is_atom(type), do: Atom.to_string(type), else: type
      "#{type_str}_" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
    end
    
    defp generate_relationship_id(type) do
      type_str = if is_atom(type), do: Atom.to_string(type), else: type
      "rel_#{type_str}_" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
    end
    
    defp bfs_paths(graph, start, target, max_depth) do
      initial_path = [start]
      queue = :queue.in(initial_path, :queue.new())
      visited = MapSet.new([start])
      
      bfs_paths_recursive(graph, queue, visited, target, max_depth, [])
    end
    
    defp bfs_paths_recursive(_graph, queue, _visited, _target, _max_depth, paths) when queue == :queue.new() do
      paths
    end
    
    defp bfs_paths_recursive(_graph, _queue, _visited, _target, 0, paths) do
      paths
    end
    
    defp bfs_paths_recursive(graph, queue, visited, target, max_depth, paths) do
      {{:value, current_path}, rest_queue} = :queue.out(queue)
      current_node = List.last(current_path)
      
      if current_node == target do
        # Found a path to target
        bfs_paths_recursive(graph, rest_queue, visited, target, max_depth, [current_path | paths])
      else
        # Get neighbors (connected through relationships)
        neighbors = get_neighbors(graph, current_node)
        
        # Process each neighbor
        {new_queue, new_visited} = Enum.reduce(neighbors, {rest_queue, visited}, fn {neighbor, _rel}, {q, v} ->
          if MapSet.member?(v, neighbor) do
            {q, v}  # Already visited
          else
            new_path = current_path ++ [neighbor]
            new_q = :queue.in(new_path, q)
            new_v = MapSet.put(v, neighbor)
            {new_q, new_v}
          end
        end)
        
        # Continue search
        bfs_paths_recursive(graph, new_queue, new_visited, target, max_depth - 1, paths)
      end
    end
    
    defp get_neighbors(graph, node_id) do
      # Get outgoing relationships
      outgoing = Enum.filter(graph.relationships, fn {_id, rel} ->
        rel.from == node_id
      end)
      |> Enum.map(fn {_id, rel} -> {rel.to, rel} end)
      
      # Get incoming relationships
      incoming = Enum.filter(graph.relationships, fn {_id, rel} ->
        rel.to == node_id
      end)
      |> Enum.map(fn {_id, rel} -> {rel.from, rel} end)
      
      # Combine both sets of neighbors
      outgoing ++ incoming
    end
  end
  
  defmodule HierarchicalConcept do
    @moduledoc """
    Represents a hierarchically organized concept with parent-child relationships.
    
    Hierarchical concepts enable taxonomic organization of knowledge, supporting
    inheritance, abstraction/specialization, and multilevel reasoning.
    """
    
    @type t :: %__MODULE__{
      id: String.t(),
      name: String.t(),
      description: String.t(),
      parent_id: String.t() | nil,
      children_ids: list(String.t()),
      attributes: map(),
      relations: map(),  # Map of relation type to related concept IDs
      confidence: float(),
      source: term(),
      timestamp: DateTime.t(),
      metadata: map()
    }
    
    defstruct [
      :id,
      :name,
      :description,
      :parent_id,
      :children_ids,
      :attributes,
      :relations,
      :confidence,
      :source,
      :timestamp,
      :metadata
    ]
    
    @doc """
    Creates a new hierarchical concept.
    """
    def new(name, description, opts \\ []) do
      id = Keyword.get(opts, :id, generate_id())
      parent_id = Keyword.get(opts, :parent_id, nil)
      attributes = Keyword.get(opts, :attributes, %{})
      relations = Keyword.get(opts, :relations, %{})
      confidence = Keyword.get(opts, :confidence, 1.0)
      source = Keyword.get(opts, :source, :system)
      metadata = Keyword.get(opts, :metadata, %{})
      
      %__MODULE__{
        id: id,
        name: name,
        description: description,
        parent_id: parent_id,
        children_ids: [],
        attributes: attributes,
        relations: relations,
        confidence: confidence,
        source: source,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }
    end
    
    @doc """
    Adds a child concept to a parent concept.
    """
    def add_child(parent, child) do
      # Update parent with new child
      updated_parent = %{parent | 
        children_ids: [child.id | parent.children_ids],
        timestamp: DateTime.utc_now()
      }
      
      # Update child with parent reference
      updated_child = %{child | 
        parent_id: parent.id,
        timestamp: DateTime.utc_now()
      }
      
      {updated_parent, updated_child}
    end
    
    @doc """
    Adds an attribute to a concept.
    """
    def add_attribute(concept, key, value, confidence \\ 1.0) do
      # Add or update attribute
      updated_attributes = Map.put(concept.attributes, key, %{
        value: value,
        confidence: confidence
      })
      
      %{concept | 
        attributes: updated_attributes,
        timestamp: DateTime.utc_now()
      }
    end
    
    @doc """
    Adds a relation to another concept.
    """
    def add_relation(concept, relation_type, target_id, metadata \\ %{}) do
      # Get existing relations of this type
      existing_relations = Map.get(concept.relations, relation_type, [])
      
      # Check if relation already exists
      unless Enum.any?(existing_relations, fn rel -> rel.target_id == target_id end) do
        # Create new relation
        new_relation = %{
          target_id: target_id,
          metadata: metadata,
          timestamp: DateTime.utc_now()
        }
        
        # Update relations
        updated_relations = Map.put(
          concept.relations,
          relation_type,
          [new_relation | existing_relations]
        )
        
        # Update concept
        %{concept | 
          relations: updated_relations,
          timestamp: DateTime.utc_now()
        }
      else
        # Relation already exists
        concept
      end
    end
    
    @doc """
    Inherits attributes from parent concept.
    """
    def inherit_attributes(concept, parent) do
      # Merge attributes, prioritizing child's existing attributes
      inherited_attributes = Enum.reduce(parent.attributes, concept.attributes, fn {key, attr}, acc ->
        if Map.has_key?(acc, key) do
          # Child already has this attribute
          acc
        else
          # Inherit with slightly reduced confidence
          inherited_attr = %{
            value: attr.value,
            confidence: attr.confidence * 0.9,
            inherited: true
          }
          
          Map.put(acc, key, inherited_attr)
        end
      end)
      
      %{concept | 
        attributes: inherited_attributes,
        timestamp: DateTime.utc_now()
      }
    end
    
    # Private functions
    
    defp generate_id do
      "hc_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    end
  end
end