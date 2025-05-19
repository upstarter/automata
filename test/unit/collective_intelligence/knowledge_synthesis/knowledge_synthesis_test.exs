defmodule Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSynthesisTest do
  use ExUnit.Case, async: true
  
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeRepresentation
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSynthesis
  
  alias KnowledgeRepresentation.KnowledgeAtom
  alias KnowledgeRepresentation.KnowledgeTriple
  alias KnowledgeRepresentation.KnowledgeFrame
  alias KnowledgeRepresentation.KnowledgeGraph
  alias KnowledgeRepresentation.HierarchicalConcept
  
  alias KnowledgeSynthesis.ConflictResolution
  alias KnowledgeSynthesis.AbstractionSynthesis
  alias KnowledgeSynthesis.IntegrationSynthesis
  alias KnowledgeSynthesis.ConsistencyVerification
  
  describe "ConflictResolution" do
    test "resolves atom conflicts with weighted_confidence strategy" do
      # Create conflicting atoms
      atom1 = KnowledgeAtom.new(10, :source1, confidence: 0.8)
      atom2 = KnowledgeAtom.new(20, :source2, confidence: 0.2)
      
      # Resolve conflict
      {:ok, resolved} = ConflictResolution.resolve_atom_conflict([atom1, atom2])
      
      # Should be weighted average: (10 * 0.8 + 20 * 0.2) / (0.8 + 0.2) = (8 + 4) / 1 = 12
      assert resolved.content == 12
      
      # Confidence should be the max of input confidences
      assert resolved.confidence == 0.8
      
      # Source should include both original sources
      assert resolved.source == [:source1, :source2]
      
      # Resolution strategy should be recorded in metadata
      assert resolved.metadata.resolution_strategy == :weighted_confidence
    end
    
    test "resolves atom conflicts with highest_confidence strategy" do
      # Create conflicting atoms
      atom1 = KnowledgeAtom.new("Value 1", :source1, confidence: 0.8)
      atom2 = KnowledgeAtom.new("Value 2", :source2, confidence: 0.9)
      
      # Resolve conflict
      {:ok, resolved} = ConflictResolution.resolve_atom_conflict([atom1, atom2], :highest_confidence)
      
      # Should take the atom with highest confidence
      assert resolved.content == "Value 2"
      assert resolved.confidence == 0.9
      assert resolved.source == :source2
      
      # Resolution strategy should be recorded in metadata
      assert resolved.metadata.resolution_strategy == :highest_confidence
    end
    
    test "resolves atom conflicts with newest strategy" do
      # Create atoms with different timestamps
      atom1 = %KnowledgeAtom{
        id: "atom1",
        content: "Old value",
        confidence: 0.9,
        source: :source1,
        timestamp: DateTime.add(DateTime.utc_now(), -3600, :second),  # 1 hour ago
        metadata: %{},
        context: %{}
      }
      
      atom2 = %KnowledgeAtom{
        id: "atom2",
        content: "New value",
        confidence: 0.7,
        source: :source2,
        timestamp: DateTime.utc_now(),  # Now
        metadata: %{},
        context: %{}
      }
      
      # Resolve conflict
      {:ok, resolved} = ConflictResolution.resolve_atom_conflict([atom1, atom2], :newest)
      
      # Should take the newest atom
      assert resolved.content == "New value"
      assert resolved.confidence == 0.7
      assert resolved.source == :source2
      
      # Resolution strategy should be recorded in metadata
      assert resolved.metadata.resolution_strategy == :newest
    end
    
    test "resolves atom conflicts with voting strategy" do
      # Create atoms with same content
      atom1 = KnowledgeAtom.new("Value A", :source1, confidence: 0.7)
      atom2 = KnowledgeAtom.new("Value A", :source2, confidence: 0.6)
      atom3 = KnowledgeAtom.new("Value B", :source3, confidence: 0.9)
      
      # Resolve conflict
      {:ok, resolved} = ConflictResolution.resolve_atom_conflict([atom1, atom2, atom3], :voting)
      
      # Should take the content with most votes (Value A)
      assert resolved.content == "Value A"
      
      # From the winning content atoms, should take highest confidence
      assert resolved.confidence == 0.7
      assert resolved.source == :source1
      
      # Resolution strategy should be recorded in metadata
      assert resolved.metadata.resolution_strategy == :voting
    end
    
    test "resolves triple conflicts with weighted_confidence strategy" do
      # Create conflicting triples (same subject/predicate, different objects)
      triple1 = KnowledgeTriple.new(:person, :age, 30, :source1, confidence: 0.8)
      triple2 = KnowledgeTriple.new(:person, :age, 35, :source2, confidence: 0.2)
      
      # Resolve conflict
      {:ok, resolved_triples} = ConflictResolution.resolve_triple_conflict([triple1, triple2])
      
      # Should have one resolved triple
      assert length(resolved_triples) == 1
      resolved = hd(resolved_triples)
      
      # Should have weighted average object
      assert resolved.subject == :person
      assert resolved.predicate == :age
      assert resolved.object == 31  # (30 * 0.8 + 35 * 0.2) / 1 = 31
      
      # Source should include both original sources
      assert resolved.source == [:source1, :source2]
    end
    
    test "resolves triple conflicts with highest_confidence strategy" do
      # Create conflicting triples (different predicates)
      triple1 = KnowledgeTriple.new(:person, :name, "John", :source1, confidence: 0.8)
      triple2 = KnowledgeTriple.new(:person, :full_name, "John Smith", :source2, confidence: 0.9)
      
      # Resolve conflict
      {:ok, resolved_triples} = ConflictResolution.resolve_triple_conflict([triple1, triple2], :highest_confidence)
      
      # Should have two triples (one for each predicate)
      assert length(resolved_triples) == 2
      
      # Triples should be preserved
      assert Enum.at(resolved_triples, 0).subject == :person
      assert Enum.at(resolved_triples, 1).subject == :person
      
      # Predicates should be different
      predicates = Enum.map(resolved_triples, & &1.predicate) |> Enum.sort()
      assert predicates == [:full_name, :name] |> Enum.sort()
    end
    
    test "resolves frame conflicts with slot_by_slot strategy" do
      # Create frames with overlapping slots
      frame1 = KnowledgeFrame.new("Person", %{
        name: "John Smith",
        age: 30,
        occupation: "Engineer"
      }, confidence: 0.8)
      
      frame2 = KnowledgeFrame.new("Person", %{
        name: "J. Smith",
        age: 32,
        height: 180
      }, confidence: 0.7)
      
      # Resolve conflict
      {:ok, resolved} = ConflictResolution.resolve_frame_conflict([frame1, frame2])
      
      # Should merge all slots, taking highest confidence for each
      assert KnowledgeFrame.get_slot(resolved, :name) == "John Smith"  # frame1 has higher confidence
      assert KnowledgeFrame.get_slot(resolved, :age) == 30  # frame1 has higher confidence
      assert KnowledgeFrame.get_slot(resolved, :occupation) == "Engineer"  # Only in frame1
      assert KnowledgeFrame.get_slot(resolved, :height) == 180  # Only in frame2
      
      # Source should include both sources
      assert resolved.source == [:source1, :source2]
      
      # Resolution strategy should be recorded in metadata
      assert resolved.metadata.resolution_strategy == :slot_by_slot
    end
  end
  
  describe "AbstractionSynthesis" do
    test "creates abstract concept from instances" do
      # Create concept instances
      dog = HierarchicalConcept.new("Dog", "Canine animal")
      |> HierarchicalConcept.add_attribute(:legs, 4, 1.0)
      |> HierarchicalConcept.add_attribute(:fur, true, 1.0)
      |> HierarchicalConcept.add_attribute(:sound, "bark", 1.0)
      
      cat = HierarchicalConcept.new("Cat", "Feline animal")
      |> HierarchicalConcept.add_attribute(:legs, 4, 1.0)
      |> HierarchicalConcept.add_attribute(:fur, true, 1.0)
      |> HierarchicalConcept.add_attribute(:sound, "meow", 1.0)
      
      # Create abstraction
      {:ok, mammal, [updated_dog, updated_cat]} = 
        AbstractionSynthesis.abstract_concept_from_instances(
          [dog, cat], 
          "Mammal", 
          "Warm-blooded vertebrate animals"
        )
      
      # Abstract concept should have common attributes
      assert mammal.attributes.legs.value == 4
      assert mammal.attributes.fur.value == true
      assert_not_in_keys mammal.attributes, :sound  # Not common
      
      # Updated instances should have parent-child relationship
      assert updated_dog.parent_id == mammal.id
      assert updated_cat.parent_id == mammal.id
      
      # Abstract concept should have children
      assert length(mammal.children_ids) == 2
      assert Enum.member?(mammal.children_ids, updated_dog.id)
      assert Enum.member?(mammal.children_ids, updated_cat.id)
    end
    
    test "creates frame template from instances" do
      # Create frame instances
      person1 = KnowledgeFrame.new("Person1", %{
        name: "John",
        age: 30,
        occupation: "Engineer",
        hobbies: ["reading", "hiking"]
      })
      
      person2 = KnowledgeFrame.new("Person2", %{
        name: "Jane",
        age: 28,
        occupation: "Doctor",
        address: "123 Main St"
      })
      
      # Create template
      {:ok, template} = AbstractionSynthesis.frame_template_from_instances(
        [person1, person2], 
        "PersonTemplate"
      )
      
      # Template should have common slots
      assert_in_keys template.slots, :name
      assert_in_keys template.slots, :age
      assert_in_keys template.slots, :occupation
      
      # Template should not have non-common slots
      assert_not_in_keys template.slots, :hobbies
      assert_not_in_keys template.slots, :address
    end
  end
  
  describe "IntegrationSynthesis" do
    test "integrates atoms with cluster_and_resolve strategy" do
      # Create atoms with similar content
      atom1 = KnowledgeAtom.new("red apple", :source1, confidence: 0.8)
      atom2 = KnowledgeAtom.new("red fruit", :source2, confidence: 0.7)
      atom3 = KnowledgeAtom.new("blue sky", :source3, confidence: 0.9)
      
      # Integrate atoms
      {:ok, integrated} = IntegrationSynthesis.integrate_atoms([atom1, atom2, atom3])
      
      # Should cluster similar atoms
      assert length(integrated) == 2
      
      # Find clusters
      red_cluster = Enum.find(integrated, fn atom -> 
        String.contains?(atom.content, "red") 
      end)
      
      blue_cluster = Enum.find(integrated, fn atom -> 
        String.contains?(atom.content, "blue") 
      end)
      
      # Check clusters
      assert red_cluster != nil
      assert blue_cluster != nil
      assert blue_cluster.content == "blue sky"
    end
    
    test "integrates triples with graph_merge strategy" do
      # Create related triples
      triple1 = KnowledgeTriple.new(:john, :friend_of, :mary, :source1)
      triple2 = KnowledgeTriple.new(:mary, :colleague_of, :bob, :source2)
      triple3 = KnowledgeTriple.new(:bob, :reports_to, :alice, :source3)
      
      # Integrate triples
      {:ok, result} = IntegrationSynthesis.integrate_triples([triple1, triple2, triple3])
      
      # Should create a graph
      assert result.__struct__ == KnowledgeGraph
      
      # Graph should have 4 entities and 3 relationships
      assert map_size(result.entities) == 4  # john, mary, bob, alice
      assert map_size(result.relationships) == 3
    end
    
    test "integrates frames with slot_merge strategy" do
      # Create frames with complementary slots
      frame1 = KnowledgeFrame.new("Person", %{
        name: "John Smith",
        age: 30
      })
      
      frame2 = KnowledgeFrame.new("Person", %{
        name: "John S.", 
        height: 180,
        weight: 75
      })
      
      # Integrate frames
      {:ok, integrated} = IntegrationSynthesis.integrate_frames([frame1, frame2], :slot_merge)
      
      # Should have all slots from both frames
      assert KnowledgeFrame.get_slot(integrated, :name) == "John Smith"  # frame1 wins on conflicting slot
      assert KnowledgeFrame.get_slot(integrated, :age) == 30
      assert KnowledgeFrame.get_slot(integrated, :height) == 180
      assert KnowledgeFrame.get_slot(integrated, :weight) == 75
    end
    
    test "integrates graphs with union_merge strategy" do
      # Create first graph
      graph1 = KnowledgeGraph.new("Graph1")
      graph1 = KnowledgeGraph.add_entity(graph1, :person, %{name: "John"})
      graph1 = KnowledgeGraph.add_entity(graph1, :person, %{name: "Mary"})
      
      # Get entity IDs
      [john_id, mary_id] = Map.keys(graph1.entities)
      
      # Add relationship
      graph1 = KnowledgeGraph.add_relationship(graph1, :knows, john_id, mary_id)
      
      # Create second graph
      graph2 = KnowledgeGraph.new("Graph2")
      graph2 = KnowledgeGraph.add_entity(graph2, :person, %{name: "Bob"})
      graph2 = KnowledgeGraph.add_entity(graph2, :person, %{name: "Alice"})
      
      # Get entity IDs
      [bob_id, alice_id] = Map.keys(graph2.entities)
      
      # Add relationship
      graph2 = KnowledgeGraph.add_relationship(graph2, :knows, bob_id, alice_id)
      
      # Integrate graphs
      {:ok, merged} = IntegrationSynthesis.integrate_graphs([graph1, graph2])
      
      # Should have all entities and relationships
      assert map_size(merged.entities) == 4  # John, Mary, Bob, Alice
      assert map_size(merged.relationships) == 2  # Two 'knows' relationships
    end
  end
  
  describe "ConsistencyVerification" do
    test "verifies atom consistency - consistent" do
      # Create consistent atoms
      atom1 = KnowledgeAtom.new(10, :source1, confidence: 0.8)
      atom2 = KnowledgeAtom.new(12, :source2, confidence: 0.9)
      
      # Verify consistency
      result = ConsistencyVerification.verify_atom_consistency([atom1, atom2])
      
      # Should be consistent (variance is acceptable)
      assert elem(result, 0) == :ok
    end
    
    test "verifies atom consistency - inconsistent" do
      # Create inconsistent atoms
      atom1 = KnowledgeAtom.new(10, :source1, confidence: 0.8)
      atom2 = KnowledgeAtom.new(100, :source2, confidence: 0.9)  # Large difference
      
      # Verify consistency
      result = ConsistencyVerification.verify_atom_consistency([atom1, atom2])
      
      # Should be inconsistent (high variance)
      assert elem(result, 0) == :inconsistent
    end
    
    test "verifies triple consistency - consistent" do
      # Create consistent triples (different predicates)
      triple1 = KnowledgeTriple.new(:john, :age, 30, :source1)
      triple2 = KnowledgeTriple.new(:john, :height, 180, :source2)
      
      # Verify consistency
      result = ConsistencyVerification.verify_triple_consistency([triple1, triple2])
      
      # Should be consistent
      assert elem(result, 0) == :ok
    end
    
    test "verifies triple consistency - inconsistent" do
      # Create inconsistent triples (same subject/predicate, different objects)
      triple1 = KnowledgeTriple.new(:john, :age, 30, :source1)
      triple2 = KnowledgeTriple.new(:john, :age, 35, :source2)
      
      # Verify consistency
      result = ConsistencyVerification.verify_triple_consistency([triple1, triple2])
      
      # Should be inconsistent
      assert elem(result, 0) == :inconsistent
      
      # Should identify the contradiction
      {_, contradictions} = result
      assert length(contradictions) == 1
      assert length(hd(contradictions)) == 2
    end
    
    test "verifies graph consistency - consistent" do
      # Create a consistent graph
      graph = KnowledgeGraph.new("Test Graph")
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "John"})
      graph = KnowledgeGraph.add_entity(graph, :person, %{name: "Mary"})
      
      # Get entity IDs
      [john_id, mary_id] = Map.keys(graph.entities)
      
      # Add relationship
      graph = KnowledgeGraph.add_relationship(graph, :knows, john_id, mary_id)
      
      # Verify consistency
      result = ConsistencyVerification.verify_graph_consistency(graph)
      
      # Should be consistent
      assert elem(result, 0) == :ok
    end
  end
  
  # Helper assertions
  
  defp assert_in_keys(map, key) do
    assert Map.has_key?(map, key), "Expected #{inspect(map)} to have key #{key}"
  end
  
  defp assert_not_in_keys(map, key) do
    refute Map.has_key?(map, key), "Expected #{inspect(map)} not to have key #{key}"
  end
end