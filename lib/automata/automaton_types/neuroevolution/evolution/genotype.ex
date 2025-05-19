defmodule Automaton.Types.TWEANN.Evolution.Genotype do
  @moduledoc """
  Represents the genetic encoding of a neural network in the TWEANN system.
  
  This implementation follows principles from NEAT (NeuroEvolution of Augmenting Topologies):
  - Tracks genes with innovation numbers to align genomes during crossover
  - Separates node genes and connection genes
  - Supports structural mutations (adding nodes and connections)
  - Enables meaningful crossover between networks with different topologies
  """

  alias Automaton.Types.TWEANN.Cortex
  alias Automaton.Types.TWEANN.Neuron
  alias Automaton.Types.TWEANN.Sensor
  alias Automaton.Types.TWEANN.Actuator
  
  require Logger

  defstruct [
    :id,                      # Unique identifier
    :node_genes,              # List of neuron nodes
    :connection_genes,        # List of connections between nodes
    :sensors,                 # List of sensor nodes
    :actuators,               # List of actuator nodes
    :fitness,                 # Evaluated fitness
    :adjusted_fitness,        # Fitness adjusted for species sharing
    :species_id,              # ID of the species this genotype belongs to
    :generation_created       # Generation when this genotype was created
  ]

  # Node gene structure
  defmodule NodeGene do
    defstruct [
      :id,                    # Node ID
      :type,                  # :sensor, :neuron, :actuator, or :bias
      :activation_function,   # Activation function (for neurons)
      :layer,                 # Layer information (for layered networks)
      :innovation_number      # Historical marker
    ]
  end

  # Connection gene structure
  defmodule ConnectionGene do
    defstruct [
      :in_node_id,            # Source node ID
      :out_node_id,           # Target node ID
      :weight,                # Connection weight
      :enabled,               # Whether connection is enabled
      :innovation_number,     # Historical marker
      :recurrent              # Whether connection is recurrent
    ]
  end

  @doc """
  Creates a new genotype from raw network data.
  
  ## Parameters
  - raw_genotype: The raw genotype data from file
  
  ## Returns
  A new Genotype struct
  """
  def from_raw(raw_genotype) do
    # Extract components from raw genotype
    cortex = Enum.find(raw_genotype, fn x -> match?(%Cortex{}, x) end)
    sensors = Enum.filter(raw_genotype, fn x -> match?(%Sensor{}, x) end)
    actuators = Enum.filter(raw_genotype, fn x -> match?(%Actuator{}, x) end)
    neurons = Enum.filter(raw_genotype, fn x -> match?(%Neuron{}, x) end)
    
    # Convert to node genes
    node_genes = 
      (create_sensor_nodes(sensors) ++
       create_neuron_nodes(neurons) ++
       create_actuator_nodes(actuators))
    
    # Extract all connections from neurons
    connection_genes = extract_connections(neurons)
    
    %__MODULE__{
      id: generate_id(),
      node_genes: node_genes,
      connection_genes: connection_genes,
      sensors: sensors,
      actuators: actuators,
      fitness: 0.0,
      adjusted_fitness: 0.0,
      species_id: nil,
      generation_created: 0
    }
  end
  
  @doc """
  Converts a genotype back to the raw format for network instantiation.
  
  ## Parameters
  - genotype: The genotype to convert
  
  ## Returns
  A list of raw network component structures
  """
  def to_raw(genotype) do
    # Recreate neurons with proper connections
    neurons = convert_to_neurons(genotype)
    
    # Recreate cortex
    sensor_ids = Enum.map(genotype.sensors, & &1.id)
    actuator_ids = Enum.map(genotype.actuators, & &1.id)
    neuron_ids = Enum.map(neurons, & &1.id)
    
    cortex = %Cortex{
      id: {:cortex, generate_id()},
      sensor_ids: sensor_ids,
      actuator_ids: actuator_ids,
      n_ids: neuron_ids
    }
    
    # Combine all components
    [cortex | genotype.sensors ++ genotype.actuators ++ neurons]
  end
  
  @doc """
  Calculates the compatibility distance between two genotypes.
  
  ## Parameters
  - genotype1: First genotype
  - genotype2: Second genotype
  - c1: Coefficient for excess genes
  - c2: Coefficient for disjoint genes
  - c3: Coefficient for weight differences
  
  ## Returns
  A float representing the genetic distance
  """
  def compatibility_distance(genotype1, genotype2, c1 \\ 1.0, c2 \\ 1.0, c3 \\ 0.4) do
    # Count connection gene matches
    {matching, disjoint1, disjoint2, excess1, excess2} = count_gene_differences(
      genotype1.connection_genes, 
      genotype2.connection_genes
    )
    
    # Calculate average weight difference for matching genes
    weight_diff = calculate_average_weight_diff(
      matching, 
      genotype1.connection_genes, 
      genotype2.connection_genes
    )
    
    # Calculate normalized distance
    n = max(length(genotype1.connection_genes), length(genotype2.connection_genes))
    n = if n < 20, do: 1, else: n  # Small genomes aren't normalized
    
    excess = length(excess1) + length(excess2)
    disjoint = length(disjoint1) + length(disjoint2)
    
    c1 * excess / n + c2 * disjoint / n + c3 * weight_diff
  end
  
  # Private helper functions
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end
  
  defp create_sensor_nodes(sensors) do
    Enum.map(sensors, fn sensor ->
      %NodeGene{
        id: sensor.id,
        type: :sensor,
        activation_function: nil,
        layer: 0,  # Sensors are always in input layer
        innovation_number: hash_id(sensor.id)
      }
    end)
  end
  
  defp create_neuron_nodes(neurons) do
    Enum.map(neurons, fn neuron ->
      # Extract layer from neuron id if available
      layer = case neuron.id do
        {:neuron, {layer, _}} -> layer
        _ -> 1  # Default to hidden layer
      end
      
      %NodeGene{
        id: neuron.id,
        type: :neuron,
        activation_function: neuron.af,
        layer: layer,
        innovation_number: hash_id(neuron.id)
      }
    end)
  end
  
  defp create_actuator_nodes(actuators) do
    Enum.map(actuators, fn actuator ->
      %NodeGene{
        id: actuator.id,
        type: :actuator,
        activation_function: nil,
        layer: 999,  # Actuators are always in output layer
        innovation_number: hash_id(actuator.id)
      }
    end)
  end
  
  defp extract_connections(neurons) do
    Enum.flat_map(neurons, fn neuron ->
      # Extract connections from input_id_ps
      Enum.flat_map(neuron.input_id_ps, fn
        # Skip bias
        {:bias, _} -> []
        
        # Regular connection
        {in_id, weights} when is_list(weights) ->
          # Create a connection for each weight
          Enum.map(Enum.with_index(weights), fn {weight, idx} ->
            innovation = hash_connection(in_id, neuron.id, idx)
            %ConnectionGene{
              in_node_id: in_id,
              out_node_id: neuron.id,
              weight: weight,
              enabled: true,
              innovation_number: innovation,
              recurrent: false
            }
          end)
          
        # Single weight connection
        {in_id, weight} ->
          innovation = hash_connection(in_id, neuron.id, 0)
          [%ConnectionGene{
            in_node_id: in_id,
            out_node_id: neuron.id,
            weight: weight,
            enabled: true,
            innovation_number: innovation,
            recurrent: false
          }]
      end)
    end)
  end
  
  defp convert_to_neurons(genotype) do
    # Group connections by output node
    connections_by_output = Enum.reduce(genotype.connection_genes, %{}, fn conn, acc ->
      if conn.enabled do
        outputs = Map.get(acc, conn.out_node_id, [])
        Map.put(acc, conn.out_node_id, [{conn.in_node_id, conn.weight} | outputs])
      else
        acc
      end
    end)
    
    # Find neuron nodes
    neuron_nodes = Enum.filter(genotype.node_genes, fn node -> node.type == :neuron end)
    
    # Convert each neuron node to neuron structure
    Enum.map(neuron_nodes, fn node ->
      # Get connections to this neuron
      input_connections = Map.get(connections_by_output, node.id, [])
      
      # Add bias if not present
      input_id_ps = if Enum.any?(input_connections, fn {id, _} -> id == :bias end) do
        input_connections
      else
        [{:bias, :rand.uniform() - 0.5} | input_connections]
      end
      
      # Get output connections
      output_ids = Enum.filter_map(genotype.connection_genes, 
        fn conn -> conn.in_node_id == node.id && conn.enabled end,
        fn conn -> conn.out_node_id end
      )
      
      # Create neuron structure
      %Neuron{
        id: node.id,
        cx_id: nil,  # Will be set during network construction
        af: node.activation_function || :tanh,
        input_id_ps: input_id_ps,
        output_ids: output_ids
      }
    end)
  end
  
  defp hash_id(id) do
    :erlang.phash2(id, 1_000_000_000)
  end
  
  defp hash_connection(in_id, out_id, index) do
    :erlang.phash2({in_id, out_id, index}, 1_000_000_000)
  end
  
  defp count_gene_differences(genes1, genes2) do
    # Sort genes by innovation number
    sorted1 = Enum.sort_by(genes1, & &1.innovation_number)
    sorted2 = Enum.sort_by(genes2, & &1.innovation_number)
    
    # Find highest innovation in each list
    max_innov1 = if length(sorted1) > 0, do: List.last(sorted1).innovation_number, else: 0
    max_innov2 = if length(sorted2) > 0, do: List.last(sorted2).innovation_number, else: 0
    
    # Process genes
    count_gene_differences(sorted1, sorted2, max_innov1, max_innov2, {[], [], [], [], []})
  end
  
  defp count_gene_differences([], [], _, _, acc), do: acc
  
  defp count_gene_differences([], [gene2 | rest2], max_innov1, max_innov2, {matching, disjoint1, disjoint2, excess1, excess2}) do
    if gene2.innovation_number > max_innov1 do
      # Gene2 is excess
      count_gene_differences([], rest2, max_innov1, max_innov2, {matching, disjoint1, disjoint2, excess1, [gene2 | excess2]})
    else
      # Gene2 is disjoint
      count_gene_differences([], rest2, max_innov1, max_innov2, {matching, disjoint1, [gene2 | disjoint2], excess1, excess2})
    end
  end
  
  defp count_gene_differences([gene1 | rest1], [], max_innov1, max_innov2, {matching, disjoint1, disjoint2, excess1, excess2}) do
    if gene1.innovation_number > max_innov2 do
      # Gene1 is excess
      count_gene_differences(rest1, [], max_innov1, max_innov2, {matching, disjoint1, disjoint2, [gene1 | excess1], excess2})
    else
      # Gene1 is disjoint
      count_gene_differences(rest1, [], max_innov1, max_innov2, {matching, [gene1 | disjoint1], disjoint2, excess1, excess2})
    end
  end
  
  defp count_gene_differences([gene1 | rest1], [gene2 | rest2], max_innov1, max_innov2, acc) do
    {matching, disjoint1, disjoint2, excess1, excess2} = acc
    
    cond do
      gene1.innovation_number == gene2.innovation_number ->
        # Matching genes
        count_gene_differences(rest1, rest2, max_innov1, max_innov2, 
          {[{gene1, gene2} | matching], disjoint1, disjoint2, excess1, excess2})
        
      gene1.innovation_number < gene2.innovation_number ->
        # Gene1 is disjoint
        count_gene_differences(rest1, [gene2 | rest2], max_innov1, max_innov2,
          {matching, [gene1 | disjoint1], disjoint2, excess1, excess2})
        
      gene1.innovation_number > gene2.innovation_number ->
        # Gene2 is disjoint
        count_gene_differences([gene1 | rest1], rest2, max_innov1, max_innov2,
          {matching, disjoint1, [gene2 | disjoint2], excess1, excess2})
    end
  end
  
  defp calculate_average_weight_diff(matching_genes, _genes1, _genes2) do
    case matching_genes do
      [] -> 0.0
      _ ->
        total_diff = Enum.sum(for {gene1, gene2} <- matching_genes, do: abs(gene1.weight - gene2.weight))
        total_diff / length(matching_genes)
    end
  end
end