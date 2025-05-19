defmodule Automata.CollectiveIntelligence.ProblemSolving.DistributedProblem do
  @moduledoc """
  Base module for distributed problem-solving processes.
  
  This module defines the core behavior and structure for distributed problem-solving,
  providing a common interface and lifecycle management for different problem types
  including optimization, search, planning, and constraint satisfaction.
  """
  use GenServer
  
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @type problem_id :: String.t()
  @type solver_id :: String.t()
  @type partial_solution :: map()
  @type complete_solution :: map()
  @type problem_state :: :initializing | :solving | :verifying | :solved | :unsolvable | :closed
  @type problem_type :: :optimization | :search | :planning | :constraint_satisfaction | :distributed_computation
  
  @type problem_config :: %{
    id: problem_id(),
    type: problem_type(),
    name: String.t(),
    description: String.t(),
    knowledge_context: KnowledgeSystem.context_id() | nil,
    objective_function: function() | nil,
    constraints: [map()],
    domain_space: map(),
    max_solvers: pos_integer() | :unlimited,
    timeout: pos_integer() | nil,
    convergence_criteria: map(),
    custom_parameters: map()
  }
  
  @type problem_data :: %{
    id: problem_id(),
    config: problem_config(),
    state: problem_state(),
    solvers: %{solver_id() => map()},
    partial_solutions: [%{solver: solver_id(), solution: partial_solution(), timestamp: DateTime.t()}],
    best_solution: complete_solution() | nil,
    created_at: DateTime.t(),
    updated_at: DateTime.t(),
    solved_at: DateTime.t() | nil,
    metadata: map()
  }
  
  @callback initialize(problem_config()) :: {:ok, problem_data()} | {:error, term()}
  @callback register_solver(problem_data(), solver_id(), map()) :: 
    {:ok, problem_data()} | {:error, term()}
  @callback submit_partial_solution(problem_data(), solver_id(), partial_solution()) :: 
    {:ok, problem_data()} | {:error, term()}
  @callback evaluate_solution(problem_data(), partial_solution()) :: 
    {:ok, float(), boolean()} | {:error, term()}
  @callback combine_solutions(problem_data(), [partial_solution()]) :: 
    {:ok, complete_solution()} | {:error, term()}
  @callback check_termination(problem_data()) :: 
    {:continue, problem_data()} | {:solved, problem_data(), complete_solution()} | {:unsolvable, problem_data(), term()}
  
  # GenServer implementation
  
  def start_link(type, config) when type in [:optimization, :search, :planning, :constraint_satisfaction, :distributed_computation] do
    config = Map.put(config, :type, type)
    GenServer.start_link(__MODULE__, config, name: via_tuple(config.id))
  end
  
  def init(config) do
    module = get_implementation_module(config.type)
    
    with {:ok, problem_data} <- module.initialize(config) do
      {:ok, %{
        data: problem_data,
        implementation: module
      }}
    else
      {:error, reason} -> {:stop, reason}
    end
  end
  
  # Client API
  
  @spec register_solver(problem_id(), solver_id(), map()) :: 
    {:ok, :registered} | {:error, term()}
  def register_solver(problem_id, solver_id, params \\ %{}) do
    GenServer.call(via_tuple(problem_id), {:register_solver, solver_id, params})
  end
  
  @spec submit_partial_solution(problem_id(), solver_id(), partial_solution()) ::
    {:ok, :submitted} | {:error, term()}
  def submit_partial_solution(problem_id, solver_id, solution) do
    GenServer.call(via_tuple(problem_id), {:submit_partial_solution, solver_id, solution})
  end
  
  @spec get_status(problem_id()) :: 
    {:ok, problem_state(), map()} | {:error, term()}
  def get_status(problem_id) do
    GenServer.call(via_tuple(problem_id), :get_status)
  end
  
  @spec get_problem_definition(problem_id()) :: 
    {:ok, map()} | {:error, term()}
  def get_problem_definition(problem_id) do
    GenServer.call(via_tuple(problem_id), :get_definition)
  end
  
  @spec get_solution(problem_id()) :: 
    {:ok, complete_solution()} | {:error, term()}
  def get_solution(problem_id) do
    GenServer.call(via_tuple(problem_id), :get_solution)
  end
  
  @spec close_problem(problem_id()) :: 
    {:ok, :closed} | {:error, term()}
  def close_problem(problem_id) do
    GenServer.call(via_tuple(problem_id), :close)
  end
  
  # GenServer callbacks
  
  def handle_call({:register_solver, solver_id, params}, _from, %{data: data, implementation: impl} = state) do
    case impl.register_solver(data, solver_id, params) do
      {:ok, updated_data} ->
        {:reply, {:ok, :registered}, %{state | data: updated_data}}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:submit_partial_solution, solver_id, solution}, _from, %{data: data, implementation: impl} = state) do
    case impl.submit_partial_solution(data, solver_id, solution) do
      {:ok, updated_data} ->
        # Check if we should terminate
        case impl.check_termination(updated_data) do
          {:continue, continue_data} ->
            {:reply, {:ok, :submitted}, %{state | data: continue_data}}
            
          {:solved, solved_data, solution} ->
            final_data = %{
              solved_data |
              state: :solved,
              best_solution: solution,
              solved_at: DateTime.utc_now()
            }
            {:reply, {:ok, :submitted}, %{state | data: final_data}}
            
          {:unsolvable, unsolvable_data, reason} ->
            final_data = %{
              unsolvable_data |
              state: :unsolvable,
              metadata: Map.put(unsolvable_data.metadata, :unsolvable_reason, reason)
            }
            {:reply, {:ok, :submitted}, %{state | data: final_data}}
        end
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call(:get_status, _from, %{data: data} = state) do
    status_info = %{
      id: data.id,
      state: data.state,
      solvers_count: map_size(data.solvers),
      partial_solutions_count: length(data.partial_solutions),
      has_solution: data.best_solution != nil,
      created_at: data.created_at,
      updated_at: data.updated_at,
      solved_at: data.solved_at
    }
    
    {:reply, {:ok, data.state, status_info}, state}
  end
  
  def handle_call(:get_definition, _from, %{data: data} = state) do
    definition = %{
      id: data.id,
      type: data.config.type,
      name: data.config.name,
      description: data.config.description,
      domain_space: data.config.domain_space,
      constraints: data.config.constraints
    }
    
    {:reply, {:ok, definition}, state}
  end
  
  def handle_call(:get_solution, _from, %{data: data} = state) do
    case data.best_solution do
      nil -> {:reply, {:error, :no_solution_available}, state}
      solution -> {:reply, {:ok, solution}, state}
    end
  end
  
  def handle_call(:close, _from, %{data: data} = state) do
    if data.state in [:solved, :unsolvable] do
      updated_data = %{data | state: :closed}
      {:reply, {:ok, :closed}, %{state | data: updated_data}}
    else
      {:reply, {:error, :cannot_close_unsolved_problem}, state}
    end
  end
  
  # Private helpers
  
  defp via_tuple(problem_id) do
    {:via, Registry, {Automata.Registry, {__MODULE__, problem_id}}}
  end
  
  defp get_implementation_module(:optimization),
    do: Automata.CollectiveIntelligence.ProblemSolving.Optimization

  defp get_implementation_module(:search),
    do: Automata.CollectiveIntelligence.ProblemSolving.Search
    
  defp get_implementation_module(:planning),
    do: Automata.CollectiveIntelligence.ProblemSolving.Planning
    
  defp get_implementation_module(:constraint_satisfaction),
    do: Automata.CollectiveIntelligence.ProblemSolving.ConstraintSatisfaction
    
  defp get_implementation_module(:distributed_computation),
    do: Automata.CollectiveIntelligence.ProblemSolving.DistributedComputation
end