defmodule Automaton.Types.TWEANN.Evolution.GeneticOperators do
  @moduledoc """
  Implements genetic operators for TWEANN evolution.
  
  Includes:
  - Mutation (weight, add node, add connection)
  - Crossover
  - Genetic distance calculation
  
  These operators follow NEAT principles for meaningful evolution of neural network
  topologies with historical marking.
  """
  
  alias Automaton.Types.TWEANN.Evolution.Genotype
  alias Automaton.Types.TWEANN.Evolution.Genotype.NodeGene
  alias Automaton.Types.TWEANN.Evolution.Genotype.ConnectionGene
  
  require Logger
  
  @doc """
  Applies mutations to a genotype based on configured probabilities.
  
  ## Parameters
  - genotype: The genotype to mutate
  - config: Configuration with mutation rates
  
  ## Returns
  Mutated genotype
  """
  def mutate(genotype, config) do
    genotype
    |> mutate_weights(config.weight_mutation_rate, config.weight_perturbation_rate)
    |> mutate_add_node(config.add_node_mutation_rate)
    |> mutate_add_connection(config.add_connection_mutation_rate)
    |> mutate_enable_disable(config.toggle_connection_mutation_rate)
  end
  
  @doc """
  Performs crossover between two parent genotypes to produce a child.
  
  ## Parameters
  - parent1: First parent genotype
  - parent2: Second parent genotype
  
  ## Returns
  Child genotype
  """
  def crossover(parent1, parent2) do
    # Determine which parent is fitter for gene selection preference
    {fit_parent, less_fit_parent} = if parent1.fitness >= parent2.fitness do
      {parent1, parent2}
    else
      {parent2, parent1}
    end
    
    # Create child node genes (combine all unique nodes)
    child_nodes = merge_node_genes(fit_parent.node_genes, less_fit_parent.node_genes)
    
    # Create child connection genes (handle matching, disjoint, and excess genes)
    child_connections = merge_connection_genes(
      fit_parent.connection_genes, 
      less_fit_parent.connection_genes
    )
    
    # Create child genotype
    %Genotype{
      id: generate_id(),
      node_genes: child_nodes,
      connection_genes: child_connections,
      sensors: fit_parent.sensors,
      actuators: fit_parent.actuators,
      fitness: 0.0,
      adjusted_fitness: 0.0,
      species_id: fit_parent.species_id,
      generation_created: fit_parent.generation_created + 1
    }
  end
  
  @doc """
  Calculates genetic distance between two genotypes for speciation.
  
  ## Parameters
  - genotype1: First genotype
  - genotype2: Second genotype
  
  ## Returns
  Numeric distance value
  """
  def genetic_distance(genotype1, genotype2) do
    Genotype.compatibility_distance(genotype1, genotype2)
  end
  
  # Private implementation
  
  defp mutate_weights(genotype, mutation_rate, perturbation_rate) do
    # Apply weight mutations to connection genes
    connections = Enum.map(genotype.connection_genes, fn conn ->
      if :rand.uniform() < mutation_rate do
        if :rand.uniform() < perturbation_rate do
          # Perturb weight
          %{conn | weight: conn.weight + (:rand.uniform() * 2 - 1) * 0.5}
        else
          # Assign new random weight
          %{conn | weight: :rand.uniform() * 4 - 2}
        end
      else
        conn
      end
    end)
    
    %{genotype | connection_genes: connections}
  end
  
  defp mutate_add_node(genotype, mutation_rate) do
    if :rand.uniform() < mutation_rate do
      # Select a random enabled connection to split
      enabled_connections = Enum.filter(genotype.connection_genes, & &1.enabled)
      
      case enabled_connections do
        [] -> 
          # No connections to split
          genotype
          
        connections ->
          # Randomly select a connection to split
          conn = Enum.random(connections)
          
          # Create a new node in between
          new_node_id = {:neuron, {0, generate_id()}}
          new_node = %NodeGene{
            id: new_node_id,
            type: :neuron,
            activation_function: :sigmoid,
            layer: 0,  # Will be fixed during network construction
            innovation_number: hash_node(conn.in_node_id, conn.out_node_id)
          }
          
          # Create two new connections
          in_to_new = %ConnectionGene{
            in_node_id: conn.in_node_id,
            out_node_id: new_node_id,
            weight: 1.0,  # Weight to the new node is 1.0
            enabled: true,
            innovation_number: hash_connection(conn.in_node_id, new_node_id),
            recurrent: false
          }
          
          new_to_out = %ConnectionGene{
            in_node_id: new_node_id,
            out_node_id: conn.out_node_id,
            weight: conn.weight,  # Preserve the original connection weight
            enabled: true,
            innovation_number: hash_connection(new_node_id, conn.out_node_id),
            recurrent: false
          }
          
          # Disable the original connection
          updated_connections = Enum.map(genotype.connection_genes, fn c ->
            if c.innovation_number == conn.innovation_number do
              %{c | enabled: false}
            else
              c
            end
          end)
          
          # Add the new node and connections
          %{genotype |
            node_genes: [new_node | genotype.node_genes],
            connection_genes: [in_to_new, new_to_out | updated_connections]
          }
      end
    else
      genotype
    end
  end
  
  defp mutate_add_connection(genotype, mutation_rate) do
    if :rand.uniform() < mutation_rate do
      # Find potential connection endpoints (excluding sensors as outputs and actuators as inputs)
      potential_inputs = Enum.filter(genotype.node_genes, fn node ->
        node.type == :sensor || node.type == :neuron
      end)
      
      potential_outputs = Enum.filter(genotype.node_genes, fn node ->
        node.type == :neuron || node.type == :actuator
      end)
      
      # Check all existing connections to avoid duplicates
      existing_connections = MapSet.new(
        for conn <- genotype.connection_genes,
          do: {conn.in_node_id, conn.out_node_id}
      )
      
      # Find valid new connections
      valid_new_connections = for in_node <- potential_inputs,
                                  out_node <- potential_outputs,
                                  in_node.id != out_node.id,
                                  !MapSet.member?(existing_connections, {in_node.id, out_node.id}),
                                  do: {in_node.id, out_node.id}
      
      case valid_new_connections do
        [] -> 
          # No valid connections to add
          genotype
          
        connections ->
          # Randomly select a connection to add
          {in_id, out_id} = Enum.random(connections)
          
          # Create new connection
          new_conn = %ConnectionGene{
            in_node_id: in_id,
            out_node_id: out_id,
            weight: :rand.uniform() * 4 - 2,  # Random weight between -2 and 2
            enabled: true,
            innovation_number: hash_connection(in_id, out_id),
            recurrent: false
          }
          
          # Add the new connection
          %{genotype | connection_genes: [new_conn | genotype.connection_genes]}
      end
    else
      genotype
    end
  end
  
  defp mutate_enable_disable(genotype, mutation_rate) do
    if :rand.uniform() < mutation_rate do
      # Find connections that can be toggled
      toggleable_connections = Enum.filter(genotype.connection_genes, fn conn ->
        # Don't disable connections if it would disconnect a node
        if conn.enabled do
          # Count connections to output node
          input_count = Enum.count(genotype.connection_genes, fn c -> 
            c.out_node_id == conn.out_node_id && c.enabled 
          end)
          # Only disable if there are multiple inputs
          input_count > 1
        else
          # Can always re-enable
          true
        end
      end)
      
      case toggleable_connections do
        [] -> 
          # No connections to toggle
          genotype
          
        connections ->
          # Randomly select a connection to toggle
          conn_to_toggle = Enum.random(connections)
          
          # Toggle the connection
          updated_connections = Enum.map(genotype.connection_genes, fn c ->
            if c.innovation_number == conn_to_toggle.innovation_number do
              %{c | enabled: !c.enabled}
            else
              c
            end
          end)
          
          %{genotype | connection_genes: updated_connections}
      end
    else
      genotype
    end
  end
  
  defp merge_node_genes(nodes1, nodes2) do
    # Create map for fast lookup
    nodes_map = Enum.reduce(nodes1, %{}, fn node, acc ->
      Map.put(acc, node.innovation_number, node)
    end)
    
    # Add unique nodes from second parent
    unique_nodes2 = Enum.reject(nodes2, fn node ->
      Map.has_key?(nodes_map, node.innovation_number)
    end)
    
    nodes1 ++ unique_nodes2
  end
  
  defp merge_connection_genes(connections1, connections2) do
    # Sort connections by innovation number
    sorted1 = Enum.sort_by(connections1, & &1.innovation_number)
    sorted2 = Enum.sort_by(connections2, & &1.innovation_number)
    
    merge_sorted_connections(sorted1, sorted2, [])
  end
  
  defp merge_sorted_connections([], [], acc), do: Enum.reverse(acc)
  
  defp merge_sorted_connections([], [conn2 | rest2], acc) do
    # Add remaining genes from parent2 (less fit)
    merge_sorted_connections([], rest2, [conn2 | acc])
  end
  
  defp merge_sorted_connections([conn1 | rest1], [], acc) do
    # Add remaining genes from parent1 (more fit)
    merge_sorted_connections(rest1, [], [conn1 | acc])
  end
  
  defp merge_sorted_connections([conn1 | rest1], [conn2 | rest2], acc) do
    cond do
      conn1.innovation_number == conn2.innovation_number ->
        # Matching genes - randomly choose parent or average
        child_conn = if :rand.uniform() < 0.5, do: conn1, else: conn2
        merge_sorted_connections(rest1, rest2, [child_conn | acc])
        
      conn1.innovation_number < conn2.innovation_number ->
        # Disjoint gene from parent1 (more fit)
        merge_sorted_connections(rest1, [conn2 | rest2], [conn1 | acc])
        
      conn1.innovation_number > conn2.innovation_number ->
        # Disjoint gene from parent2 (less fit) - only include from fitter parent
        merge_sorted_connections([conn1 | rest1], rest2, acc)
    end
  end
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end
  
  defp hash_node(in_id, out_id) do
    # Historical marking for a node added between two nodes
    :erlang.phash2({:node_between, in_id, out_id}, 1_000_000_000)
  end
  
  defp hash_connection(in_id, out_id) do
    # Historical marking for a connection between two nodes
    :erlang.phash2({:connection, in_id, out_id}, 1_000_000_000)
  end
end