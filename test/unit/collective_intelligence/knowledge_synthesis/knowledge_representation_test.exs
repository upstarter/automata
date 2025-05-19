defmodule Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeRepresentationTest do
  use ExUnit.Case, async: true
  
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeRepresentation
  alias KnowledgeRepresentation.KnowledgeAtom
  alias KnowledgeRepresentation.KnowledgeTriple
  alias KnowledgeRepresentation.KnowledgeFrame
  alias KnowledgeRepresentation.KnowledgeGraph
  alias KnowledgeRepresentation.HierarchicalConcept
  
  describe "KnowledgeAtom" do
    test "creates a new knowledge atom" do
      content = "This is a test"
      source = :test_source
      
      atom = KnowledgeAtom.new(content, source)
      
      assert atom.content == content
      assert atom.source == source
      assert atom.confidence == 1.0  # Default value
      assert is_map(atom.metadata)
      assert is_map(atom.context)
      assert String.starts_with?(atom.id, "ka_")
    end
    
    test "creates a new knowledge atom with options" do
      content = "This is a test"
      source = :test_source
      id = "custom_id"
      confidence = 0.9
      metadata = %{key: "value"}
      context = %{domain: "test"}
      
      atom = KnowledgeAtom.new(content, source, [
        id: id,
        confidence: confidence,
        metadata: metadata,
        context: context
      ])
      
      assert atom.content == content
      assert atom.source == source
      assert atom.confidence == confidence
      assert atom.id == id
      assert atom.metadata == metadata
      assert atom.context == context
    end
    
    test "updates confidence" do
      atom = KnowledgeAtom.new("test", :source, confidence: 0.8)
      updated_atom = KnowledgeAtom.update_confidence(atom, 0.9)
      
      # Should be a weighted average: 0.8 * 0.7 + 0.9 * 0.3 = 0.56 + 0.27 = 0.83
      assert_in_delta updated_atom.confidence, 0.83, 0.001
      
      # Original atom should be unchanged
      assert atom.confidence == 0.8
    end
    
    test "adds metadata" do
      atom = KnowledgeAtom.new("test", :source)
      updated_atom = KnowledgeAtom.add_metadata(atom, :key, "value")
      
      assert updated_atom.metadata.key == "value"
      assert Map.keys(atom.metadata) == []  # Original should be unchanged
    end
    
    test "adds context" do
      atom = KnowledgeAtom.new("test", :source)
      updated_atom = KnowledgeAtom.add_context(atom, :domain, "test_domain")
      
      assert updated_atom.context.domain == "test_domain"
      assert Map.keys(atom.context) == []  # Original should be unchanged
    end
  end
  
  describe "KnowledgeTriple" do
    test "creates a new knowledge triple" do
      subject = :entity1
      predicate = :relates_to
      object = :entity2
      source = :test_source
      
      triple = KnowledgeTriple.new(subject, predicate, object, source)
      
      assert triple.subject == subject
      assert triple.predicate == predicate
      assert triple.object == object
      assert triple.source == source
      assert triple.confidence == 1.0  # Default value
      assert is_map(triple.metadata)
      assert is_map(triple.context)
      assert String.starts_with?(triple.id, "kt_")
    end
    
    test "creates a new knowledge triple with options" do
      subject = :entity1
      predicate = :relates_to
      object = :entity2
      source = :test_source
      id = "custom_id"
      confidence = 0.9
      metadata = %{key: "value"}
      context = %{domain: "test"}
      
      triple = KnowledgeTriple.new(subject, predicate, object, source, [
        id: id,
        confidence: confidence,
        metadata: metadata,
        context: context
      ])
      
      assert triple.subject == subject
      assert triple.predicate == predicate
      assert triple.object == object
      assert triple.source == source
      assert triple.confidence == confidence
      assert triple.id == id
      assert triple.metadata == metadata
      assert triple.context == context
    end
    
    test "updates confidence" do
      triple = KnowledgeTriple.new(:entity1, :relates_to, :entity2, :source, confidence: 0.8)
      updated_triple = KnowledgeTriple.update_confidence(triple, 0.9)
      
      # Should be a weighted average: 0.8 * 0.7 + 0.9 * 0.3 = 0.56 + 0.27 = 0.83
      assert_in_delta updated_triple.confidence, 0.83, 0.001
      
      # Original triple should be unchanged
      assert triple.confidence == 0.8
    end
    
    test "creates inverse triple" do
      triple = KnowledgeTriple.new(:person, :parent_of, :child, :source)
      inverse = KnowledgeTriple.inverse(triple)
      
      assert inverse.subject == :child
      assert inverse.predicate == :child_of  # Inferred inverse predicate
      assert inverse.object == :person
      assert inverse.confidence == triple.confidence
      assert inverse.source == triple.source
    end
    
    test "creates inverse triple with specified predicate" do
      triple = KnowledgeTriple.new(:entity1, :custom_relation, :entity2, :source)
      inverse = KnowledgeTriple.inverse(triple, :inverse_custom_relation)
      
      assert inverse.subject == :entity2
      assert inverse.predicate == :inverse_custom_relation
      assert inverse.object == :entity1
    end
  end
  
  describe "KnowledgeFrame" do
    test "creates a new knowledge frame" do
      name = "Test Frame"
      
      frame = KnowledgeFrame.new(name)
      
      assert frame.name == name
      assert frame.slots == %{}  # Empty slots
      assert frame.parent == nil  # No parent
      assert frame.confidence == 1.0  # Default value
      assert frame.source == :system  # Default value
      assert is_map(frame.metadata)
      assert String.starts_with?(frame.id, "kf_")
    end
    
    test "creates a new knowledge frame with slots" do
      name = "Test Frame"
      slots = %{
        name: "John",
        age: 30
      }
      
      frame = KnowledgeFrame.new(name, slots)
      
      assert frame.name == name
      assert frame.slots.name.value == "John"
      assert frame.slots.age.value == 30
    end
    
    test "creates a new knowledge frame with options" do
      name = "Test Frame"
      parent = "parent_frame"
      source = :test_source
      
      frame = KnowledgeFrame.new(name, %{}, [
        parent: parent,
        source: source
      ])
      
      assert frame.name == name
      assert frame.parent == parent
      assert frame.source == source
    end
    
    test "gets a slot value" do
      frame = KnowledgeFrame.new("Test", %{name: "John", age: 30})
      
      assert KnowledgeFrame.get_slot(frame, :name) == "John"
      assert KnowledgeFrame.get_slot(frame, :age) == 30
      assert KnowledgeFrame.get_slot(frame, :nonexistent) == nil
    end
    
    test "sets a slot value" do
      frame = KnowledgeFrame.new("Test", %{name: "John"})
      
      # Set existing slot
      updated_frame = KnowledgeFrame.set_slot(frame, :name, "Jane")
      assert KnowledgeFrame.get_slot(updated_frame, :name) == "Jane"
      
      # Set new slot
      updated_frame = KnowledgeFrame.set_slot(frame, :age, 30)
      assert KnowledgeFrame.get_slot(updated_frame, :age) == 30
    end
    
    test "adds a constraint to a slot" do
      frame = KnowledgeFrame.new("Test", %{age: 30})
      
      # Add constraint
      updated_frame = KnowledgeFrame.add_constraint(frame, :age, {:range, 0, 120})
      
      # Constraint should be added
      assert hd(updated_frame.slots.age.constraints) == {:range, 0, 120}
    end
    
    test "merges two frames" do
      frame1 = KnowledgeFrame.new("Frame1", %{
        name: "John",
        age: 30
      }, source: :source1)
      
      frame2 = KnowledgeFrame.new("Frame2", %{
        name: "Jane",
        height: 175
      }, source: :source2)
      
      merged = KnowledgeFrame.merge(frame1, frame2)
      
      # Merged frame should contain all slots
      assert KnowledgeFrame.get_slot(merged, :name) == "John"  # frame1 has higher confidence by default
      assert KnowledgeFrame.get_slot(merged, :age) == 30
      assert KnowledgeFrame.get_slot(merged, :height) == 175
      
      # Source should include both sources
      assert merged.source == [:source1, :source2]
    end
  end
  
  describe "KnowledgeGraph" do
    test "creates a new knowledge graph" do
      name = "Test Graph"
      
      graph = KnowledgeGraph.new(name)
      
      assert graph.name == name
      assert graph.entities == %{}  # Empty entities
      assert graph.relationships == %{}  # Empty relationships
      assert is_map(graph.metadata)
      assert String.starts_with?(graph.id, "kg_")
    end
    
    test "adds an entity to the graph" do
      graph = KnowledgeGraph.new("Test Graph")
      
      updated_graph = KnowledgeGraph.add_entity(graph, :person, %{name: "John", age: 30})
      
      # Entity should be added
      assert map_size(updated_graph.entities) == 1
      entity_id = hd(Map.keys(updated_graph.entities))
      entity = updated_graph.entities[entity_id]
      
      assert entity.type == :person
      assert entity.properties.name == "John"
      assert entity.properties.age == 30
    end
    
    test "adds a relationship to the graph" do
      graph = KnowledgeGraph.new("Test Graph")
      
      # Add entities
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "John"})
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "Jane"})
      
      # Get entity IDs
      [entity1_id, entity2_id] = Map.keys(graph.entities)
      
      # Add relationship
      updated_graph = KnowledgeGraph.add_relationship(
        graph, :knows, entity1_id, entity2_id, %{since: 2020}
      )
      
      # Relationship should be added
      assert map_size(updated_graph.relationships) == 1
      rel_id = hd(Map.keys(updated_graph.relationships))
      relationship = updated_graph.relationships[rel_id]
      
      assert relationship.type == :knows
      assert relationship.from == entity1_id
      assert relationship.to == entity2_id
      assert relationship.properties.since == 2020
    end
    
    test "gets entity relationships" do
      graph = KnowledgeGraph.new("Test Graph")
      
      # Add entities
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "John"})
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "Jane"})
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "Bob"})
      
      # Get entity IDs
      [john_id, jane_id, bob_id] = Map.keys(graph.entities)
      
      # Add relationships
      graph = KnowledgeGraph.add_relationship(graph, :knows, john_id, jane_id)
      graph = KnowledgeGraph.add_relationship(graph, :knows, bob_id, john_id)
      
      # Get relationships for John
      relationships = KnowledgeGraph.get_entity_relationships(graph, john_id)
      
      # Should have two relationships (one outgoing, one incoming)
      assert map_size(relationships) == 2
      
      # Check directions
      outgoing = Enum.find(relationships, fn {_id, rel} -> rel.direction == :outgoing end)
      incoming = Enum.find(relationships, fn {_id, rel} -> rel.direction == :incoming end)
      
      assert elem(outgoing, 1).to == jane_id
      assert elem(incoming, 1).from == bob_id
    end
    
    test "finds paths between entities" do
      graph = KnowledgeGraph.new("Test Graph")
      
      # Add entities
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "John"})
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "Jane"})
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "Bob"})
      
      # Get entity IDs
      [john_id, jane_id, bob_id] = Map.keys(graph.entities)
      
      # Add relationships to form a path: John -> Jane -> Bob
      graph = KnowledgeGraph.add_relationship(graph, :knows, john_id, jane_id)
      graph = KnowledgeGraph.add_relationship(graph, :knows, jane_id, bob_id)
      
      # Find paths
      {:ok, paths} = KnowledgeGraph.find_paths(graph, john_id, bob_id)
      
      # Should find a path
      assert length(paths) == 1
      
      # Check the path
      path = hd(paths)
      assert path == [john_id, jane_id, bob_id]
    end
    
    test "merges two graphs" do
      # Create first graph
      graph1 = KnowledgeGraph.new("Graph1")
      graph1 = KnowledgeGraph.add_entity(graph1, :person, %{name: "John"})
      
      # Create second graph with same entity
      graph2 = KnowledgeGraph.new("Graph2")
      graph2 = KnowledgeGraph.add_entity(graph2, :person, %{name: "John"})
      graph2 = KnowledgeGraph.add_entity(graph2, :person, %{name: "Jane"})
      
      # Merge graphs
      merged = KnowledgeGraph.merge(graph1, graph2)
      
      # Should have two entities (John only counted once)
      assert map_size(merged.entities) == 2
      
      # Check entity names
      entity_names = merged.entities
      |> Map.values()
      |> Enum.map(fn entity -> entity.properties.name end)
      |> Enum.sort()
      
      assert entity_names == ["Jane", "John"]
    end
  end
  
  describe "HierarchicalConcept" do
    test "creates a new hierarchical concept" do
      name = "Test Concept"
      description = "A test concept"
      
      concept = HierarchicalConcept.new(name, description)
      
      assert concept.name == name
      assert concept.description == description
      assert concept.parent_id == nil  # No parent
      assert concept.children_ids == []  # No children
      assert concept.attributes == %{}  # No attributes
      assert concept.relations == %{}  # No relations
      assert concept.confidence == 1.0  # Default value
      assert concept.source == :system  # Default value
      assert is_map(concept.metadata)
      assert String.starts_with?(concept.id, "hc_")
    end
    
    test "creates a new hierarchical concept with options" do
      name = "Test Concept"
      description = "A test concept"
      parent_id = "parent_concept"
      attributes = %{key: "value"}
      
      concept = HierarchicalConcept.new(name, description, [
        parent_id: parent_id,
        attributes: attributes
      ])
      
      assert concept.name == name
      assert concept.description == description
      assert concept.parent_id == parent_id
      assert concept.attributes == attributes
    end
    
    test "adds a child concept" do
      parent = HierarchicalConcept.new("Parent", "Parent concept")
      child = HierarchicalConcept.new("Child", "Child concept")
      
      {updated_parent, updated_child} = HierarchicalConcept.add_child(parent, child)
      
      # Parent should have child in children_ids
      assert updated_parent.children_ids == [child.id]
      
      # Child should have parent as parent_id
      assert updated_child.parent_id == parent.id
    end
    
    test "adds an attribute to a concept" do
      concept = HierarchicalConcept.new("Test", "Test concept")
      
      updated_concept = HierarchicalConcept.add_attribute(concept, :color, "blue", 0.9)
      
      # Attribute should be added
      assert updated_concept.attributes.color.value == "blue"
      assert updated_concept.attributes.color.confidence == 0.9
    end
    
    test "adds a relation to another concept" do
      concept1 = HierarchicalConcept.new("Concept1", "First concept")
      concept2 = HierarchicalConcept.new("Concept2", "Second concept")
      
      updated_concept = HierarchicalConcept.add_relation(
        concept1, :related_to, concept2.id, %{strength: 0.8}
      )
      
      # Relation should be added
      assert hd(updated_concept.relations.related_to).target_id == concept2.id
      assert hd(updated_concept.relations.related_to).metadata.strength == 0.8
    end
    
    test "inherits attributes from parent" do
      parent = HierarchicalConcept.new("Parent", "Parent concept")
      |> HierarchicalConcept.add_attribute(:color, "blue", 1.0)
      |> HierarchicalConcept.add_attribute(:size, "large", 1.0)
      
      child = HierarchicalConcept.new("Child", "Child concept")
      |> HierarchicalConcept.add_attribute(:color, "red", 1.0)  # Override parent's color
      
      updated_child = HierarchicalConcept.inherit_attributes(child, parent)
      
      # Child should keep its own color
      assert updated_child.attributes.color.value == "red"
      
      # Child should inherit parent's size with reduced confidence
      assert updated_child.attributes.size.value == "large"
      assert_in_delta updated_child.attributes.size.confidence, 0.9, 0.001
      assert updated_child.attributes.size.inherited == true
    end
  end
end