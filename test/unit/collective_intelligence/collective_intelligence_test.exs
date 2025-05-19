defmodule Automata.CollectiveIntelligenceTest do
  use ExUnit.Case
  
  alias Automata.CollectiveIntelligence
  
  @moduletag :capture_log
  
  setup do
    # Start CI system with auto_synthesis and auto_consistency disabled for tests
    {:ok, ci_system} = CollectiveIntelligence.start_link(
      auto_synthesis: false,
      auto_consistency: false
    )
    
    # Return the CI system for use in tests
    %{ci_system: ci_system}
  end
  
  describe "knowledge creation and retrieval" do
    test "create and retrieve knowledge atom", %{ci_system: _} do
      # Create a knowledge atom
      {:ok, id, _} = CollectiveIntelligence.create_knowledge_atom("test content", :test_source)
      
      # Retrieve the atom
      {:ok, atom} = CollectiveIntelligence.get_knowledge(id, :atom)
      
      # Verify the atom
      assert atom.content == "test content"
      assert atom.source == :test_source
    end
    
    test "create and retrieve knowledge triple", %{ci_system: _} do
      # Create a knowledge triple
      {:ok, id, _} = CollectiveIntelligence.create_knowledge_triple(:subject, :predicate, :object, :test_source)
      
      # Retrieve the triple
      {:ok, triple} = CollectiveIntelligence.get_knowledge(id, :triple)
      
      # Verify the triple
      assert triple.subject == :subject
      assert triple.predicate == :predicate
      assert triple.object == :object
    end
    
    test "create and retrieve knowledge frame", %{ci_system: _} do
      # Create a knowledge frame
      {:ok, id} = CollectiveIntelligence.create_knowledge_frame("test frame", %{
        name: "John",
        age: 30
      })
      
      # Retrieve the frame
      {:ok, frame} = CollectiveIntelligence.get_knowledge(id, :frame)
      
      # Get slot values
      name = frame.slots.name.value
      age = frame.slots.age.value
      
      # Verify the frame
      assert frame.name == "test frame"
      assert name == "John"
      assert age == 30
    end
    
    test "create and retrieve knowledge graph", %{ci_system: _} do
      # Create a knowledge graph
      {:ok, id, _} = CollectiveIntelligence.create_knowledge_graph("test graph")
      
      # Retrieve the graph
      {:ok, graph} = CollectiveIntelligence.get_knowledge(id, :graph)
      
      # Verify the graph
      assert graph.name == "test graph"
      assert graph.entities == %{}  # Empty initially
    end
    
    test "create and retrieve hierarchical concept", %{ci_system: _} do
      # Create a hierarchical concept
      {:ok, id} = CollectiveIntelligence.create_hierarchical_concept("test concept", "A test concept")
      
      # Retrieve the concept
      {:ok, concept} = CollectiveIntelligence.get_knowledge(id, :concept)
      
      # Verify the concept
      assert concept.name == "test concept"
      assert concept.description == "A test concept"
    end
  end
  
  describe "knowledge querying" do
    test "query knowledge atoms", %{ci_system: _} do
      # Create some atoms
      CollectiveIntelligence.create_knowledge_atom("red apple", :source1)
      CollectiveIntelligence.create_knowledge_atom("green apple", :source2)
      CollectiveIntelligence.create_knowledge_atom("blue sky", :source1)
      
      # Query atoms containing "apple"
      {:ok, results} = CollectiveIntelligence.query_knowledge_atoms([
        content_regex: ~r/apple/
      ])
      
      # Should find 2 atoms
      assert length(results) == 2
      assert Enum.all?(results, fn atom -> String.contains?(atom.content, "apple") end)
    end
    
    test "query knowledge triples", %{ci_system: _} do
      # Create some triples
      CollectiveIntelligence.create_knowledge_triple(:john, :knows, :mary, :source1)
      CollectiveIntelligence.create_knowledge_triple(:john, :age, 30, :source2)
      CollectiveIntelligence.create_knowledge_triple(:mary, :knows, :bob, :source1)
      
      # Query triples with subject=john
      {:ok, results} = CollectiveIntelligence.query_knowledge_triples([
        subject: :john
      ])
      
      # Should find 2 triples
      assert length(results) == 2
      assert Enum.all?(results, fn triple -> triple.subject == :john end)
    end
  end
  
  describe "knowledge graph operations" do
    test "build and query knowledge graph", %{ci_system: _} do
      # Create a graph
      {:ok, graph_id, _} = CollectiveIntelligence.create_knowledge_graph("social graph")
      
      # Add entities
      {:ok, _, _} = CollectiveIntelligence.add_entity_to_graph(graph_id, :person, %{name: "John"})
      {:ok, _, _} = CollectiveIntelligence.add_entity_to_graph(graph_id, :person, %{name: "Mary"})
      
      # Get the graph to find entity IDs
      {:ok, graph} = CollectiveIntelligence.get_knowledge(graph_id, :graph)
      entity_ids = Map.keys(graph.entities)
      
      # Entity IDs should exist
      assert length(entity_ids) == 2
      
      # Find John and Mary's IDs
      john_id = Enum.find(entity_ids, fn id -> 
        graph.entities[id].properties.name == "John"
      end)
      
      mary_id = Enum.find(entity_ids, fn id -> 
        graph.entities[id].properties.name == "Mary"
      end)
      
      # Add relationship
      {:ok, updated_graph, _} = CollectiveIntelligence.add_relationship_to_graph(
        graph_id, :knows, john_id, mary_id, %{since: 2020}
      )
      
      # Relationship should be added
      assert map_size(updated_graph.relationships) == 1
    end
  end
  
  describe "knowledge synthesis and consistency" do
    test "synthesize knowledge", %{ci_system: _} do
      # Create some related triples
      CollectiveIntelligence.create_knowledge_triple(:john, :knows, :mary, :source1)
      CollectiveIntelligence.create_knowledge_triple(:mary, :knows, :bob, :source1)
      CollectiveIntelligence.create_knowledge_triple(:bob, :knows, :alice, :source1)
      
      # Synthesize knowledge
      {:ok, synthesis_results} = CollectiveIntelligence.synthesize_knowledge(:triple)
      
      # Should have results for triple synthesis
      assert Map.has_key?(synthesis_results, :triple)
    end
    
    test "verify knowledge consistency", %{ci_system: _} do
      # Create consistent triples
      CollectiveIntelligence.create_knowledge_triple(:john, :age, 30, :source1)
      CollectiveIntelligence.create_knowledge_triple(:john, :height, 180, :source1)
      
      # Verify consistency
      consistency_result = CollectiveIntelligence.verify_knowledge_consistency(:triple)
      
      # Should be consistent
      assert elem(consistency_result, 0) == :ok
      
      # Add inconsistent triple
      CollectiveIntelligence.create_knowledge_triple(:john, :age, 40, :source2)  # Conflicts with first triple
      
      # Verify consistency again
      consistency_result = CollectiveIntelligence.verify_knowledge_consistency(:triple)
      
      # Should be inconsistent
      assert elem(consistency_result, 0) == :inconsistent
    end
    
    test "identify contradictions", %{ci_system: _} do
      # Create contradictory knowledge
      CollectiveIntelligence.create_knowledge_triple(:earth, :is_flat, true, :source1)
      CollectiveIntelligence.create_knowledge_triple(:earth, :is_flat, false, :source2)
      
      # Identify contradictions
      {:ok, contradictions} = CollectiveIntelligence.identify_knowledge_contradictions()
      
      # Should find contradictions
      assert Map.has_key?(contradictions, :triples)
      assert length(contradictions.triples) > 0
    end
  end
  
  describe "concept hierarchy operations" do
    test "build and explore concept hierarchy", %{ci_system: _} do
      # Create concepts
      {:ok, animal_id} = CollectiveIntelligence.create_hierarchical_concept("Animal", "Animal kingdom")
      {:ok, mammal_id} = CollectiveIntelligence.create_hierarchical_concept("Mammal", "Warm-blooded vertebrates")
      {:ok, dog_id} = CollectiveIntelligence.create_hierarchical_concept("Dog", "Canine mammal")
      
      # Get concepts
      {:ok, animal} = CollectiveIntelligence.get_knowledge(animal_id, :concept)
      {:ok, mammal} = CollectiveIntelligence.get_knowledge(mammal_id, :concept)
      {:ok, dog} = CollectiveIntelligence.get_knowledge(dog_id, :concept)
      
      # Set parent-child relationships
      CollectiveIntelligence.create_hierarchical_concept(
        "Animal",
        "Animal kingdom",
        id: animal_id,
        children_ids: [mammal_id]
      )
      
      CollectiveIntelligence.create_hierarchical_concept(
        "Mammal",
        "Warm-blooded vertebrates",
        id: mammal_id,
        parent_id: animal_id,
        children_ids: [dog_id]
      )
      
      CollectiveIntelligence.create_hierarchical_concept(
        "Dog",
        "Canine mammal",
        id: dog_id,
        parent_id: mammal_id
      )
      
      # Explore hierarchy from Animal down
      {:ok, hierarchy} = CollectiveIntelligence.explore_concept_hierarchy(animal_id, :down, 2)
      
      # Should have children
      assert hierarchy.concept.id == animal_id
      assert length(hierarchy.children) > 0
      
      # First child should be Mammal
      mammal_child = hd(hierarchy.children)
      assert mammal_child.concept.name == "Mammal"
      
      # Mammal should have Dog as child
      assert length(mammal_child.children) > 0
      dog_child = hd(mammal_child.children)
      assert dog_child.concept.name == "Dog"
    end
  end
  
  describe "placeholders for future functionality" do
    test "decision process placeholders return :not_implemented", %{ci_system: _} do
      assert {:error, :not_implemented} = CollectiveIntelligence.start_decision_process(:consensus, [:agent1, :agent2])
      assert {:error, :not_implemented} = CollectiveIntelligence.submit_decision_input("process1", :agent1, "input")
      assert {:error, :not_implemented} = CollectiveIntelligence.get_decision_status("process1")
    end
    
    test "problem solving placeholders return :not_implemented", %{ci_system: _} do
      assert {:error, :not_implemented} = CollectiveIntelligence.define_problem(:optimization, %{objective: "minimize cost"})
      assert {:error, :not_implemented} = CollectiveIntelligence.submit_partial_solution("problem1", :agent1, %{solution_part: "part1"})
      assert {:error, :not_implemented} = CollectiveIntelligence.get_problem_state("problem1")
    end
  end
end