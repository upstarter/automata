defmodule Automaton.Types.TWEANN.Evolution.PopulationManager do
  @moduledoc """
  Manages a population of neural networks undergoing evolution.
  
  The PopulationManager handles:
  - Maintaining a population of genotypes
  - Coordinating fitness evaluation
  - Selection of parents for reproduction
  - Application of genetic operators (mutation and crossover)
  - Species management for diversity preservation
  - Statistics tracking across generations
  """

  alias Automaton.Types.TWEANN.Evolution.Species
  alias Automaton.Types.TWEANN.Evolution.Genotype
  alias Automaton.Types.TWEANN.Evolution.GeneticOperators
  alias Automaton.Types.TWEANN.Constructor
  alias Automaton.Types.TWEANN.ExoSelf
  
  require Logger

  defstruct [
    :population,           # List of genotypes
    :species,              # List of species
    :generation,           # Current generation number
    :config,               # Configuration parameters
    :innovation_counter,   # Counter for assigning unique innovation numbers
    :best_fitness,         # Best fitness seen so far
    :best_genotype,        # Best genotype seen so far
    :fitness_evaluator,    # Module implementing fitness evaluation
    :stats                 # Statistical data about evolution progress
  ]

  @doc """
  Creates a new population manager with initial random population.
  
  ## Parameters
  - sensor_name: Sensor type for the networks
  - actuator_name: Actuator type for the networks
  - hidden_layer_spec: Initial hidden layer structure
  - config: Configuration parameters for evolution
  - fitness_evaluator: Module implementing fitness evaluation
  
  ## Returns
  A new PopulationManager struct
  """
  def new(sensor_name, actuator_name, hidden_layer_spec, config, fitness_evaluator) do
    # Generate initial population
    population = create_initial_population(
      sensor_name, 
      actuator_name, 
      hidden_layer_spec, 
      config.population_size
    )
    
    # Initialize manager
    %__MODULE__{
      population: population,
      species: [],
      generation: 0,
      config: config,
      innovation_counter: 0,
      best_fitness: 0,
      best_genotype: nil,
      fitness_evaluator: fitness_evaluator,
      stats: %{
        avg_fitness_history: [],
        best_fitness_history: [],
        species_count_history: []
      }
    }
    |> speciate()
  end
  
  @doc """
  Runs the evolutionary process for a specified number of generations.
  
  ## Parameters
  - manager: The population manager
  - generations: Number of generations to evolve
  
  ## Returns
  Updated population manager with evolved population
  """
  def evolve(manager, generations) do
    Enum.reduce(1..generations, manager, fn gen, acc_manager ->
      Logger.info("Starting generation #{gen}/#{generations}")
      
      # Evaluate fitness of all genotypes
      updated_manager = evaluate_fitness(acc_manager)
      
      # Log statistics
      log_generation_stats(updated_manager)
      
      # Create next generation
      next_generation(updated_manager)
    end)
  end
  
  @doc """
  Evaluates the fitness of all genotypes in the population.
  
  ## Parameters
  - manager: The population manager
  
  ## Returns
  Updated manager with fitness scores
  """
  def evaluate_fitness(manager) do
    # Evaluate each genotype
    population_with_fitness = Enum.map(manager.population, fn genotype ->
      fitness = apply(manager.fitness_evaluator, :evaluate, [genotype])
      %{genotype | fitness: fitness}
    end)
    
    # Find best genotype
    best = Enum.max_by(population_with_fitness, & &1.fitness)
    
    # Update manager
    %{manager | 
      population: population_with_fitness,
      best_fitness: if(best.fitness > manager.best_fitness, do: best.fitness, else: manager.best_fitness),
      best_genotype: if(best.fitness > manager.best_fitness, do: best, else: manager.best_genotype)
    }
  end
  
  @doc """
  Creates the next generation through selection, crossover, and mutation.
  
  ## Parameters
  - manager: The population manager
  
  ## Returns
  Updated manager with new generation
  """
  def next_generation(manager) do
    # Calculate adjusted fitness and determine how many offspring each species gets
    species_with_offspring = calculate_offspring_counts(manager)
    
    # Create offspring
    new_population = generate_offspring(species_with_offspring, manager)
    
    # Update manager
    %{manager | 
      population: new_population,
      generation: manager.generation + 1
    }
    |> speciate() # Re-speciate the population
    |> update_stats()
  end
  
  @doc """
  Divides the population into species based on genetic similarity.
  
  ## Parameters
  - manager: The population manager
  
  ## Returns
  Updated manager with population divided into species
  """
  def speciate(manager) do
    # Clear existing species
    species = Enum.map(manager.species, fn s -> %{s | members: []} end)
    
    # Assign each genotype to a species
    {updated_species, unassigned} = Enum.reduce(manager.population, {species, []}, 
      fn genotype, {species_acc, unassigned_acc} ->
        case find_compatible_species(genotype, species_acc, manager.config.compatibility_threshold) do
          nil -> {species_acc, [genotype | unassigned_acc]}
          species_index -> 
            updated_species = List.update_at(species_acc, species_index, fn s -> 
              %{s | members: [genotype | s.members]}
            end)
            {updated_species, unassigned_acc}
        end
      end)
    
    # Create new species for unassigned genotypes
    new_species = Enum.map(unassigned, fn genotype -> 
      Species.new([genotype], genotype)
    end)
    
    # Remove empty species
    non_empty_species = Enum.filter(updated_species, fn s -> length(s.members) > 0 end)
    
    # Update manager
    %{manager | species: non_empty_species ++ new_species}
  end
  
  # Private helper functions
  
  defp create_initial_population(sensor_name, actuator_name, hidden_layer_spec, size) do
    Enum.map(1..size, fn _ ->
      # Create a genotype with random structure
      genotype_file = "gen_#{:rand.uniform(1_000_000)}.gen"
      Constructor.construct_genotype(genotype_file, sensor_name, actuator_name, hidden_layer_spec)
      
      # Load the genotype and convert to our internal format
      {:ok, genotype_raw} = :file.consult(genotype_file)
      Genotype.from_raw(genotype_raw)
    end)
  end
  
  defp find_compatible_species(genotype, species, threshold) do
    Enum.find_index(species, fn s -> 
      GeneticOperators.genetic_distance(genotype, s.representative) < threshold
    end)
  end
  
  defp calculate_offspring_counts(manager) do
    # Calculate total adjusted fitness
    species_with_fitness = Enum.map(manager.species, fn species ->
      avg_fitness = calculate_average_fitness(species)
      {species, avg_fitness}
    end)
    
    total_adjusted_fitness = Enum.sum(for {_, fitness} <- species_with_fitness, do: fitness)
    
    # Allocate offspring
    Enum.map(species_with_fitness, fn {species, fitness} ->
      offspring_count = round(fitness / total_adjusted_fitness * manager.config.population_size)
      {species, offspring_count}
    end)
  end
  
  defp calculate_average_fitness(species) do
    total = Enum.sum(for genotype <- species.members, do: genotype.fitness)
    total / length(species.members)
  end
  
  defp generate_offspring(species_with_counts, manager) do
    # Generate offspring for each species
    offspring = Enum.flat_map(species_with_counts, fn {species, count} ->
      # Ensure elitism - keep best member if species is large enough
      elite = if length(species.members) > 5 do
        [Enum.max_by(species.members, & &1.fitness)]
      else
        []
      end
      
      # Generate remaining offspring
      new_offspring = if count > 1 do
        Enum.map(1..(count - length(elite)), fn _ ->
          if :rand.uniform() < manager.config.crossover_rate and length(species.members) >= 2 do
            # Sexual reproduction (crossover + mutation)
            parent1 = select_parent(species)
            parent2 = select_parent(species)
            child = GeneticOperators.crossover(parent1, parent2)
            GeneticOperators.mutate(child, manager.config)
          else
            # Asexual reproduction (mutation only)
            parent = select_parent(species)
            GeneticOperators.mutate(parent, manager.config)
          end
        end)
      else
        []
      end
      
      elite ++ new_offspring
    end)
    
    # Ensure population size remains constant
    if length(offspring) < manager.config.population_size do
      # Add random new genotypes if needed
      additional = manager.config.population_size - length(offspring)
      offspring ++ create_initial_population(
        manager.config.sensor_name, 
        manager.config.actuator_name,
        manager.config.hidden_layer_spec,
        additional
      )
    else
      # Truncate if we have too many
      Enum.take(offspring, manager.config.population_size)
    end
  end
  
  defp select_parent(species) do
    # Tournament selection
    tournament_size = min(3, length(species.members))
    
    # Select random contestants and pick the best
    contestants = Enum.take_random(species.members, tournament_size)
    Enum.max_by(contestants, & &1.fitness)
  end
  
  defp update_stats(manager) do
    # Calculate statistics
    avg_fitness = Enum.sum(for g <- manager.population, do: g.fitness) / length(manager.population)
    best_fitness = Enum.max_by(manager.population, & &1.fitness).fitness
    species_count = length(manager.species)
    
    # Update stats history
    %{manager | 
      stats: %{
        avg_fitness_history: [avg_fitness | manager.stats.avg_fitness_history],
        best_fitness_history: [best_fitness | manager.stats.best_fitness_history],
        species_count_history: [species_count | manager.stats.species_count_history]
      }
    }
  end
  
  defp log_generation_stats(manager) do
    best = Enum.max_by(manager.population, & &1.fitness)
    avg = Enum.sum(for g <- manager.population, do: g.fitness) / length(manager.population)
    species_count = length(manager.species)
    
    Logger.info("Generation #{manager.generation} stats:")
    Logger.info("  Best fitness: #{best.fitness}")
    Logger.info("  Average fitness: #{avg}")
    Logger.info("  Species count: #{species_count}")
    Logger.info("  All-time best: #{manager.best_fitness}")
  end
end