defmodule Automata.CollectiveIntelligence.ProblemSolving.Search do
  @moduledoc """
  Implements distributed search problem solving.
  
  This module provides mechanisms for solving search problems through
  distributed collaboration, supporting various search strategies such as
  informed search, uninformed search, local search, and adversarial search.
  """
  
  alias Automata.CollectiveIntelligence.ProblemSolving.DistributedProblem
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @behaviour DistributedProblem
  
  @search_strategies [
    :breadth_first,
    :depth_first,
    :a_star,
    :best_first,
    :iterative_deepening,
    :bidirectional,
    :monte_carlo_tree_search
  ]
  
  # DistributedProblem callbacks
  
  @impl DistributedProblem
  def initialize(config) do
    # Validate config
    with :ok <- validate_config(config) do
      # Extract problem-specific information
      domain_space = config.domain_space
      
      problem_data = %{
        id: config.id,
        config: config,
        state: :initializing,
        solvers: %{},
        partial_solutions: [],
        best_solution: nil,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        solved_at: nil,
        metadata: %{
          search_strategy: Map.get(config.custom_parameters, :search_strategy, :a_star),
          initial_state: Map.get(config.custom_parameters, :initial_state),
          goal_state: Map.get(config.custom_parameters, :goal_state),
          goal_predicate: Map.get(config.custom_parameters, :goal_predicate),
          heuristic: Map.get(config.custom_parameters, :heuristic),
          explored_states: %{},
          frontier: [],
          path_to_best: [],
          search_stats: %{
            nodes_expanded: 0,
            max_frontier_size: 0,
            search_depth: 0
          },
          algorithm_state: initialize_algorithm_state(config)
        }
      }
      
      # If we have knowledge context, fetch relevant information
      problem_data = 
        if config.knowledge_context do
          enrich_with_knowledge(problem_data, config.knowledge_context)
        else
          problem_data
        end
      
      {:ok, %{problem_data | state: :solving}}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @impl DistributedProblem
  def register_solver(problem_data, solver_id, params) do
    if Map.has_key?(problem_data.solvers, solver_id) do
      {:error, :already_registered}
    else
      if problem_data.state != :solving do
        {:error, :registration_closed}
      else
        # Check if we've reached max solvers
        if problem_data.config.max_solvers != :unlimited &&
           map_size(problem_data.solvers) >= problem_data.config.max_solvers do
          {:error, :max_solvers_reached}
        else
          # Set solver properties based on search strategy
          search_region = assign_search_region(
            Map.get(problem_data.metadata, :search_strategy),
            map_size(problem_data.solvers),
            params
          )
          
          updated_solvers = Map.put(problem_data.solvers, solver_id, %{
            registered_at: DateTime.utc_now(),
            params: params,
            search_region: search_region,
            states_explored: 0,
            paths_found: 0,
            best_path: nil
          })
          
          updated_data = %{
            problem_data |
            solvers: updated_solvers,
            updated_at: DateTime.utc_now()
          }
          
          {:ok, updated_data}
        end
      end
    end
  end
  
  @impl DistributedProblem
  def submit_partial_solution(problem_data, solver_id, solution) do
    cond do
      problem_data.state != :solving ->
        {:error, :not_solving}
        
      not Map.has_key?(problem_data.solvers, solver_id) ->
        {:error, :solver_not_registered}
        
      true ->
        # Validate solution format (path or partial exploration)
        with :ok <- validate_solution_format(solution, problem_data) do
          case solution.type do
            :path ->
              # Solution is a complete path
              process_path_solution(problem_data, solver_id, solution)
              
            :explored_states ->
              # Solution is a set of explored states
              process_explored_states(problem_data, solver_id, solution)
              
            :frontier_expansion ->
              # Solution is a frontier expansion
              process_frontier_expansion(problem_data, solver_id, solution)
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end
  
  @impl DistributedProblem
  def evaluate_solution(problem_data, solution) do
    # For search problems, evaluation is typically checking if the path is valid
    # and leads to the goal, along with measuring path cost
    
    if solution.type == :path do
      # Check if path is valid
      case validate_path(solution.path, problem_data) do
        :ok ->
          # Calculate path cost
          path_cost = calculate_path_cost(solution.path, problem_data)
          # Check if reaches goal
          reaches_goal = path_reaches_goal?(solution.path, problem_data)
          
          {:ok, path_cost, reaches_goal}
          
        {:error, reason} ->
          {:error, reason}
      end
    else
      # For other solution types, just validate format
      {:ok, nil, true}
    end
  end
  
  @impl DistributedProblem
  def combine_solutions(problem_data, partial_solutions) do
    # For search problems, combining typically means selecting the best path
    # or merging explored state spaces
    
    # Filter for path solutions
    path_solutions = Enum.filter(partial_solutions, fn s -> s.solution.type == :path end)
    
    if Enum.empty?(path_solutions) do
      # No path solutions found, return combined exploration
      combined_exploration = 
        combine_explorations(partial_solutions, problem_data)
        
      {:ok, %{type: :explored_states, states: combined_exploration}}
    else
      # Find the best path solution
      best_path = 
        Enum.min_by(path_solutions, fn s -> 
          s.solution.cost 
        end)
        
      {:ok, best_path.solution}
    end
  end
  
  @impl DistributedProblem
  def check_termination(problem_data) do
    # Check termination conditions
    cond do
      # Check if problem is solved (best solution is a valid path to goal)
      problem_data.best_solution != nil && 
      problem_data.best_solution.type == :path &&
      path_reaches_goal?(problem_data.best_solution.path, problem_data) ->
        {:solved, problem_data, problem_data.best_solution}
      
      # Check if entire search space has been explored without finding solution
      is_search_exhausted?(problem_data) ->
        {:unsolvable, problem_data, :search_space_exhausted}
      
      # Check timeout condition
      has_search_timeout?(problem_data) ->
        if problem_data.best_solution != nil do
          {:solved, problem_data, problem_data.best_solution}
        else
          {:unsolvable, problem_data, :timeout_without_solution}
        end
      
      # Continue searching
      true ->
        {:continue, problem_data}
    end
  end
  
  # Private helpers
  
  defp validate_config(config) do
    # Validate required fields
    required_fields = [:id, :name, :description, :domain_space]
    
    missing_fields = Enum.filter(required_fields, &(not Map.has_key?(config, &1)))
    
    if length(missing_fields) > 0 do
      {:error, {:missing_required_fields, missing_fields}}
    else
      # Validate custom parameters for search
      custom_params = config.custom_parameters || %{}
      
      search_strategy = Map.get(custom_params, :search_strategy, :a_star)
      
      if search_strategy not in @search_strategies do
        {:error, {:invalid_search_strategy, search_strategy, @search_strategies}}
      else
        # Validate initial and goal states
        cond do
          not Map.has_key?(custom_params, :initial_state) ->
            {:error, :missing_initial_state}
            
          not (Map.has_key?(custom_params, :goal_state) || 
               Map.has_key?(custom_params, :goal_predicate)) ->
            {:error, :missing_goal_specification}
            
          search_strategy in [:a_star, :best_first] and 
          not Map.has_key?(custom_params, :heuristic) ->
            {:error, :missing_heuristic_for_informed_search}
            
          true ->
            :ok
        end
      end
    end
  end
  
  defp assign_search_region(search_strategy, existing_solvers_count, params) do
    # Determine how to partition the search space
    case search_strategy do
      :breadth_first ->
        # Assign by depth ranges
        max_depth = Map.get(params, :max_depth, 20)
        depth_per_solver = max(2, div(max_depth, max(1, existing_solvers_count + 1)))
        
        min_depth = existing_solvers_count * depth_per_solver
        max_depth = min_depth + depth_per_solver - 1
        
        %{type: :depth_range, min_depth: min_depth, max_depth: max_depth}
        
      :bidirectional ->
        # First solver searches forward, second backward, others help based on load
        if existing_solvers_count == 0 do
          %{type: :direction, direction: :forward}
        else
          if existing_solvers_count == 1 do
            %{type: :direction, direction: :backward}
          else
            # Balance subsequent solvers
            if rem(existing_solvers_count, 2) == 0 do
              %{type: :direction, direction: :forward}
            else
              %{type: :direction, direction: :backward}
            end
          end
        end
        
      :monte_carlo_tree_search ->
        # Assign different regions of the tree
        %{type: :tree_region, sector: existing_solvers_count}
        
      _ ->
        # For other strategies, assign by state space regions if possible
        Map.get(params, :search_region, %{type: :general})
    end
  end
  
  defp validate_solution_format(solution, problem_data) do
    # Different validation based on solution type
    case solution.type do
      :path ->
        validate_path_solution(solution, problem_data)
        
      :explored_states ->
        validate_explored_states(solution, problem_data)
        
      :frontier_expansion ->
        validate_frontier_expansion(solution, problem_data)
        
      _ ->
        {:error, {:invalid_solution_type, solution.type}}
    end
  end
  
  defp validate_path_solution(solution, problem_data) do
    # Check that solution contains a path
    if not Map.has_key?(solution, :path) do
      {:error, :missing_path}
    else
      # Check that path is a sequence of states
      path = solution.path
      
      if not is_list(path) or Enum.empty?(path) do
        {:error, :invalid_path_format}
      else
        # Check that path starts from initial state
        initial_state = problem_data.metadata.initial_state
        
        if hd(path) != initial_state do
          {:error, :path_does_not_start_from_initial_state}
        else
          # Basic format is valid
          :ok
        end
      end
    end
  end
  
  defp validate_explored_states(solution, problem_data) do
    # Check that solution contains explored states
    if not Map.has_key?(solution, :states) do
      {:error, :missing_explored_states}
    else
      # Check that states are in a valid format (set or map)
      states = solution.states
      
      if not (is_map(states) or is_list(states)) do
        {:error, :invalid_states_format}
      else
        # Basic format is valid
        :ok
      end
    end
  end
  
  defp validate_frontier_expansion(solution, problem_data) do
    # Check that solution contains frontier nodes
    if not Map.has_key?(solution, :frontier_nodes) do
      {:error, :missing_frontier_nodes}
    else
      # Check that frontier nodes are in a valid format
      nodes = solution.frontier_nodes
      
      if not is_list(nodes) do
        {:error, :invalid_frontier_format}
      else
        # Each node should have state and cost
        invalid_nodes = 
          Enum.filter(nodes, fn node ->
            not (is_map(node) and Map.has_key?(node, :state) and Map.has_key?(node, :cost))
          end)
          
        if not Enum.empty?(invalid_nodes) do
          {:error, {:invalid_frontier_nodes, invalid_nodes}}
        else
          # Basic format is valid
          :ok
        end
      end
    end
  end
  
  defp validate_path(path, problem_data) do
    # Check that successive states are valid transitions
    transition_errors = 
      Enum.chunk_every(path, 2, 1, :discard)
      |> Enum.with_index()
      |> Enum.filter(fn {[state1, state2], _idx} ->
        not valid_transition?(state1, state2, problem_data)
      end)
      |> Enum.map(fn {[state1, state2], idx} ->
        "Invalid transition at index #{idx}: #{inspect(state1)} -> #{inspect(state2)}"
      end)
    
    if Enum.empty?(transition_errors) do
      :ok
    else
      {:error, {:invalid_transitions, transition_errors}}
    end
  end
  
  defp valid_transition?(state1, state2, problem_data) do
    # Use transition function from problem config if available
    case problem_data.config.custom_parameters do
      %{transition_function: f} when is_function(f, 2) ->
        # Function takes two states and returns true/false
        f.(state1, state2)
        
      %{successor_function: f} when is_function(f, 1) ->
        # Function takes a state and returns list of valid successor states
        successors = f.(state1)
        Enum.member?(successors, state2)
        
      %{action_space: actions, action_result: result_fn} ->
        # Check if any action leads from state1 to state2
        Enum.any?(actions, fn action ->
          result_fn.(state1, action) == state2
        end)
        
      _ ->
        # Default to always valid if no transition function provided
        # (this relies on external validation)
        true
    end
  end
  
  defp calculate_path_cost(path, problem_data) do
    # Use cost function from problem config
    cost_function = 
      case problem_data.config.custom_parameters do
        %{transition_cost: f} when is_function(f, 2) ->
          # Function takes two states and returns cost
          f
          
        %{path_cost: f} when is_function(f, 1) ->
          # Function takes entire path and returns cost
          fn _state1, _state2 -> 1 end
          
        _ ->
          # Default to unit cost for each step
          fn _state1, _state2 -> 1 end
      end
    
    # Calculate total cost
    Enum.chunk_every(path, 2, 1, :discard)
    |> Enum.reduce(0, fn [state1, state2], acc ->
      acc + cost_function.(state1, state2)
    end)
  end
  
  defp path_reaches_goal?(path, problem_data) do
    # Check if last state in path satisfies goal condition
    last_state = List.last(path)
    
    case problem_data.metadata do
      %{goal_state: goal} when goal != nil ->
        # Direct comparison with goal state
        last_state == goal
        
      %{goal_predicate: pred} when is_function(pred, 1) ->
        # Use predicate function
        pred.(last_state)
        
      _ ->
        # No goal defined
        false
    end
  end
  
  defp process_path_solution(problem_data, solver_id, solution) do
    # Evaluate the path
    case evaluate_solution(problem_data, solution) do
      {:ok, path_cost, reaches_goal} ->
        # Update the solution with cost
        solution_with_cost = Map.put(solution, :cost, path_cost)
        
        # Record the solution
        partial_solution_record = %{
          solver: solver_id,
          solution: solution_with_cost,
          reaches_goal: reaches_goal,
          timestamp: DateTime.utc_now()
        }
        
        updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
        
        # Update solver stats
        updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
          updated_best = 
            if solver.best_path == nil || 
                (reaches_goal && 
                (not Map.get(solver.best_path, :reaches_goal, false) || 
                 path_cost < solver.best_path.cost)) do
              %{path: solution.path, cost: path_cost, reaches_goal: reaches_goal}
            else
              solver.best_path
            end
          
          %{solver |
            paths_found: solver.paths_found + 1,
            best_path: updated_best
          }
        end)
        
        # Update best solution if better
        updated_best_solution = 
          cond do
            # First solution that reaches goal
            reaches_goal && 
            (problem_data.best_solution == nil || 
             not Map.get(problem_data.best_solution, :reaches_goal, false)) ->
              solution_with_cost
              
            # Better solution that reaches goal
            reaches_goal && 
            Map.get(problem_data.best_solution, :reaches_goal, false) &&
            path_cost < problem_data.best_solution.cost ->
              solution_with_cost
              
            # Keep current best
            true ->
              problem_data.best_solution
          end
        
        # Update search statistics
        search_stats = %{
          problem_data.metadata.search_stats |
          search_depth: max(
            problem_data.metadata.search_stats.search_depth,
            length(solution.path) - 1
          )
        }
        
        # Update metadata
        updated_metadata = %{
          problem_data.metadata |
          search_stats: search_stats,
          path_to_best: if(updated_best_solution != problem_data.best_solution, do: solution.path, else: problem_data.metadata.path_to_best)
        }
        
        # Update problem data
        updated_data = %{
          problem_data |
          partial_solutions: updated_partial_solutions,
          solvers: updated_solvers,
          best_solution: updated_best_solution,
          metadata: updated_metadata,
          updated_at: DateTime.utc_now()
        }
        
        {:ok, updated_data}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp process_explored_states(problem_data, solver_id, solution) do
    # Merge explored states with existing ones
    existing_explored = problem_data.metadata.explored_states
    new_explored = solution.states
    
    # Convert to maps with value = true for efficient merging/lookups
    normalized_new = 
      case new_explored do
        states when is_list(states) ->
          Map.new(states, fn state -> {state, true} end)
          
        states when is_map(states) ->
          states
      end
    
    merged_explored = Map.merge(existing_explored, normalized_new)
    
    # Update solver stats
    updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
      %{solver |
        states_explored: solver.states_explored + map_size(normalized_new)
      }
    end)
    
    # Update search statistics
    search_stats = %{
      problem_data.metadata.search_stats |
      nodes_expanded: problem_data.metadata.search_stats.nodes_expanded + map_size(normalized_new)
    }
    
    # Update metadata
    updated_metadata = %{
      problem_data.metadata |
      explored_states: merged_explored,
      search_stats: search_stats
    }
    
    # Record the solution
    partial_solution_record = %{
      solver: solver_id,
      solution: solution,
      states_count: map_size(normalized_new),
      timestamp: DateTime.utc_now()
    }
    
    updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
    
    # Update problem data
    updated_data = %{
      problem_data |
      partial_solutions: updated_partial_solutions,
      solvers: updated_solvers,
      metadata: updated_metadata,
      updated_at: DateTime.utc_now()
    }
    
    {:ok, updated_data}
  end
  
  defp process_frontier_expansion(problem_data, solver_id, solution) do
    # Process new frontier nodes
    frontier_nodes = solution.frontier_nodes
    
    # Merge with existing frontier (depending on search strategy)
    updated_frontier = 
      merge_frontier(
        problem_data.metadata.frontier, 
        frontier_nodes, 
        problem_data.metadata.search_strategy
      )
    
    # Update search statistics
    search_stats = %{
      problem_data.metadata.search_stats |
      max_frontier_size: max(
        problem_data.metadata.search_stats.max_frontier_size,
        length(updated_frontier)
      )
    }
    
    # Update metadata
    updated_metadata = %{
      problem_data.metadata |
      frontier: updated_frontier,
      search_stats: search_stats
    }
    
    # Record the solution
    partial_solution_record = %{
      solver: solver_id,
      solution: solution,
      nodes_count: length(frontier_nodes),
      timestamp: DateTime.utc_now()
    }
    
    updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
    
    # Update problem data
    updated_data = %{
      problem_data |
      partial_solutions: updated_partial_solutions,
      metadata: updated_metadata,
      updated_at: DateTime.utc_now()
    }
    
    {:ok, updated_data}
  end
  
  defp merge_frontier(existing_frontier, new_nodes, search_strategy) do
    # Different merging strategies based on search approach
    case search_strategy do
      :breadth_first ->
        # BFS uses a FIFO queue
        existing_frontier ++ new_nodes
        
      :depth_first ->
        # DFS uses a LIFO stack
        new_nodes ++ existing_frontier
        
      :a_star ->
        # A* sorts by f = g + h
        (existing_frontier ++ new_nodes)
        |> Enum.sort_by(fn node -> node.cost + node.heuristic end)
        
      :best_first ->
        # Best-first sorts by heuristic only
        (existing_frontier ++ new_nodes)
        |> Enum.sort_by(fn node -> node.heuristic end)
        
      _ ->
        # Default strategy
        existing_frontier ++ new_nodes
    end
  end
  
  defp combine_explorations(partial_solutions, problem_data) do
    # Combine all explored states
    Enum.reduce(partial_solutions, %{}, fn solution, acc ->
      case solution.solution do
        %{type: :explored_states, states: states} ->
          # Convert states to normalized format if needed
          normalized = 
            case states do
              s when is_list(s) -> Map.new(s, fn state -> {state, true} end)
              s when is_map(s) -> s
            end
          
          Map.merge(acc, normalized)
          
        _ ->
          acc
      end
    end)
  end
  
  defp is_search_exhausted?(problem_data) do
    # Search is exhausted if frontier is empty and solver frontier expansion queue is empty
    Enum.empty?(problem_data.metadata.frontier) && 
    not Enum.any?(problem_data.partial_solutions, fn sol ->
      sol.solution.type == :frontier_expansion && 
      not Enum.empty?(sol.solution.frontier_nodes)
    end)
  end
  
  defp has_search_timeout?(problem_data) do
    # Check if timeout has occurred
    case problem_data.config.timeout do
      nil ->
        false
        
      timeout when is_integer(timeout) ->
        # Calculate elapsed time
        created = problem_data.created_at
        now = DateTime.utc_now()
        
        diff_ms = DateTime.diff(now, created, :millisecond)
        diff_ms >= timeout
    end
  end
  
  defp initialize_algorithm_state(config) do
    strategy = Map.get(config.custom_parameters, :search_strategy, :a_star)
    
    case strategy do
      :breadth_first ->
        %{
          frontier_type: :queue,
          current_depth: 0,
          max_depth: Map.get(config.custom_parameters, :max_depth)
        }
        
      :depth_first ->
        %{
          frontier_type: :stack,
          current_depth: 0,
          max_depth: Map.get(config.custom_parameters, :max_depth)
        }
        
      :a_star ->
        %{
          frontier_type: :priority_queue,
          heuristic: config.custom_parameters.heuristic,
          open_set: %{},
          closed_set: %{}
        }
        
      :best_first ->
        %{
          frontier_type: :priority_queue,
          heuristic: config.custom_parameters.heuristic,
          open_set: %{},
          closed_set: %{}
        }
        
      :iterative_deepening ->
        %{
          frontier_type: :stack,
          current_depth_limit: 1,
          max_depth: Map.get(config.custom_parameters, :max_depth, 100),
          depth_increment: Map.get(config.custom_parameters, :depth_increment, 1)
        }
        
      :bidirectional ->
        %{
          forward_frontier: [],
          backward_frontier: [],
          forward_explored: %{},
          backward_explored: %{},
          meeting_point: nil
        }
        
      :monte_carlo_tree_search ->
        %{
          root: config.custom_parameters.initial_state,
          tree: %{},
          exploration_constant: Map.get(config.custom_parameters, :exploration_constant, 1.4),
          max_iterations: Map.get(config.custom_parameters, :max_iterations, 1000),
          current_iterations: 0
        }
    end
  end
  
  defp enrich_with_knowledge(problem_data, context_id) do
    # Fetch relevant context from the knowledge system
    case KnowledgeSystem.get_context(context_id) do
      {:ok, context} ->
        # Extract relevant information to enrich the problem
        metadata = Map.put(problem_data.metadata, :knowledge_context, %{
          context_id: context_id,
          relevant_concepts: context.concepts,
          relevant_relations: context.relations
        })
        
        %{problem_data | metadata: metadata}
        
      _ ->
        # Context not found or error, continue without enrichment
        problem_data
    end
  end
end