defmodule Automata.Reasoning.Cognitive.NeuroIntegration.NeuroevolutionManager do
  @moduledoc """
  Manages the neuroevolution process for neural networks in the Automata system.
  
  This module serves as the integration point between Automata's perception system and
  the TWEANN (Topology and Weight Evolving Artificial Neural Network) implementation.
  
  Key responsibilities:
  - Configuration of neural network populations
  - Fitness evaluation using perception-driven criteria
  - Evolution control (starting, stopping, monitoring)
  - Persisting and loading evolved networks
  - Providing evolved networks to the perception system
  """
  
  alias Automaton.Types.TWEANN.Evolution.PopulationManager
  alias Automaton.Types.TWEANN.Evolution.Genotype
  alias Automaton.Types.TWEANN.ExoSelf
  alias Automata.Reasoning.Cognitive.Perceptory.EnhancedPerceptory
  alias Automata.Reasoning.Cognitive.NeuroIntegration.PerceptionAdapter
  
  require Logger
  
  defstruct [
    :population_manager,    # The TWEANN population manager
    :config,                # Configuration parameters
    :perception_adapter,    # Adapter to the perception system
    :fitness_evaluator,     # Module implementing fitness evaluation
    :best_network_file,     # Path to best network file
    :evolution_status,      # :idle, :running, or :completed
    :generation_callback,   # Optional callback function for generation events
    :training_data,         # Cached perception data for training
    :best_fitness           # Current best fitness
  ]
  
  @doc """
  Creates a new neuroevolution manager.
  
  ## Parameters
  - config: Configuration for evolution
  - perception_adapter: Adapter to connect with perception system
  - fitness_evaluator: Module implementing fitness evaluation
  
  ## Returns
  A new NeuroevolutionManager struct
  """
  def new(config, perception_adapter, fitness_evaluator) do
    %__MODULE__{
      population_manager: nil,
      config: config,
      perception_adapter: perception_adapter,
      fitness_evaluator: fitness_evaluator,
      best_network_file: nil,
      evolution_status: :idle,
      generation_callback: nil,
      training_data: [],
      best_fitness: 0.0
    }
  end
  
  @doc """
  Initializes the neuroevolution population.
  
  ## Parameters
  - manager: The neuroevolution manager
  
  ## Returns
  Updated manager with initialized population
  """
  def initialize(manager) do
    # Create population manager
    population_manager = PopulationManager.new(
      manager.config.sensor_name,
      manager.config.actuator_name,
      manager.config.hidden_layer_spec,
      manager.config,
      manager.fitness_evaluator
    )
    
    %{manager | 
      population_manager: population_manager, 
      evolution_status: :idle
    }
  end
  
  @doc """
  Starts the evolution process.
  
  ## Parameters
  - manager: The neuroevolution manager
  - generations: Number of generations to evolve
  - callback: Optional callback function called after each generation
  
  ## Returns
  Updated manager with evolution in progress
  """
  def start_evolution(manager, generations, callback \\ nil) do
    if manager.evolution_status != :running do
      # Set up callback
      manager = %{manager | generation_callback: callback, evolution_status: :running}
      
      # Start evolution process in separate process
      spawn_link(fn -> 
        evolved_manager = run_evolution(manager, generations)
        
        # Send result back to caller
        if Process.alive?(self()) do
          send(self(), {:evolution_completed, evolved_manager})
        end
      end)
      
      manager
    else
      # Already running
      manager
    end
  end
  
  @doc """
  Stops the current evolution process.
  
  ## Parameters
  - manager: The neuroevolution manager
  
  ## Returns
  Updated manager with evolution stopped
  """
  def stop_evolution(manager) do
    %{manager | evolution_status: :idle}
  end
  
  @doc """
  Gets the best neural network from the current population.
  
  ## Parameters
  - manager: The neuroevolution manager
  
  ## Returns
  Tuple of {network_file, fitness}
  """
  def get_best_network(manager) do
    if manager.best_network_file do
      {manager.best_network_file, manager.best_fitness}
    else
      # No best network yet
      {nil, 0.0}
    end
  end
  
  @doc """
  Adds perception data to the training dataset.
  
  ## Parameters
  - manager: The neuroevolution manager
  - perception_data: Perception data to add
  - reward: Associated reward value
  
  ## Returns
  Updated manager with new training data
  """
  def add_training_data(manager, perception_data, reward) do
    # Add to training data cache
    updated_training_data = manager.training_data ++ [{perception_data, reward}]
    
    # Limit cache size
    limited_data = if length(updated_training_data) > manager.config.max_training_cache do
      Enum.drop(updated_training_data, length(updated_training_data) - manager.config.max_training_cache)
    else
      updated_training_data
    end
    
    %{manager | training_data: limited_data}
  end
  
  @doc """
  Evaluates a single genotype using the fitness evaluator.
  
  ## Parameters
  - manager: The neuroevolution manager
  - genotype: The genotype to evaluate
  
  ## Returns
  Fitness score
  """
  def evaluate_genotype(manager, genotype) do
    # Convert genotype to neural network
    network_file = "temp_network_#{:rand.uniform(1_000_000)}.gen"
    
    # Save genotype to file
    raw_genotype = Genotype.to_raw(genotype)
    {:ok, file} = :file.open(network_file, :write)
    :lists.foreach(fn x -> :io.format(file, "~p.~n", [x]) end, raw_genotype)
    :file.close(file)
    
    # Run fitness evaluation
    fitness = apply(manager.fitness_evaluator, :evaluate, [
      network_file, 
      manager.perception_adapter,
      manager.training_data
    ])
    
    # Clean up
    File.rm(network_file)
    
    fitness
  end
  
  @doc """
  Saves the best network to a specified file.
  
  ## Parameters
  - manager: The neuroevolution manager
  - file_path: Path to save the network to
  
  ## Returns
  :ok on success, {:error, reason} on failure
  """
  def save_best_network(manager, file_path) do
    if manager.best_network_file do
      # Copy the best network file
      File.copy(manager.best_network_file, file_path)
    else
      {:error, :no_best_network}
    end
  end
  
  @doc """
  Loads a previously saved network into the perception adapter.
  
  ## Parameters
  - manager: The neuroevolution manager
  - file_path: Path to load the network from
  
  ## Returns
  Updated manager with network loaded into perception adapter
  """
  def load_network_to_adapter(manager, file_path) do
    if File.exists?(file_path) do
      # Initialize the network in the perception adapter
      updated_adapter = PerceptionAdapter.initialize_network(
        manager.perception_adapter, 
        file_path
      )
      
      %{manager | perception_adapter: updated_adapter}
    else
      Logger.error("Network file not found: #{file_path}")
      manager
    end
  end
  
  # Private helper functions
  
  defp run_evolution(manager, generations) do
    # Execute evolution process
    evolved_pop_manager = PopulationManager.evolve(
      manager.population_manager, 
      generations
    )
    
    # Get best genotype
    best_genotype = evolved_pop_manager.best_genotype
    best_fitness = evolved_pop_manager.best_fitness
    
    # Save best network to file
    best_file = "best_network_#{DateTime.utc_now() |> DateTime.to_unix()}.gen"
    raw_genotype = Genotype.to_raw(best_genotype)
    {:ok, file} = :file.open(best_file, :write)
    :lists.foreach(fn x -> :io.format(file, "~p.~n", [x]) end, raw_genotype)
    :file.close(file)
    
    Logger.info("Evolution completed. Best fitness: #{best_fitness}")
    Logger.info("Best network saved to: #{best_file}")
    
    # Update manager
    %{manager | 
      population_manager: evolved_pop_manager,
      best_network_file: best_file,
      best_fitness: best_fitness,
      evolution_status: :completed
    }
  end
  
  defp update_progress(manager, generation, best_fitness) do
    if manager.generation_callback do
      manager.generation_callback.(generation, best_fitness)
    end
    
    # Log progress
    Logger.info("Evolution generation #{generation} - Best fitness: #{best_fitness}")
  end
end