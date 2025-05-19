defmodule Automata.CollectiveIntelligence.KnowledgeSynthesis.MultilevelKnowledgeStoreTest do
  use ExUnit.Case
  
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeRepresentation
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.MultilevelKnowledgeStore
  
  alias KnowledgeRepresentation.KnowledgeAtom
  alias KnowledgeRepresentation.KnowledgeTriple
  alias KnowledgeRepresentation.KnowledgeFrame
  alias KnowledgeRepresentation.KnowledgeGraph
  alias KnowledgeRepresentation.HierarchicalConcept
  
  @moduletag :capture_log
  
  setup do
    # Start a store with a unique name for each test
    store_name = :"TestStore#{:erlang.unique_integer([:positive])}"
    
    {:ok, store} = MultilevelKnowledgeStore.start_link(
      name: store_name,
      auto_synthesis: false,  # Disable auto synthesis for tests
      auto_consistency: false  # Disable auto consistency for tests
    )
    
    # Return the store for use in tests
    %{store: store}
  end
  
  describe "basic storage and retrieval" do
    test "store and retrieve atoms", %{store: store} do
      # Create an atom
      atom = KnowledgeAtom.new("test atom", :test_source)
      
      # Add to store
      {:ok, id, _} = MultilevelKnowledgeStore.add_atom(store, atom)
      
      # Retrieve from store
      {:ok, retrieved} = MultilevelKnowledgeStore.get_atom(store, id)
      
      # Should be the same atom
      assert retrieved.id == atom.id
      assert retrieved.content == atom.content
      assert retrieved.source == atom.source
    end
    
    test "store and retrieve triples", %{store: store} do
      # Create a triple
      triple = KnowledgeTriple.new(:subject, :predicate, :object, :test_source)
      
      # Add to store
      {:ok, id, _} = MultilevelKnowledgeStore.add_triple(store, triple)
      
      # Retrieve from store
      {:ok, retrieved} = MultilevelKnowledgeStore.get_triple(store, id)
      
      # Should be the same triple
      assert retrieved.id == triple.id
      assert retrieved.subject == triple.subject
      assert retrieved.predicate == triple.predicate
      assert retrieved.object == triple.object
    end
    
    test "store and retrieve frames", %{store: store} do
      # Create a frame
      frame = KnowledgeFrame.new("test frame", %{
        name: "John",
        age: 30
      })
      
      # Add to store
      {:ok, id} = MultilevelKnowledgeStore.add_frame(store, frame)
      
      # Retrieve from store
      {:ok, retrieved} = MultilevelKnowledgeStore.get_frame(store, id)
      
      # Should be the same frame
      assert retrieved.id == frame.id
      assert retrieved.name == frame.name
      assert retrieved.slots.name.value == frame.slots.name.value
      assert retrieved.slots.age.value == frame.slots.age.value
    end
    
    test "store and retrieve graphs", %{store: store} do
      # Create a graph
      graph = KnowledgeGraph.new("test graph")
      
      # Add to store
      {:ok, id, _} = MultilevelKnowledgeStore.add_graph(store, graph)
      
      # Retrieve from store
      {:ok, retrieved} = MultilevelKnowledgeStore.get_graph(store, id)
      
      # Should be the same graph
      assert retrieved.id == graph.id
      assert retrieved.name == graph.name
    end
    
    test "store and retrieve concepts", %{store: store} do
      # Create a concept
      concept = HierarchicalConcept.new("test concept", "A test concept")
      
      # Add to store
      {:ok, id} = MultilevelKnowledgeStore.add_concept(store, concept)
      
      # Retrieve from store
      {:ok, retrieved} = MultilevelKnowledgeStore.get_concept(store, id)
      
      # Should be the same concept
      assert retrieved.id == concept.id
      assert retrieved.name == concept.name
      assert retrieved.description == concept.description
    end
  end
  
  describe "querying" do
    test "query atoms by criteria", %{store: store} do
      # Add some atoms
      atom1 = KnowledgeAtom.new("red apple", :source1, confidence: 0.8)
      atom2 = KnowledgeAtom.new("green apple", :source2, confidence: 0.7)
      atom3 = KnowledgeAtom.new("blue sky", :source1, confidence: 0.9)
      
      MultilevelKnowledgeStore.add_atom(store, atom1)
      MultilevelKnowledgeStore.add_atom(store, atom2)
      MultilevelKnowledgeStore.add_atom(store, atom3)
      
      # Query by content regex
      {:ok, results} = MultilevelKnowledgeStore.query_atoms(store, [
        content_regex: ~r/apple/
      ])
      
      # Should return atoms with "apple" in content
      assert length(results) == 2
      
      # Query by source
      {:ok, results} = MultilevelKnowledgeStore.query_atoms(store, [
        source: :source1
      ])
      
      # Should return atoms from source1
      assert length(results) == 2
      
      # Query by confidence minimum
      {:ok, results} = MultilevelKnowledgeStore.query_atoms(store, [
        confidence_min: 0.8
      ])
      
      # Should return atoms with confidence >= 0.8
      assert length(results) == 2
      assert Enum.all?(results, fn atom -> atom.confidence >= 0.8 end)
    end
    
    test "query triples by criteria", %{store: store} do
      # Add some triples
      triple1 = KnowledgeTriple.new(:john, :knows, :mary, :source1)
      triple2 = KnowledgeTriple.new(:john, :works_with, :bob, :source2)
      triple3 = KnowledgeTriple.new(:mary, :knows, :bob, :source1)
      
      MultilevelKnowledgeStore.add_triple(store, triple1)
      MultilevelKnowledgeStore.add_triple(store, triple2)
      MultilevelKnowledgeStore.add_triple(store, triple3)
      
      # Query by subject
      {:ok, results} = MultilevelKnowledgeStore.query_triples(store, [
        subject: :john
      ])
      
      # Should return triples with subject=john
      assert length(results) == 2
      
      # Query by predicate
      {:ok, results} = MultilevelKnowledgeStore.query_triples(store, [
        predicate: :knows
      ])
      
      # Should return triples with predicate=knows
      assert length(results) == 2
      
      # Query by object and source
      {:ok, results} = MultilevelKnowledgeStore.query_triples(store, [
        object: :bob,
        source: :source2
      ])
      
      # Should return triples with object=bob and source=source2
      assert length(results) == 1
      assert hd(results).subject == :john
      assert hd(results).predicate == :works_with
    end
    
    test "graph pattern match", %{store: store} do
      # Add some triples to form a pattern
      triple1 = KnowledgeTriple.new(:john, :knows, :mary, :source1)
      triple2 = KnowledgeTriple.new(:mary, :knows, :bob, :source1)
      triple3 = KnowledgeTriple.new(:bob, :works_with, :alice, :source2)
      
      MultilevelKnowledgeStore.add_triple(store, triple1)
      MultilevelKnowledgeStore.add_triple(store, triple2)
      MultilevelKnowledgeStore.add_triple(store, triple3)
      
      # Define a pattern: Find people that know someone who knows someone else
      pattern = %{
        triples: [
          %{subject: "?person1", predicate: :knows, object: "?person2"},
          %{subject: "?person2", predicate: :knows, object: "?person3"}
        ]
      }
      
      # Match pattern
      {:ok, matches} = MultilevelKnowledgeStore.graph_pattern_match(store, pattern)
      
      # Should match the pattern
      assert length(matches) == 1
      match = hd(matches)
      
      assert match["?person1"] == :john
      assert match["?person2"] == :mary
      assert match["?person3"] == :bob
    end
    
    test "traverse concept hierarchy", %{store: store} do
      # Create a hierarchy of concepts
      parent = HierarchicalConcept.new("Animal", "Animal kingdom")
      child1 = HierarchicalConcept.new("Mammal", "Warm-blooded vertebrates")
      child2 = HierarchicalConcept.new("Bird", "Feathered vertebrates")
      grandchild = HierarchicalConcept.new("Dog", "Canine mammal")
      
      # Add concepts to store
      {:ok, parent_id} = MultilevelKnowledgeStore.add_concept(store, parent)
      {:ok, child1_id} = MultilevelKnowledgeStore.add_concept(store, child1)
      {:ok, child2_id} = MultilevelKnowledgeStore.add_concept(store, child2)
      {:ok, grandchild_id} = MultilevelKnowledgeStore.add_concept(store, grandchild)
      
      # Retrieve concepts and establish parent-child relationships
      {:ok, parent_concept} = MultilevelKnowledgeStore.get_concept(store, parent_id)
      {:ok, child1_concept} = MultilevelKnowledgeStore.get_concept(store, child1_id)
      {:ok, child2_concept} = MultilevelKnowledgeStore.get_concept(store, child2_id)
      {:ok, grandchild_concept} = MultilevelKnowledgeStore.get_concept(store, grandchild_id)
      
      # Set up relationships
      {updated_parent, updated_child1} = HierarchicalConcept.add_child(parent_concept, child1_concept)
      {updated_parent, updated_child2} = HierarchicalConcept.add_child(updated_parent, child2_concept)
      {updated_child1, updated_grandchild} = HierarchicalConcept.add_child(updated_child1, grandchild_concept)
      
      # Update concepts in store
      MultilevelKnowledgeStore.add_concept(store, updated_parent)
      MultilevelKnowledgeStore.add_concept(store, updated_child1)
      MultilevelKnowledgeStore.add_concept(store, updated_child2)
      MultilevelKnowledgeStore.add_concept(store, updated_grandchild)
      
      # Traverse down from parent
      {:ok, hierarchy} = MultilevelKnowledgeStore.traverse_concept_hierarchy(store, parent_id, :down, 2)
      
      # Should have 2 children
      assert length(hierarchy.children) == 2
      
      # At least one child should have a child
      has_grandchild = Enum.any?(hierarchy.children, fn child ->
        length(child.children) > 0
      end)
      
      assert has_grandchild
      
      # Traverse up from grandchild
      {:ok, reverse_hierarchy} = MultilevelKnowledgeStore.traverse_concept_hierarchy(store, grandchild_id, :up, 2)
      
      # Should have a parent
      assert length(reverse_hierarchy.parents) == 1
      
      # Parent should have a parent
      assert length(hd(reverse_hierarchy.parents).parents) == 1
    end
  end
  
  describe "synthesis" do
    test "synthesize atoms", %{store: store} do
      # Add some related atoms
      atom1 = KnowledgeAtom.new("red apple", :source1, confidence: 0.8)
      atom2 = KnowledgeAtom.new("green apple", :source2, confidence: 0.7)
      atom3 = KnowledgeAtom.new("yellow apple", :source3, confidence: 0.9)
      
      MultilevelKnowledgeStore.add_atom(store, atom1)
      MultilevelKnowledgeStore.add_atom(store, atom2)
      MultilevelKnowledgeStore.add_atom(store, atom3)
      
      # Trigger synthesis
      {:ok, results} = MultilevelKnowledgeStore.synthesize(store, :atom)
      
      # Should cluster similar atoms
      atom_result = results[:atom]
      assert atom_result != nil
      
      # Depending on the implementation, we should have integrated atoms
      # Here we check that something happened
      assert elem(atom_result, 0) in [:integrated, :no_change]
    end
    
    test "synthesize triples into a graph", %{store: store} do
      # Add related triples that form a connected graph
      triple1 = KnowledgeTriple.new(:john, :knows, :mary, :source1)
      triple2 = KnowledgeTriple.new(:mary, :knows, :bob, :source1)
      triple3 = KnowledgeTriple.new(:bob, :works_with, :john, :source2)
      
      MultilevelKnowledgeStore.add_triple(store, triple1)
      MultilevelKnowledgeStore.add_triple(store, triple2)
      MultilevelKnowledgeStore.add_triple(store, triple3)
      
      # Trigger synthesis
      {:ok, results} = MultilevelKnowledgeStore.synthesize(store, :triple)
      
      # Should create a graph from triples
      triple_result = results[:triple]
      assert triple_result != nil
      
      # The result might be different depending on implementation details
      # Here we just check that something happened
      assert elem(triple_result, 0) in [:integrated, :synthesized_graph]
    end
  end
  
  describe "consistency verification" do
    test "verify atom consistency", %{store: store} do
      # Add consistent atoms
      atom1 = KnowledgeAtom.new(10, :source1, confidence: 0.8)
      atom2 = KnowledgeAtom.new(12, :source2, confidence: 0.9)
      
      MultilevelKnowledgeStore.add_atom(store, atom1)
      MultilevelKnowledgeStore.add_atom(store, atom2)
      
      # Verify consistency
      {:ok, results} = MultilevelKnowledgeStore.verify_consistency(store, :atom)
      
      # Should be consistent
      atom_result = results[:atom]
      assert atom_result != nil
      assert elem(atom_result, 0) == :ok
    end
    
    test "verify triple consistency", %{store: store} do
      # Add inconsistent triples
      triple1 = KnowledgeTriple.new(:john, :age, 30, :source1)
      triple2 = KnowledgeTriple.new(:john, :age, 40, :source2)
      
      MultilevelKnowledgeStore.add_triple(store, triple1)
      MultilevelKnowledgeStore.add_triple(store, triple2)
      
      # Verify consistency
      result = MultilevelKnowledgeStore.verify_consistency(store, :triple)
      
      # Should be inconsistent
      assert elem(result, 0) == :inconsistent
      
      # Should have triple inconsistencies
      inconsistencies = elem(result, 1)
      assert Map.has_key?(inconsistencies, :triple)
      
      triple_result = inconsistencies[:triple]
      assert elem(triple_result, 0) == :inconsistent
    end
    
    test "verify overall consistency", %{store: store} do
      # Add consistent atoms
      atom = KnowledgeAtom.new(10, :source1, confidence: 0.8)
      MultilevelKnowledgeStore.add_atom(store, atom)
      
      # Add inconsistent triples
      triple1 = KnowledgeTriple.new(:john, :age, 30, :source1)
      triple2 = KnowledgeTriple.new(:john, :age, 40, :source2)
      
      MultilevelKnowledgeStore.add_triple(store, triple1)
      MultilevelKnowledgeStore.add_triple(store, triple2)
      
      # Verify overall consistency
      result = MultilevelKnowledgeStore.verify_consistency(store, :all)
      
      # Should be inconsistent overall
      assert elem(result, 0) == :inconsistent
      
      # Should have atom consistency result (consistent)
      # and triple consistency result (inconsistent)
      inconsistencies = elem(result, 1)
      assert inconsistencies[:atom] != nil
      assert inconsistencies[:triple] != nil
      
      # Atoms should be consistent
      assert elem(inconsistencies[:atom], 0) == :ok
      
      # Triples should be inconsistent
      assert elem(inconsistencies[:triple], 0) == :inconsistent
    end
  end
end