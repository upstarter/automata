defmodule Automata.CollectiveIntelligence.ProblemSolving.ConstraintSatisfaction do
  @moduledoc """
  Implements distributed constraint satisfaction problem solving.
  
  This module provides mechanisms for solving constraint satisfaction problems (CSPs)
  through distributed collaboration, supporting various CSP techniques such as
  backtracking, constraint propagation, and local search methods.
  """
  
  alias Automata.CollectiveIntelligence.ProblemSolving.DistributedProblem
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @behaviour DistributedProblem
  
  @csp_techniques [
    :backtracking,
    :constraint_propagation,
    :local_search,
    :distributed_breakout,
    :asynchronous_backtracking,
    :arc_consistency
  ]
  
  # DistributedProblem callbacks
  
  @impl DistributedProblem
  def initialize(config) do
    # Validate config
    with :ok <- validate_config(config) do
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
          csp_technique: Map.get(config.custom_parameters, :csp_technique, :backtracking),
          variables: Map.get(config.custom_parameters, :variables, []),
          domains: Map.get(config.custom_parameters, :domains, %{}),
          constraints: Map.get(config.custom_parameters, :constraints, []),
          current_assignments: %{},
          consistent_partial_assignments: [],
          backtrack_count: 0,
          constraint_checks: 0,
          domain_reductions: 0,
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
          # Set solver properties based on CSP technique
          csp_role = determine_csp_role(
            Map.get(problem_data.metadata, :csp_technique),
            map_size(problem_data.solvers),
            problem_data.metadata.variables,
            params
          )
          
          updated_solvers = Map.put(problem_data.solvers, solver_id, %{
            registered_at: DateTime.utc_now(),
            params: params,
            role: csp_role,
            solutions_submitted: 0,
            best_solution: nil,
            constraint_checks: 0
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
        # Validate solution format
        with :ok <- validate_solution_format(solution, problem_data) do
          case solution.type do
            :complete_assignment ->
              # Solution is a complete variable assignment
              process_complete_assignment(problem_data, solver_id, solution)
              
            :partial_assignment ->
              # Solution is a partial variable assignment
              process_partial_assignment(problem_data, solver_id, solution)
              
            :domain_reductions ->
              # Solution contains domain reduction information
              process_domain_reductions(problem_data, solver_id, solution)
              
            :constraint_checks ->
              # Solution contains constraint check results
              process_constraint_checks(problem_data, solver_id, solution)
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end
  
  @impl DistributedProblem
  def evaluate_solution(problem_data, solution) do
    # For CSPs, evaluation is checking if all constraints are satisfied
    
    if solution.type == :complete_assignment do
      # Get the assignment
      assignment = solution.assignment
      
      # Check all constraints
      constraints = problem_data.metadata.constraints
      
      {all_satisfied, constraint_checks} = check_all_constraints(assignment, constraints)
      
      if all_satisfied do
        # For CSPs, there's typically no quality measure - solutions are either valid or not
        # But we can track the number of constraint checks as a performance metric
        {:ok, constraint_checks, true}
      else
        # Solution doesn't satisfy all constraints
        {:ok, constraint_checks, false}
      end
    else
      # For partial assignments, just check consistency
      if solution.type == :partial_assignment do
        assignment = solution.assignment
        constraints = applicable_constraints(assignment, problem_data.metadata.constraints)
        
        {consistent, constraint_checks} = check_all_constraints(assignment, constraints)
        
        {:ok, constraint_checks, consistent}
      else
        # For other solution types, just validate format
        {:ok, nil, true}
      end
    end
  end
  
  @impl DistributedProblem
  def combine_solutions(problem_data, partial_solutions) do
    # For CSPs, combining typically means merging partial assignments
    # if they are compatible
    
    # Filter for complete assignments that satisfy constraints
    complete_solutions = 
      Enum.filter(partial_solutions, fn s -> 
        s.solution.type == :complete_assignment && 
        Map.get(s, :satisfies_constraints, false)
      end)
    
    if not Enum.empty?(complete_solutions) do
      # We have at least one complete solution
      # Simply return the first one (all complete solutions are equally valid in CSPs)
      {:ok, hd(complete_solutions).solution}
    else
      # Try to combine partial assignments
      case combine_partial_assignments(
        Enum.filter(partial_solutions, fn s -> s.solution.type == :partial_assignment end),
        problem_data
      ) do
        {:ok, combined_assignment} ->
          # Check if combined assignment is complete
          if map_size(combined_assignment) == length(problem_data.metadata.variables) do
            {:ok, %{type: :complete_assignment, assignment: combined_assignment}}
          else
            {:ok, %{type: :partial_assignment, assignment: combined_assignment}}
          end
          
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
  
  @impl DistributedProblem
  def check_termination(problem_data) do
    # Check termination conditions
    cond do
      # Check if problem is solved (best solution is a complete assignment that satisfies all constraints)
      problem_data.best_solution != nil && 
      problem_data.best_solution.type == :complete_assignment ->
        {:solved, problem_data, problem_data.best_solution}
      
      # Check timeout condition
      has_csp_timeout?(problem_data) ->
        if problem_data.best_solution != nil do
          {:solved, problem_data, problem_data.best_solution}
        else
          {:unsolvable, problem_data, :timeout_without_solution}
        end
      
      # Check if search is exhausted
      is_csp_search_exhausted?(problem_data) ->
        {:unsolvable, problem_data, :search_space_exhausted}
      
      # Continue solving
      true ->
        {:continue, problem_data}
    end
  end
  
  # Private helpers
  
  defp validate_config(config) do
    # Validate required fields
    required_fields = [:id, :name, :description]
    
    missing_fields = Enum.filter(required_fields, &(not Map.has_key?(config, &1)))
    
    if length(missing_fields) > 0 do
      {:error, {:missing_required_fields, missing_fields}}
    else
      # Validate custom parameters for CSPs
      custom_params = config.custom_parameters || %{}
      
      csp_technique = Map.get(custom_params, :csp_technique, :backtracking)
      
      if csp_technique not in @csp_techniques do
        {:error, {:invalid_csp_technique, csp_technique, @csp_techniques}}
      else
        # Validate variables and domains
        cond do
          not Map.has_key?(custom_params, :variables) or Enum.empty?(custom_params.variables) ->
            {:error, :missing_variables}
            
          not Map.has_key?(custom_params, :domains) or map_size(custom_params.domains) == 0 ->
            {:error, :missing_domains}
            
          not Map.has_key?(custom_params, :constraints) or Enum.empty?(custom_params.constraints) ->
            {:error, :missing_constraints}
            
          true ->
            # Check that all variables have domains
            vars_without_domains = 
              Enum.filter(custom_params.variables, fn var ->
                not Map.has_key?(custom_params.domains, var)
              end)
              
            if not Enum.empty?(vars_without_domains) do
              {:error, {:variables_without_domains, vars_without_domains}}
            else
              :ok
            end
        end
      end
    end
  end
  
  defp determine_csp_role(csp_technique, existing_solvers_count, variables, params) do
    case csp_technique do
      :asynchronous_backtracking ->
        # Assign variables to different solvers
        var_count = length(variables)
        vars_per_solver = max(1, div(var_count, max(1, existing_solvers_count + 1)))
        
        start_idx = existing_solvers_count * vars_per_solver
        end_idx = min(var_count - 1, start_idx + vars_per_solver - 1)
        
        assigned_vars = 
          if start_idx < var_count do
            Enum.slice(variables, start_idx, vars_per_solver)
          else
            []
          end
        
        %{type: :variable_owner, variables: assigned_vars}
        
      :distributed_breakout ->
        # Each solver manages different constraints
        constraints = Map.get(params, :constraints, [])
        
        %{type: :constraint_manager, constraints: constraints}
        
      :arc_consistency ->
        # Each solver handles arc consistency for different variable pairs
        var_pairs = 
          if Map.has_key?(params, :var_pairs) do
            params.var_pairs
          else
            []
          end
          
        %{type: :arc_manager, var_pairs: var_pairs}
        
      _ ->
        # For other techniques, assign by search region
        search_region = Map.get(params, :search_region, %{type: :general})
        
        %{type: :general_solver, search_region: search_region}
    end
  end
  
  defp validate_solution_format(solution, problem_data) do
    # Different validation based on solution type
    case solution.type do
      :complete_assignment ->
        validate_assignment(solution.assignment, problem_data, true)
        
      :partial_assignment ->
        validate_assignment(solution.assignment, problem_data, false)
        
      :domain_reductions ->
        validate_domain_reductions(solution.reductions, problem_data)
        
      :constraint_checks ->
        validate_constraint_checks(solution.checks, problem_data)
        
      _ ->
        {:error, {:invalid_solution_type, solution.type}}
    end
  end
  
  defp validate_assignment(assignment, problem_data, complete) do
    # Check that all assigned variables are valid
    variables = problem_data.metadata.variables
    domains = problem_data.metadata.domains
    
    # Check for invalid variables
    invalid_vars = 
      Enum.filter(Map.keys(assignment), fn var ->
        not Enum.member?(variables, var)
      end)
      
    if not Enum.empty?(invalid_vars) do
      {:error, {:invalid_variables, invalid_vars}}
    else
      # Check for out-of-domain values
      out_of_domain = 
        Enum.filter(assignment, fn {var, value} ->
          not Enum.member?(domains[var], value)
        end)
      
      if not Enum.empty?(out_of_domain) do
        {:error, {:values_out_of_domain, out_of_domain}}
      else
        # If complete, check that all variables are assigned
        if complete and length(variables) != map_size(assignment) do
          missing_vars = variables -- Map.keys(assignment)
          {:error, {:incomplete_assignment, missing_vars}}
        else
          :ok
        end
      end
    end
  end
  
  defp validate_domain_reductions(reductions, problem_data) do
    # Check that domain reductions are valid
    variables = problem_data.metadata.variables
    domains = problem_data.metadata.domains
    
    # Check for invalid variables
    invalid_vars = 
      Enum.filter(Map.keys(reductions), fn var ->
        not Enum.member?(variables, var)
      end)
      
    if not Enum.empty?(invalid_vars) do
      {:error, {:invalid_variables, invalid_vars}}
    else
      # Check that reduced domains are subsets of original domains
      invalid_reductions = 
        Enum.filter(reductions, fn {var, reduced_domain} ->
          not Enum.all?(reduced_domain, fn value ->
            Enum.member?(domains[var], value)
          end)
        end)
      
      if not Enum.empty?(invalid_reductions) do
        {:error, {:invalid_domain_reductions, invalid_reductions}}
      else
        :ok
      end
    end
  end
  
  defp validate_constraint_checks(checks, problem_data) do
    # Check that constraint checks are valid
    constraints = problem_data.metadata.constraints
    
    # Check for invalid constraints
    invalid_constraints = 
      Enum.filter(checks, fn check ->
        not Enum.any?(constraints, fn constraint ->
          constraint_id(constraint) == check.constraint_id
        end)
      end)
      
    if not Enum.empty?(invalid_constraints) do
      {:error, {:invalid_constraints, invalid_constraints}}
    else
      :ok
    end
  end
  
  defp constraint_id(constraint) do
    # Generate a unique ID for a constraint
    case constraint do
      %{id: id} -> id
      %{name: name} -> name
      {vars, _} when is_list(vars) -> vars
      _ -> inspect(constraint)
    end
  end
  
  defp check_all_constraints(assignment, constraints) do
    # Check if all applicable constraints are satisfied
    constraint_checks = 0
    
    result = 
      Enum.reduce_while(constraints, {true, constraint_checks}, fn constraint, {_, checks} ->
        # Check if constraint is applicable to current assignment
        if constraint_applicable?(constraint, assignment) do
          # Check if constraint is satisfied
          {satisfied, new_checks} = constraint_satisfied?(constraint, assignment, checks)
          
          if satisfied do
            {:cont, {true, new_checks}}
          else
            {:halt, {false, new_checks}}
          end
        else
          # Constraint not applicable to current assignment
          {:cont, {true, checks}}
        end
      end)
      
    result
  end
  
  defp constraint_applicable?(constraint, assignment) do
    # Check if all variables in constraint are assigned
    vars = constraint_variables(constraint)
    Enum.all?(vars, fn var -> Map.has_key?(assignment, var) end)
  end
  
  defp constraint_variables(constraint) do
    # Extract variables involved in a constraint
    case constraint do
      %{variables: vars} -> vars
      %{vars: vars} -> vars
      {vars, _} when is_list(vars) -> vars
      {var1, var2, _} -> [var1, var2]
      _ -> []
    end
  end
  
  defp constraint_satisfied?(constraint, assignment, checks_count) do
    # Check if constraint is satisfied by current assignment
    checks_count = checks_count + 1
    
    case constraint do
      %{predicate: pred} when is_function(pred, 1) ->
        # Predicate takes the assignment as input
        {pred.(assignment), checks_count}
        
      %{predicate: pred} when is_function(pred) ->
        # Extract values for variables in constraint
        vars = constraint_variables(constraint)
        values = Enum.map(vars, fn var -> assignment[var] end)
        
        # Apply predicate to values
        {apply(pred, values), checks_count}
        
      {vars, pred} when is_list(vars) and is_function(pred) ->
        # Extract values for variables
        values = Enum.map(vars, fn var -> assignment[var] end)
        
        # Apply predicate to values
        {apply(pred, values), checks_count}
        
      {var1, var2, rel} when is_atom(rel) ->
        # Binary constraint with relation
        val1 = assignment[var1]
        val2 = assignment[var2]
        
        result = 
          case rel do
            :eq -> val1 == val2
            :neq -> val1 != val2
            :lt -> val1 < val2
            :lte -> val1 <= val2
            :gt -> val1 > val2
            :gte -> val1 >= val2
            _ -> false
          end
          
        {result, checks_count}
        
      _other ->
        # Unknown constraint format, considered satisfied
        {true, checks_count}
    end
  end
  
  defp applicable_constraints(assignment, constraints) do
    # Get constraints that are applicable to the current partial assignment
    assigned_vars = Map.keys(assignment)
    
    Enum.filter(constraints, fn constraint ->
      constraint_vars = constraint_variables(constraint)
      # Constraint is applicable if all its variables are assigned
      Enum.all?(constraint_vars, fn var -> Enum.member?(assigned_vars, var) end)
    end)
  end
  
  defp process_complete_assignment(problem_data, solver_id, solution) do
    # Evaluate the assignment
    case evaluate_solution(problem_data, solution) do
      {:ok, constraint_checks, satisfies_constraints} ->
        # Record the solution
        partial_solution_record = %{
          solver: solver_id,
          solution: solution,
          satisfies_constraints: satisfies_constraints,
          constraint_checks: constraint_checks,
          timestamp: DateTime.utc_now()
        }
        
        updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
        
        # Update solver stats
        updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
          %{solver |
            solutions_submitted: solver.solutions_submitted + 1,
            constraint_checks: solver.constraint_checks + constraint_checks,
            best_solution: 
              if satisfies_constraints and solver.best_solution == nil do
                solution
              else
                solver.best_solution
              end
          }
        end)
        
        # Update best solution if this is valid
        updated_best_solution = 
          if satisfies_constraints and problem_data.best_solution == nil do
            solution
          else
            problem_data.best_solution
          end
        
        # Update overall constraint checks count
        updated_metadata = %{
          problem_data.metadata |
          constraint_checks: problem_data.metadata.constraint_checks + constraint_checks
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
  
  defp process_partial_assignment(problem_data, solver_id, solution) do
    # Evaluate the partial assignment
    case evaluate_solution(problem_data, solution) do
      {:ok, constraint_checks, is_consistent} ->
        # Record the solution
        partial_solution_record = %{
          solver: solver_id,
          solution: solution,
          is_consistent: is_consistent,
          constraint_checks: constraint_checks,
          timestamp: DateTime.utc_now()
        }
        
        updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
        
        # Update solver stats
        updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
          %{solver |
            solutions_submitted: solver.solutions_submitted + 1,
            constraint_checks: solver.constraint_checks + constraint_checks
          }
        end)
        
        # Update consistent partial assignments if this one is consistent
        updated_consistent_assignments = 
          if is_consistent do
            [solution.assignment | problem_data.metadata.consistent_partial_assignments]
          else
            problem_data.metadata.consistent_partial_assignments
          end
        
        # Update overall constraint checks count
        updated_metadata = %{
          problem_data.metadata |
          constraint_checks: problem_data.metadata.constraint_checks + constraint_checks,
          consistent_partial_assignments: updated_consistent_assignments
        }
        
        # Update problem data
        updated_data = %{
          problem_data |
          partial_solutions: updated_partial_solutions,
          solvers: updated_solvers,
          metadata: updated_metadata,
          updated_at: DateTime.utc_now()
        }
        
        {:ok, updated_data}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp process_domain_reductions(problem_data, solver_id, solution) do
    # Process domain reductions
    reductions = solution.reductions
    
    # Record the solution
    partial_solution_record = %{
      solver: solver_id,
      solution: solution,
      timestamp: DateTime.utc_now()
    }
    
    updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
    
    # Update current domains
    current_domains = problem_data.metadata.domains
    
    updated_domains = 
      Enum.reduce(reductions, current_domains, fn {var, reduced_domain}, acc_domains ->
        # Intersect with current domain
        current_domain = acc_domains[var]
        new_domain = Enum.filter(current_domain, fn value -> value in reduced_domain end)
        
        Map.put(acc_domains, var, new_domain)
      end)
    
    # Update domain reduction count
    reduction_count = 
      Enum.sum(
        Enum.map(reductions, fn {var, reduced_domain} ->
          length(current_domains[var]) - length(reduced_domain)
        end)
      )
    
    # Update metadata
    updated_metadata = %{
      problem_data.metadata |
      domains: updated_domains,
      domain_reductions: problem_data.metadata.domain_reductions + reduction_count
    }
    
    # Update problem data
    updated_data = %{
      problem_data |
      partial_solutions: updated_partial_solutions,
      metadata: updated_metadata,
      updated_at: DateTime.utc_now()
    }
    
    {:ok, updated_data}
  end
  
  defp process_constraint_checks(problem_data, solver_id, solution) do
    # Process constraint check results
    checks = solution.checks
    
    # Record the solution
    partial_solution_record = %{
      solver: solver_id,
      solution: solution,
      timestamp: DateTime.utc_now()
    }
    
    updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
    
    # Update metadata
    updated_metadata = %{
      problem_data.metadata |
      constraint_checks: problem_data.metadata.constraint_checks + length(checks)
    }
    
    # Update solver stats
    updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
      %{solver |
        solutions_submitted: solver.solutions_submitted + 1,
        constraint_checks: solver.constraint_checks + length(checks)
      }
    end)
    
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
  
  defp combine_partial_assignments(partial_solutions, problem_data) do
    # Extract assignments from solutions
    assignments = 
      Enum.map(partial_solutions, fn solution ->
        solution.solution.assignment
      end)
    
    # Check if we have any to combine
    if Enum.empty?(assignments) do
      {:ok, %{}}
    else
      # Try to combine compatible assignments
      combined = 
        Enum.reduce_while(assignments, %{}, fn assignment, acc ->
          # Check if new assignment is compatible with accumulated one
          if assignments_compatible?(acc, assignment) do
            # Merge assignments
            {:cont, Map.merge(acc, assignment)}
          else
            # Incompatible, try another combination
            {:halt, :incompatible}
          end
        end)
      
      case combined do
        :incompatible ->
          # Try to find max compatible subset
          max_compatible = find_max_compatible_subset(assignments, problem_data)
          
          if not Enum.empty?(max_compatible) do
            {:ok, max_compatible}
          else
            {:error, :no_compatible_assignments}
          end
          
        combined_assignment ->
          {:ok, combined_assignment}
      end
    end
  end
  
  defp assignments_compatible?(assignment1, assignment2) do
    # Check if two assignments are compatible (no conflicting values)
    # Get common variables
    common_vars = Map.keys(assignment1) -- (Map.keys(assignment1) -- Map.keys(assignment2))
    
    # Check that they have same values for common variables
    Enum.all?(common_vars, fn var ->
      assignment1[var] == assignment2[var]
    end)
  end
  
  defp find_max_compatible_subset(assignments, problem_data) do
    # Find largest subset of compatible assignments
    # This is a greedy approach, not guaranteed to be optimal
    
    # Sort by size descending to prioritize larger assignments
    sorted = Enum.sort_by(assignments, &map_size/1, :desc)
    
    # Start with first assignment
    case sorted do
      [] -> %{}
      [first | rest] ->
        Enum.reduce(rest, first, fn assignment, acc ->
          if assignments_compatible?(acc, assignment) do
            Map.merge(acc, assignment)
          else
            acc
          end
        end)
    end
  end
  
  defp has_csp_timeout?(problem_data) do
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
  
  defp is_csp_search_exhausted?(problem_data) do
    # Check if search space is exhausted
    # This is a simplified check based on backtrack count
    technique = problem_data.metadata.csp_technique
    
    case technique do
      :backtracking ->
        # Estimate search space size
        search_space_size = calculate_search_space_size(problem_data)
        
        # Check if we've done enough backtracking to consider exhausted
        problem_data.metadata.backtrack_count >= search_space_size
        
      _ ->
        # For other techniques, check other metrics
        max_iterations = get_max_iterations(problem_data)
        
        problem_data.metadata.constraint_checks >= max_iterations
    end
  end
  
  defp calculate_search_space_size(problem_data) do
    # Estimate size of search space
    domains = problem_data.metadata.domains
    variables = problem_data.metadata.variables
    
    # Product of domain sizes
    Enum.reduce(variables, 1, fn var, acc ->
      acc * length(domains[var])
    end)
  end
  
  defp get_max_iterations(problem_data) do
    # Get maximum iterations to consider
    case problem_data.config.custom_parameters do
      %{max_iterations: max} when is_integer(max) ->
        max
        
      _ ->
        # Default value based on problem size
        variables = problem_data.metadata.variables
        domains = problem_data.metadata.domains
        
        # Estimate search space size and set a reasonable limit
        search_space = calculate_search_space_size(problem_data)
        min(search_space, 10_000)
    end
  end
  
  defp initialize_algorithm_state(config) do
    technique = Map.get(config.custom_parameters, :csp_technique, :backtracking)
    
    case technique do
      :backtracking ->
        %{
          current_assignment: %{},
          domains: config.custom_parameters.domains,
          backtrack_count: 0,
          variable_ordering: Map.get(config.custom_parameters, :variable_ordering, :static)
        }
        
      :constraint_propagation ->
        %{
          current_assignment: %{},
          domains: config.custom_parameters.domains,
          propagation_queue: [],
          inference_technique: Map.get(config.custom_parameters, :inference_technique, :ac3)
        }
        
      :local_search ->
        %{
          current_assignment: initialize_random_assignment(
            config.custom_parameters.variables,
            config.custom_parameters.domains
          ),
          temperature: Map.get(config.custom_parameters, :initial_temperature, 1.0),
          cooling_rate: Map.get(config.custom_parameters, :cooling_rate, 0.99),
          current_conflicts: 0,
          iteration: 0
        }
        
      :distributed_breakout ->
        %{
          current_assignment: initialize_random_assignment(
            config.custom_parameters.variables,
            config.custom_parameters.domains
          ),
          constraint_weights: initialize_constraint_weights(config.custom_parameters.constraints),
          current_conflicts: 0,
          improvement_opportunities: %{},
          iteration: 0
        }
        
      :asynchronous_backtracking ->
        %{
          agent_view: %{},
          current_value: nil,
          nogood_store: %{},
          higher_priority_agents: [],
          lower_priority_agents: []
        }
        
      :arc_consistency ->
        %{
          domains: config.custom_parameters.domains,
          revisions_done: %{},
          arc_queue: initialize_arc_queue(
            config.custom_parameters.variables,
            config.custom_parameters.constraints
          ),
          consistent: true
        }
    end
  end
  
  defp initialize_random_assignment(variables, domains) do
    # Initialize a random assignment for local search
    Enum.reduce(variables, %{}, fn var, acc ->
      domain = domains[var]
      random_value = Enum.random(domain)
      Map.put(acc, var, random_value)
    end)
  end
  
  defp initialize_constraint_weights(constraints) do
    # Initialize weights for distributed breakout
    Enum.reduce(constraints, %{}, fn constraint, acc ->
      Map.put(acc, constraint_id(constraint), 1)
    end)
  end
  
  defp initialize_arc_queue(variables, constraints) do
    # Initialize queue of arcs for arc consistency
    arcs = []
    
    Enum.reduce(constraints, arcs, fn constraint, acc ->
      vars = constraint_variables(constraint)
      
      # For each pair of variables in constraint, add both directions
      pairs = 
        for v1 <- vars, v2 <- vars, v1 != v2 do
          {v1, v2}
        end
        
      acc ++ pairs
    end)
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