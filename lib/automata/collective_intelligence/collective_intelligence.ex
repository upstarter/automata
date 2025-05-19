defmodule Automata.CollectiveIntelligence do
  @moduledoc """
  Main entry point for the Collective Intelligence mechanisms.
  
  This module integrates all components of the Collective Intelligence framework:
  - Multi-Level Knowledge Synthesis (implemented)
  - Collaborative Decision Processes (implemented)
  - Distributed Problem Solving (implemented)
  
  The Collective Intelligence framework provides mechanisms for distributed agents
  to collaboratively synthesize knowledge, make decisions, and solve problems.
  """
  
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  alias Automata.CollectiveIntelligence.DecisionProcesses.ProcessManager
  alias Automata.CollectiveIntelligence.DecisionProcesses.DecisionProcess
  alias Automata.CollectiveIntelligence.ProblemSolving.ProblemManager
  alias Automata.CollectiveIntelligence.ProblemSolving.DistributedProblem
  
  @doc """
  Starts the Collective Intelligence system.
  """
  def start_link(opts \\ []) do
    # Start the knowledge system
    {:ok, knowledge_system} = KnowledgeSystem.start_link(
      store_name: Keyword.get(opts, :store_name, KnowledgeSystem.Store),
      auto_synthesis: Keyword.get(opts, :auto_synthesis, true),
      auto_consistency: Keyword.get(opts, :auto_consistency, true),
      synthesis_threshold: Keyword.get(opts, :synthesis_threshold, 10)
    )
    
    # Start the decision processes supervisor
    {:ok, decision_supervisor} = Automata.CollectiveIntelligence.DecisionProcesses.Supervisor.start_link(
      process_manager_name: Keyword.get(opts, :process_manager_name, ProcessManager)
    )
    
    # Start the problem solving supervisor
    {:ok, problem_supervisor} = Automata.CollectiveIntelligence.ProblemSolving.Supervisor.start_link(
      problem_manager_name: Keyword.get(opts, :problem_manager_name, ProblemManager)
    )
    
    # Get references to the managers
    process_manager = Keyword.get(opts, :process_manager_name, ProcessManager)
    problem_manager = Keyword.get(opts, :problem_manager_name, ProblemManager)
    
    # Return a handle to the Collective Intelligence system
    {:ok, %{
      knowledge_system: knowledge_system,
      decision_supervisor: decision_supervisor,
      problem_supervisor: problem_supervisor,
      process_manager: process_manager,
      problem_manager: problem_manager,
      modules: [:knowledge_synthesis, :decision_processes, :problem_solving]
    }}
  end
  
  # Knowledge System facade methods
  
  @doc """
  Creates a new knowledge atom.
  """
  def create_knowledge_atom(content, source, opts \\ []) do
    KnowledgeSystem.create_atom(content, source, opts)
  end
  
  @doc """
  Creates a new knowledge triple.
  """
  def create_knowledge_triple(subject, predicate, object, source, opts \\ []) do
    KnowledgeSystem.create_triple(subject, predicate, object, source, opts)
  end
  
  @doc """
  Creates a new knowledge frame.
  """
  def create_knowledge_frame(name, slots \\ %{}, opts \\ []) do
    KnowledgeSystem.create_frame(name, slots, opts)
  end
  
  @doc """
  Creates a new knowledge graph.
  """
  def create_knowledge_graph(name, opts \\ []) do
    KnowledgeSystem.create_graph(name, opts)
  end
  
  @doc """
  Creates a new hierarchical concept.
  """
  def create_hierarchical_concept(name, description, opts \\ []) do
    KnowledgeSystem.create_concept(name, description, opts)
  end
  
  @doc """
  Retrieves knowledge by ID and type.
  """
  def get_knowledge(id, type) do
    case type do
      :atom -> KnowledgeSystem.get_atom(id)
      :triple -> KnowledgeSystem.get_triple(id)
      :frame -> KnowledgeSystem.get_frame(id)
      :graph -> KnowledgeSystem.get_graph(id)
      :concept -> KnowledgeSystem.get_concept(id)
      _ -> {:error, :invalid_knowledge_type}
    end
  end
  
  @doc """
  Queries the knowledge base for atoms matching criteria.
  """
  def query_knowledge_atoms(criteria) do
    KnowledgeSystem.query_atoms(criteria)
  end
  
  @doc """
  Queries the knowledge base for triples matching criteria.
  """
  def query_knowledge_triples(criteria) do
    KnowledgeSystem.query_triples(criteria)
  end
  
  @doc """
  Performs a graph pattern match query on the knowledge base.
  """
  def query_knowledge_pattern(pattern) do
    KnowledgeSystem.graph_pattern_match(pattern)
  end
  
  @doc """
  Synthesizes higher-level knowledge based on current knowledge base content.
  """
  def synthesize_knowledge(level \\ :all, options \\ []) do
    KnowledgeSystem.synthesize(level, options)
  end
  
  @doc """
  Verifies the consistency of the knowledge base.
  """
  def verify_knowledge_consistency(level \\ :all) do
    KnowledgeSystem.verify_consistency(level)
  end
  
  @doc """
  Identifies contradictions in the knowledge base.
  """
  def identify_knowledge_contradictions do
    KnowledgeSystem.identify_contradictions()
  end
  
  @doc """
  Traverses the concept hierarchy from a starting concept.
  """
  def explore_concept_hierarchy(concept_id, direction \\ :down, max_depth \\ 3) do
    KnowledgeSystem.traverse_concept_hierarchy(concept_id, direction, max_depth)
  end
  
  @doc """
  Extracts a conceptual model from the knowledge base for a specific domain.
  """
  def extract_domain_model(domain_name, options \\ []) do
    KnowledgeSystem.extract_conceptual_model(domain_name, options)
  end
  
  @doc """
  Adds an entity to a knowledge graph.
  """
  def add_entity_to_graph(graph_id, type, properties, opts \\ []) do
    KnowledgeSystem.add_entity_to_graph(graph_id, type, properties, opts)
  end
  
  @doc """
  Adds a relationship to a knowledge graph.
  """
  def add_relationship_to_graph(graph_id, type, from_id, to_id, properties \\ %{}, opts \\ []) do
    KnowledgeSystem.add_relationship_to_graph(graph_id, type, from_id, to_id, properties, opts)
  end
  
  @doc """
  Finds paths between two entities in a knowledge graph.
  """
  def find_graph_paths(graph_id, from_id, to_id, max_depth \\ 3) do
    KnowledgeSystem.find_entity_paths(graph_id, from_id, to_id, max_depth)
  end
  
  # Collaborative Decision Processes
  
  @doc """
  Starts a new collaborative decision process.
  
  ## Parameters
  
  - decision_type: The type of decision process (:consensus, :voting, :argumentation, :preference)
  - config: Configuration for the decision process
  - participants: List of initial participants (optional)
  
  ## Returns
  
  - `{:ok, process_id}` on success
  - `{:error, reason}` on failure
  """
  def start_decision_process(decision_type, config, participants \\ []) when is_map(config) do
    # Create the process
    case ProcessManager.create_process(decision_type, config) do
      {:ok, process_id} ->
        # Register initial participants if provided
        if participants != [] do
          Enum.each(participants, fn {id, params} ->
            DecisionProcess.register_participant(process_id, id, params)
          end)
        end
        
        {:ok, process_id}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Registers a new participant for a decision process.
  
  ## Parameters
  
  - process_id: The ID of the decision process
  - participant_id: The ID of the participant to register
  - params: Additional parameters for the participant (optional)
  
  ## Returns
  
  - `{:ok, :registered}` on success
  - `{:error, reason}` on failure
  """
  def register_decision_participant(process_id, participant_id, params \\ %{}) do
    DecisionProcess.register_participant(process_id, participant_id, params)
  end
  
  @doc """
  Submits input to a decision process.
  
  ## Parameters
  
  - process_id: The ID of the decision process
  - participant_id: The ID of the participant submitting input
  - input: The input data (format depends on decision type)
  
  ## Returns
  
  - `{:ok, :submitted}` on success
  - `{:error, reason}` on failure
  """
  def submit_decision_input(process_id, participant_id, input) do
    DecisionProcess.submit_input(process_id, participant_id, input)
  end
  
  @doc """
  Gets the current status of a decision process.
  
  ## Parameters
  
  - process_id: The ID of the decision process
  
  ## Returns
  
  - `{:ok, state, status_info}` on success
  - `{:error, reason}` on failure
  """
  def get_decision_status(process_id) do
    DecisionProcess.get_status(process_id)
  end
  
  @doc """
  Gets the result of a completed decision process.
  
  ## Parameters
  
  - process_id: The ID of the decision process
  
  ## Returns
  
  - `{:ok, result}` on success
  - `{:error, reason}` on failure
  """
  def get_decision_result(process_id) do
    DecisionProcess.get_result(process_id)
  end
  
  @doc """
  Lists all active decision processes.
  
  ## Returns
  
  - `{:ok, [process_summary]}` on success
  - `{:error, reason}` on failure
  """
  def list_decision_processes do
    ProcessManager.list_processes()
  end
  
  @doc """
  Gets detailed information about a decision process.
  
  ## Parameters
  
  - process_id: The ID of the decision process
  
  ## Returns
  
  - `{:ok, process_info}` on success
  - `{:error, reason}` on failure
  """
  def get_decision_process_info(process_id) do
    ProcessManager.get_process_info(process_id)
  end
  
  @doc """
  Closes a decision process, finalizing its result.
  
  ## Parameters
  
  - process_id: The ID of the decision process
  
  ## Returns
  
  - `{:ok, :closed}` on success
  - `{:error, reason}` on failure
  """
  def close_decision_process(process_id) do
    DecisionProcess.close_process(process_id)
  end
  
  # Distributed Problem Solving
  
  @doc """
  Defines a distributed problem for collaborative solving.
  
  ## Parameters
  
  - problem_type: The type of problem (:optimization, :search, :planning, :constraint_satisfaction, :distributed_computation)
  - config: Configuration for the problem
  - solvers: List of initial solvers (optional)
  
  ## Returns
  
  - `{:ok, problem_id}` on success
  - `{:error, reason}` on failure
  """
  def define_problem(problem_type, config, solvers \\ []) when is_map(config) do
    # Create the problem
    case ProblemManager.create_problem(problem_type, config) do
      {:ok, problem_id} ->
        # Register initial solvers if provided
        if solvers != [] do
          Enum.each(solvers, fn {id, params} ->
            DistributedProblem.register_solver(problem_id, id, params)
          end)
        end
        
        {:ok, problem_id}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Registers a new solver for a distributed problem.
  
  ## Parameters
  
  - problem_id: The ID of the problem
  - solver_id: The ID of the solver to register
  - params: Additional parameters for the solver (optional)
  
  ## Returns
  
  - `{:ok, :registered}` on success
  - `{:error, reason}` on failure
  """
  def register_problem_solver(problem_id, solver_id, params \\ %{}) do
    DistributedProblem.register_solver(problem_id, solver_id, params)
  end
  
  @doc """
  Submits a partial solution to a distributed problem.
  
  ## Parameters
  
  - problem_id: The ID of the problem
  - solver_id: The ID of the solver submitting the solution
  - solution_part: The partial solution data
  
  ## Returns
  
  - `{:ok, :submitted}` on success
  - `{:error, reason}` on failure
  """
  def submit_partial_solution(problem_id, solver_id, solution_part) do
    DistributedProblem.submit_partial_solution(problem_id, solver_id, solution_part)
  end
  
  @doc """
  Gets the current status of a distributed problem.
  
  ## Parameters
  
  - problem_id: The ID of the problem
  
  ## Returns
  
  - `{:ok, state, status_info}` on success
  - `{:error, reason}` on failure
  """
  def get_problem_status(problem_id) do
    DistributedProblem.get_status(problem_id)
  end
  
  @doc """
  Gets the problem definition.
  
  ## Parameters
  
  - problem_id: The ID of the problem
  
  ## Returns
  
  - `{:ok, definition}` on success
  - `{:error, reason}` on failure
  """
  def get_problem_definition(problem_id) do
    DistributedProblem.get_problem_definition(problem_id)
  end
  
  @doc """
  Gets the solution to a completed problem.
  
  ## Parameters
  
  - problem_id: The ID of the problem
  
  ## Returns
  
  - `{:ok, solution}` on success
  - `{:error, reason}` on failure
  """
  def get_problem_solution(problem_id) do
    DistributedProblem.get_solution(problem_id)
  end
  
  @doc """
  Lists all active distributed problems.
  
  ## Returns
  
  - `{:ok, [problem_summary]}` on success
  - `{:error, reason}` on failure
  """
  def list_problems do
    ProblemManager.list_problems()
  end
  
  @doc """
  Gets detailed information about a distributed problem.
  
  ## Parameters
  
  - problem_id: The ID of the problem
  
  ## Returns
  
  - `{:ok, problem_info}` on success
  - `{:error, reason}` on failure
  """
  def get_problem_info(problem_id) do
    ProblemManager.get_problem_info(problem_id)
  end
  
  @doc """
  Filters problems based on criteria.
  
  ## Parameters
  
  - criteria: Map of filter criteria
  
  ## Returns
  
  - `{:ok, [problem_summary]}` on success
  - `{:error, reason}` on failure
  """
  def filter_problems(criteria) do
    ProblemManager.filter_problems(criteria)
  end
  
  @doc """
  Closes a distributed problem.
  
  ## Parameters
  
  - problem_id: The ID of the problem
  
  ## Returns
  
  - `{:ok, :closed}` on success
  - `{:error, reason}` on failure
  """
  def close_problem(problem_id) do
    DistributedProblem.close_problem(problem_id)
  end
end