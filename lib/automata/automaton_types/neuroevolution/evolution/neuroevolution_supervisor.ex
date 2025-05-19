defmodule Automaton.Types.TWEANN.Evolution.NeuroevolutionSupervisor do
  @moduledoc """
  Supervisor for the neuroevolution system.
  
  This supervisor manages the neuroevolution process, including:
  - Population management
  - Fitness evaluation
  - Species tracking
  - Evolution statistics
  
  The supervisor ensures that the evolution process can recover from crashes
  and provides clean lifecycle management for all neuroevolution components.
  """
  
  use Supervisor
  alias Automaton.Types.TWEANN.Evolution.PopulationManager
  alias Automaton.Types.TWEANN.Evolution.EvolutionServer
  alias Automaton.Types.TWEANN.Evolution.FitnessEvaluationServer
  
  require Logger
  
  @doc """
  Starts the neuroevolution supervisor.
  
  ## Parameters
  - config: Configuration for the neuroevolution system
  - opts: Supervisor options
  
  ## Returns
  {:ok, pid} on success, {:error, reason} on failure
  """
  def start_link(config, opts \\ []) do
    Supervisor.start_link(__MODULE__, config, opts)
  end
  
  @doc """
  Initializes the supervisor.
  
  ## Parameters
  - config: Configuration for the neuroevolution system
  
  ## Returns
  Supervisor specification
  """
  @impl true
  def init(config) do
    children = [
      # Evolution server manages the overall evolution process
      {EvolutionServer, config},
      
      # Fitness evaluation server handles parallel fitness evaluation
      {FitnessEvaluationServer, config},
      
      # Population manager maintains the current population
      {PopulationManager, config}
    ]
    
    # Start with one_for_one strategy - if a child crashes, only restart that child
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Gets the current population manager.
  
  ## Parameters
  - supervisor: Supervisor PID
  
  ## Returns
  PID of the population manager
  """
  def get_population_manager(supervisor) do
    Supervisor.which_children(supervisor)
    |> Enum.find_value(fn {id, pid, _type, _modules} ->
      if id == PopulationManager, do: pid, else: nil
    end)
  end
  
  @doc """
  Gets the evolution server.
  
  ## Parameters
  - supervisor: Supervisor PID
  
  ## Returns
  PID of the evolution server
  """
  def get_evolution_server(supervisor) do
    Supervisor.which_children(supervisor)
    |> Enum.find_value(fn {id, pid, _type, _modules} ->
      if id == EvolutionServer, do: pid, else: nil
    end)
  end
  
  @doc """
  Gets the fitness evaluation server.
  
  ## Parameters
  - supervisor: Supervisor PID
  
  ## Returns
  PID of the fitness evaluation server
  """
  def get_fitness_evaluation_server(supervisor) do
    Supervisor.which_children(supervisor)
    |> Enum.find_value(fn {id, pid, _type, _modules} ->
      if id == FitnessEvaluationServer, do: pid, else: nil
    end)
  end
  
  @doc """
  Starts the evolution process.
  
  ## Parameters
  - supervisor: Supervisor PID
  - generations: Number of generations to evolve
  - callback: Optional callback function for progress updates
  
  ## Returns
  :ok on success
  """
  def start_evolution(supervisor, generations, callback \\ nil) do
    evolution_server = get_evolution_server(supervisor)
    EvolutionServer.start_evolution(evolution_server, generations, callback)
  end
  
  @doc """
  Stops the evolution process.
  
  ## Parameters
  - supervisor: Supervisor PID
  
  ## Returns
  :ok on success
  """
  def stop_evolution(supervisor) do
    evolution_server = get_evolution_server(supervisor)
    EvolutionServer.stop_evolution(evolution_server)
  end
  
  @doc """
  Gets the best network from the current population.
  
  ## Parameters
  - supervisor: Supervisor PID
  
  ## Returns
  Tuple of {network_file, fitness}
  """
  def get_best_network(supervisor) do
    population_manager = get_population_manager(supervisor)
    PopulationManager.get_best_network(population_manager)
  end
  
  @doc """
  Gets statistics about the evolution process.
  
  ## Parameters
  - supervisor: Supervisor PID
  
  ## Returns
  Map of evolution statistics
  """
  def get_statistics(supervisor) do
    evolution_server = get_evolution_server(supervisor)
    EvolutionServer.get_statistics(evolution_server)
  end
  
  @doc """
  Adds training data for fitness evaluation.
  
  ## Parameters
  - supervisor: Supervisor PID
  - training_data: Data for fitness evaluation
  
  ## Returns
  :ok on success
  """
  def add_training_data(supervisor, training_data) do
    fitness_server = get_fitness_evaluation_server(supervisor)
    FitnessEvaluationServer.add_training_data(fitness_server, training_data)
  end
end

defmodule Automaton.Types.TWEANN.Evolution.EvolutionServer do
  @moduledoc """
  Server that manages the evolution process.
  
  This server coordinates the evolution of neural networks, including:
  - Starting and stopping evolution
  - Tracking evolution progress
  - Collecting and reporting statistics
  - Persisting best networks
  """
  
  use GenServer
  alias Automaton.Types.TWEANN.Evolution.PopulationManager
  alias Automaton.Types.TWEANN.Evolution.FitnessEvaluationServer
  
  require Logger
  
  defstruct [
    :config,
    :population_manager,
    :fitness_server,
    :evolution_task,
    :status,
    :generation,
    :best_fitness,
    :best_network_file,
    :stats,
    :callback
  ]
  
  # Client API
  
  @doc """
  Starts the evolution server.
  
  ## Parameters
  - config: Configuration for the evolution process
  - opts: GenServer options
  
  ## Returns
  {:ok, pid} on success, {:error, reason} on failure
  """
  def start_link(config, opts \\ []) do
    GenServer.start_link(__MODULE__, config, opts)
  end
  
  @doc """
  Starts the evolution process.
  
  ## Parameters
  - server: PID of the evolution server
  - generations: Number of generations to evolve
  - callback: Optional callback function for progress updates
  
  ## Returns
  :ok on success
  """
  def start_evolution(server, generations, callback \\ nil) do
    GenServer.cast(server, {:start_evolution, generations, callback})
  end
  
  @doc """
  Stops the evolution process.
  
  ## Parameters
  - server: PID of the evolution server
  
  ## Returns
  :ok on success
  """
  def stop_evolution(server) do
    GenServer.cast(server, :stop_evolution)
  end
  
  @doc """
  Gets the current status of the evolution process.
  
  ## Parameters
  - server: PID of the evolution server
  
  ## Returns
  Status of the evolution process
  """
  def get_status(server) do
    GenServer.call(server, :get_status)
  end
  
  @doc """
  Gets statistics about the evolution process.
  
  ## Parameters
  - server: PID of the evolution server
  
  ## Returns
  Map of evolution statistics
  """
  def get_statistics(server) do
    GenServer.call(server, :get_statistics)
  end
  
  @doc """
  Gets the best network from the current population.
  
  ## Parameters
  - server: PID of the evolution server
  
  ## Returns
  Tuple of {network_file, fitness}
  """
  def get_best_network(server) do
    GenServer.call(server, :get_best_network)
  end
  
  # Server callbacks
  
  @impl true
  def init(config) do
    {:ok, %__MODULE__{
      config: config,
      population_manager: nil,
      fitness_server: nil,
      evolution_task: nil,
      status: :idle,
      generation: 0,
      best_fitness: 0.0,
      best_network_file: nil,
      stats: %{
        avg_fitness_history: [],
        best_fitness_history: [],
        species_count_history: []
      },
      callback: nil
    }}
  end
  
  @impl true
  def handle_cast({:start_evolution, generations, callback}, state) do
    if state.status != :running do
      # Get references to other processes
      population_manager = Process.whereis(PopulationManager)
      fitness_server = Process.whereis(FitnessEvaluationServer)
      
      # Start evolution in a separate task
      task = Task.async(fn -> 
        run_evolution(population_manager, fitness_server, generations, callback) 
      end)
      
      {:noreply, %{state | 
        population_manager: population_manager,
        fitness_server: fitness_server,
        evolution_task: task,
        status: :running,
        callback: callback
      }}
    else
      # Already running
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast(:stop_evolution, state) do
    if state.status == :running do
      # Stop evolution task if running
      if state.evolution_task && Process.alive?(state.evolution_task.pid) do
        Task.shutdown(state.evolution_task, :brutal_kill)
      end
      
      {:noreply, %{state | status: :idle, evolution_task: nil}}
    else
      # Not running
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end
  
  @impl true
  def handle_call(:get_statistics, _from, state) do
    # Get current statistics
    stats = if state.population_manager do
      PopulationManager.get_statistics(state.population_manager)
    else
      state.stats
    end
    
    {:reply, stats, %{state | stats: stats}}
  end
  
  @impl true
  def handle_call(:get_best_network, _from, state) do
    # Get best network
    {best_file, best_fitness} = if state.population_manager do
      PopulationManager.get_best_network(state.population_manager)
    else
      {state.best_network_file, state.best_fitness}
    end
    
    {:reply, {best_file, best_fitness}, state}
  end
  
  @impl true
  def handle_info({:evolution_progress, generation, best_fitness, stats}, state) do
    # Update progress information
    updated_state = %{state | 
      generation: generation,
      best_fitness: max(state.best_fitness, best_fitness),
      stats: Map.merge(state.stats, stats)
    }
    
    # Call callback if provided
    if state.callback do
      state.callback.(generation, best_fitness, stats)
    end
    
    {:noreply, updated_state}
  end
  
  @impl true
  def handle_info({:evolution_completed, best_network_file, best_fitness}, state) do
    Logger.info("Evolution completed. Best fitness: #{best_fitness}")
    Logger.info("Best network saved to: #{best_network_file}")
    
    # Update final state
    updated_state = %{state | 
      status: :completed, 
      evolution_task: nil,
      best_network_file: best_network_file,
      best_fitness: best_fitness
    }
    
    # Call callback with final results if provided
    if state.callback do
      state.callback.(:completed, best_fitness, updated_state.stats)
    end
    
    {:noreply, updated_state}
  end
  
  # Private helper functions
  
  defp run_evolution(population_manager, fitness_server, generations, callback) do
    # Run the evolution for the specified number of generations
    Enum.reduce(1..generations, {0, 0.0}, fn gen, {_current_gen, best_fitness} ->
      # Generate next generation
      :ok = PopulationManager.next_generation(population_manager)
      
      # Evaluate fitness
      :ok = FitnessEvaluationServer.evaluate_population(fitness_server, population_manager)
      
      # Get stats
      stats = PopulationManager.get_statistics(population_manager)
      current_best = stats.current_best_fitness
      
      # Send progress update
      send(self(), {:evolution_progress, gen, current_best, stats})
      
      # Return updated state for next iteration
      {gen, max(best_fitness, current_best)}
    end)
    
    # Complete evolution
    {best_file, final_fitness} = PopulationManager.get_best_network(population_manager)
    send(self(), {:evolution_completed, best_file, final_fitness})
  end
end

defmodule Automaton.Types.TWEANN.Evolution.FitnessEvaluationServer do
  @moduledoc """
  Server for parallel fitness evaluation of neural networks.
  
  This server coordinates the evaluation of neural networks by:
  - Distributing evaluation work across multiple processes
  - Caching training data for evaluation
  - Collecting and aggregating evaluation results
  """
  
  use GenServer
  alias Automaton.Types.TWEANN.Evolution.PopulationManager
  alias Automata.Reasoning.Cognitive.NeuroIntegration.FitnessEvaluators.PerceptionFitnessEvaluator
  
  require Logger
  
  defstruct [
    :config,
    :training_data,
    :evaluator,
    :concurrent_evaluations
  ]
  
  # Client API
  
  @doc """
  Starts the fitness evaluation server.
  
  ## Parameters
  - config: Configuration for fitness evaluation
  - opts: GenServer options
  
  ## Returns
  {:ok, pid} on success, {:error, reason} on failure
  """
  def start_link(config, opts \\ []) do
    GenServer.start_link(__MODULE__, config, opts)
  end
  
  @doc """
  Evaluates the fitness of all genotypes in a population.
  
  ## Parameters
  - server: PID of the fitness evaluation server
  - population_manager: PID of the population manager
  
  ## Returns
  :ok on success
  """
  def evaluate_population(server, population_manager) do
    GenServer.call(server, {:evaluate_population, population_manager}, :infinity)
  end
  
  @doc """
  Adds training data for fitness evaluation.
  
  ## Parameters
  - server: PID of the fitness evaluation server
  - training_data: Data for fitness evaluation
  
  ## Returns
  :ok on success
  """
  def add_training_data(server, training_data) do
    GenServer.cast(server, {:add_training_data, training_data})
  end
  
  @doc """
  Clears the training data cache.
  
  ## Parameters
  - server: PID of the fitness evaluation server
  
  ## Returns
  :ok on success
  """
  def clear_training_data(server) do
    GenServer.cast(server, :clear_training_data)
  end
  
  # Server callbacks
  
  @impl true
  def init(config) do
    # Determine reasonable concurrency level
    concurrency = System.schedulers_online()
    
    {:ok, %__MODULE__{
      config: config,
      training_data: [],
      evaluator: config.fitness_evaluator || PerceptionFitnessEvaluator,
      concurrent_evaluations: concurrency
    }}
  end
  
  @impl true
  def handle_call({:evaluate_population, population_manager}, _from, state) do
    # Get genotypes to evaluate
    genotypes = PopulationManager.get_unevaluated_genotypes(population_manager)
    
    if length(genotypes) > 0 do
      Logger.info("Evaluating #{length(genotypes)} genotypes with #{state.concurrent_evaluations} workers")
      
      # Evaluate in parallel
      results = evaluate_genotypes_parallel(
        genotypes, 
        state.evaluator, 
        state.training_data, 
        state.concurrent_evaluations
      )
      
      # Update population with results
      :ok = PopulationManager.update_fitness(population_manager, results)
      
      {:reply, :ok, state}
    else
      # No genotypes to evaluate
      {:reply, :ok, state}
    end
  end
  
  @impl true
  def handle_cast({:add_training_data, training_data}, state) do
    # Add to training data cache
    updated_training_data = state.training_data ++ training_data
    
    # Limit cache size if configured
    limited_data = if state.config.max_training_cache do
      recent = Enum.take(updated_training_data, -state.config.max_training_cache)
      if length(recent) < state.config.max_training_cache do
        updated_training_data
      else
        recent
      end
    else
      updated_training_data
    end
    
    {:noreply, %{state | training_data: limited_data}}
  end
  
  @impl true
  def handle_cast(:clear_training_data, state) do
    {:noreply, %{state | training_data: []}}
  end
  
  # Private helper functions
  
  defp evaluate_genotypes_parallel(genotypes, evaluator, training_data, concurrency) do
    # Split into chunks for parallel evaluation
    chunk_size = max(1, div(length(genotypes), concurrency))
    chunks = Enum.chunk_every(genotypes, chunk_size)
    
    # Create tasks for each chunk
    tasks = Enum.map(chunks, fn chunk ->
      Task.async(fn ->
        evaluate_chunk(chunk, evaluator, training_data)
      end)
    end)
    
    # Await results and flatten
    results = Task.await_many(tasks, :infinity)
    List.flatten(results)
  end
  
  defp evaluate_chunk(genotypes, evaluator, training_data) do
    # Evaluate each genotype in the chunk
    Enum.map(genotypes, fn genotype ->
      fitness = apply(evaluator, :evaluate_genotype, [genotype, training_data])
      {genotype.id, fitness}
    end)
  end
end