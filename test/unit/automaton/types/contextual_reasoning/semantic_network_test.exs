defmodule Automata.Reasoning.Cognitive.ContextualReasoning.SemanticNetworkTest do
  use ExUnit.Case, async: false
  
  alias Automata.Reasoning.Cognitive.ContextualReasoning.KnowledgeRepresentation.SemanticNetwork
  alias Automata.Reasoning.Cognitive.ContextualReasoning.KnowledgeRepresentation.SemanticNetwork.Node
  alias Automata.Reasoning.Cognitive.ContextualReasoning.KnowledgeRepresentation.SemanticNetwork.Edge
  alias Automata.Reasoning.Cognitive.ContextualReasoning.ContextManagement.ContextManager
  
  describe "SemanticNetwork" do
    setup do
      # Mock perceptory for testing
      mock_perceptory = %{get_active_perceptions: fn -> [] end}
      
      # Start context manager
      {:ok, manager} = ContextManager.start_link(mock_perceptory)
      
      # Create contexts for testing
      :ok = ContextManager.create_context(
        manager,
        :animals,
        "Animals Context",
        "Context for animal knowledge",
        []
      )
      
      :ok = ContextManager.create_context(
        manager,
        :vehicles,
        "Vehicles Context",
        "Context for vehicle knowledge",
        []
      )
      
      # Activate both contexts
      :ok = ContextManager.activate_context(manager, :animals, 1.0)
      :ok = ContextManager.activate_context(manager, :vehicles, 1.0)
      
      # Create semantic network
      network = SemanticNetwork.new(manager)
      
      # Add some nodes and relationships
      
      # Animal taxonomy - general nodes
      network = SemanticNetwork.add_node(network, :animal, :concept, "Animal", %{living: true})
      network = SemanticNetwork.add_node(network, :mammal, :concept, "Mammal", %{warm_blooded: true})
      network = SemanticNetwork.add_node(network, :bird, :concept, "Bird", %{has_feathers: true})
      
      # Connect general taxonomy
      network = SemanticNetwork.add_edge(network, :mammal, :animal, :is_a, 1.0, %{}, [:animals])
      network = SemanticNetwork.add_edge(network, :bird, :animal, :is_a, 1.0, %{}, [:animals])
      
      # Specific animals
      network = SemanticNetwork.add_node(network, :dog, :concept, "Dog", %{domestic: true}, [:animals])
      network = SemanticNetwork.add_node(network, :cat, :concept, "Cat", %{domestic: true}, [:animals])
      network = SemanticNetwork.add_node(network, :eagle, :concept, "Eagle", %{predator: true}, [:animals])
      
      # Connect specific animals
      network = SemanticNetwork.add_edge(network, :dog, :mammal, :is_a, 1.0, %{}, [:animals])
      network = SemanticNetwork.add_edge(network, :cat, :mammal, :is_a, 1.0, %{}, [:animals])
      network = SemanticNetwork.add_edge(network, :eagle, :bird, :is_a, 1.0, %{}, [:animals])
      
      # Vehicle taxonomy - in different context
      network = SemanticNetwork.add_node(network, :vehicle, :concept, "Vehicle", %{man_made: true})
      network = SemanticNetwork.add_node(network, :car, :concept, "Car", %{wheels: 4}, [:vehicles])
      network = SemanticNetwork.add_node(network, :bicycle, :concept, "Bicycle", %{wheels: 2}, [:vehicles])
      
      # Connect vehicles
      network = SemanticNetwork.add_edge(network, :car, :vehicle, :is_a, 1.0, %{}, [:vehicles])
      network = SemanticNetwork.add_edge(network, :bicycle, :vehicle, :is_a, 1.0, %{}, [:vehicles])
      
      # Add some cross-context relationships
      network = SemanticNetwork.add_edge(network, :dog, :car, :can_ride_in, 0.8, %{as: :passenger}, [:animals, :vehicles])
      
      {:ok, network: network, manager: manager}
    end
    
    test "add_node/6 adds nodes to the network", %{network: network} do
      # Add a new node
      updated = SemanticNetwork.add_node(
        network, 
        :wolf, 
        :concept, 
        "Wolf", 
        %{domestic: false, predator: true}, 
        [:animals]
      )
      
      # Verify node was added
      wolf = SemanticNetwork.get_node(updated, :wolf)
      
      assert wolf != nil
      assert wolf.type == :concept
      assert wolf.label == "Wolf"
      assert wolf.properties.domestic == false
      assert wolf.properties.predator == true
      assert wolf.context_ids == [:animals]
      
      # Update existing node
      modified = SemanticNetwork.add_node(
        updated,
        :wolf,
        :concept,
        "Gray Wolf",
        %{endangered: true},
        [:animals, :conservation]
      )
      
      # Verify node was updated
      wolf_updated = SemanticNetwork.get_node(modified, :wolf)
      
      assert wolf_updated.label == "Gray Wolf"
      assert wolf_updated.properties.domestic == false  # Original property preserved
      assert wolf_updated.properties.endangered == true  # New property added
      assert :animals in wolf_updated.context_ids
      assert :conservation in wolf_updated.context_ids
    end
    
    test "add_edge/8 adds edges to the network", %{network: network} do
      # Add a new edge
      updated = SemanticNetwork.add_edge(
        network,
        :dog,
        :cat,
        :chases,
        0.7,
        %{playfully: true},
        [:animals],
        false
      )
      
      # Verify edge was added
      edge = SemanticNetwork.get_edge(updated, :dog, :cat, :chases)
      
      assert edge != nil
      assert edge.source_id == :dog
      assert edge.target_id == :cat
      assert edge.relation == :chases
      assert edge.weight == 0.7
      assert edge.properties.playfully == true
      assert edge.context_ids == [:animals]
      assert edge.bidirectional == false
      
      # Test bidirectional edge
      bidir = SemanticNetwork.add_edge(
        updated,
        :dog,
        :cat,
        :lives_with,
        0.9,
        %{harmoniously: false},
        [:animals],
        true
      )
      
      # Verify bidirectional edge
      edge1 = SemanticNetwork.get_edge(bidir, :dog, :cat, :lives_with)
      assert edge1 != nil
      assert edge1.bidirectional == true
      
      # Edges should be accessible from both directions
      dog_edges = SemanticNetwork.get_connected_edges(bidir, :dog)
      cat_edges = SemanticNetwork.get_connected_edges(bidir, :cat)
      
      assert Enum.any?(dog_edges, fn e -> e.relation == :lives_with && e.target_id == :cat end)
      assert Enum.any?(cat_edges, fn e -> e.relation == :lives_with && e.source_id == :dog end)
    end
    
    test "get_node/2 retrieves nodes", %{network: network} do
      # Get existing node
      dog = SemanticNetwork.get_node(network, :dog)
      
      assert dog != nil
      assert dog.label == "Dog"
      assert dog.properties.domestic == true
      
      # Non-existent node
      assert SemanticNetwork.get_node(network, :unicorn) == nil
    end
    
    test "get_edge/4 retrieves edges", %{network: network} do
      # Get existing edge
      is_a = SemanticNetwork.get_edge(network, :dog, :mammal, :is_a)
      
      assert is_a != nil
      assert is_a.source_id == :dog
      assert is_a.target_id == :mammal
      assert is_a.relation == :is_a
      
      # Non-existent edge
      assert SemanticNetwork.get_edge(network, :dog, :bird, :is_a) == nil
    end
    
    test "get_connected_edges/3 retrieves edges by direction", %{network: network} do
      # Get all edges connected to dog
      all_dog_edges = SemanticNetwork.get_connected_edges(network, :dog)
      assert length(all_dog_edges) == 3  # is_a, can_ride_in
      
      # Get only outgoing edges
      outgoing = SemanticNetwork.get_connected_edges(network, :dog, :outgoing)
      assert length(outgoing) == 2  # is_a, can_ride_in
      assert Enum.all?(outgoing, fn e -> e.source_id == :dog end)
      
      # Get only incoming edges (none for dog)
      incoming = SemanticNetwork.get_connected_edges(network, :dog, :incoming)
      assert length(incoming) == 1  # Referenced by other nodes
      assert Enum.all?(incoming, fn e -> e.target_id == :dog end)
    end
    
    test "get_connected_nodes/4 retrieves connected nodes", %{network: network} do
      # Get all nodes connected to mammal by is_a relation
      subtypes = SemanticNetwork.get_connected_nodes(network, :mammal, :is_a, :incoming)
      
      assert length(subtypes) == 2
      subtype_ids = Enum.map(subtypes, & &1.id)
      assert :dog in subtype_ids
      assert :cat in subtype_ids
      
      # Get parent node of dog
      supertypes = SemanticNetwork.get_connected_nodes(network, :dog, :is_a, :outgoing)
      
      assert length(supertypes) == 1
      assert hd(supertypes).id == :mammal
      
      # Get all nodes connected to dog by any relation
      all_connected = SemanticNetwork.get_connected_nodes(network, :dog)
      
      assert length(all_connected) == 2  # mammal and car
      connected_ids = Enum.map(all_connected, & &1.id)
      assert :mammal in connected_ids
      assert :car in connected_ids
    end
    
    test "spread_activation/5 activates connected nodes", %{network: network} do
      # Initially no activations
      assert Enum.empty?(network.activation_levels)
      
      # Activate dog node
      activated = SemanticNetwork.spread_activation(network, :dog, 1.0, 0.5, 2)
      
      # Dog should be fully activated
      assert Map.get(activated.activation_levels, :dog) == 1.0
      
      # Connected nodes should be partially activated
      assert Map.get(activated.activation_levels, :mammal) > 0.0
      assert Map.get(activated.activation_levels, :car) > 0.0
      
      # Distant nodes should have less activation
      assert Map.get(activated.activation_levels, :animal) > 0.0
      assert Map.get(activated.activation_levels, :animal) < Map.get(activated.activation_levels, :mammal)
      
      # Unconnected nodes should have no activation
      assert Map.get(activated.activation_levels, :bicycle, 0.0) == 0.0
    end
    
    test "get_active_nodes/1 retrieves nodes above threshold", %{network: network} do
      # Activate some nodes
      activated = network
      |> SemanticNetwork.spread_activation(:dog, 1.0, 0.5, 2)
      |> SemanticNetwork.spread_activation(:cat, 0.8, 0.5, 1)
      
      # Get active nodes
      active_nodes = SemanticNetwork.get_active_nodes(activated)
      
      # Nodes with high activation should be included
      active_ids = Enum.map(active_nodes, & &1.id)
      assert :dog in active_ids
      assert :cat in active_ids
      
      # Lower activation nodes also included if above threshold
      if Map.get(activated.activation_levels, :mammal, 0.0) >= activated.activation_threshold do
        assert :mammal in active_ids
      end
      
      # Inactive nodes should be excluded
      assert :bicycle not in active_ids
    end
    
    test "filter_by_active_contexts/1 filters by context", %{network: network, manager: manager} do
      # Initially both contexts active
      filtered1 = SemanticNetwork.filter_by_active_contexts(network)
      
      # All nodes should be present
      assert SemanticNetwork.get_node(filtered1, :dog) != nil
      assert SemanticNetwork.get_node(filtered1, :car) != nil
      
      # Deactivate vehicles context
      ContextManager.deactivate_context(manager, :vehicles, 1.0)
      
      # Filter again
      filtered2 = SemanticNetwork.filter_by_active_contexts(network)
      
      # Animal nodes should remain
      assert SemanticNetwork.get_node(filtered2, :dog) != nil
      assert SemanticNetwork.get_node(filtered2, :cat) != nil
      
      # Vehicle nodes with context should be filtered out
      assert SemanticNetwork.get_node(filtered2, :car) == nil
      assert SemanticNetwork.get_node(filtered2, :bicycle) == nil
      
      # Global nodes (no specific context) should remain
      assert SemanticNetwork.get_node(filtered2, :vehicle) != nil
      assert SemanticNetwork.get_node(filtered2, :animal) != nil
      
      # Cross-context edge should be filtered out
      assert SemanticNetwork.get_edge(filtered2, :dog, :car, :can_ride_in) == nil
    end
    
    test "to_assertions/1 converts network to assertions", %{network: network} do
      # Convert network to assertions
      assertions = SemanticNetwork.to_assertions(network)
      
      # Check for node assertions
      assert MapSet.member?(assertions, {:node, [:dog, :concept]})
      assert MapSet.member?(assertions, {:property, [:dog, :domestic, true]})
      
      # Check for edge assertions
      assert MapSet.member?(assertions, {:relation, [:dog, :mammal, :is_a, 1.0]})
      assert MapSet.member?(assertions, {:relation, [:dog, :car, :can_ride_in, 0.8]})
    end
  end
end