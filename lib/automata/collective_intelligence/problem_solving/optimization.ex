defmodule Automata.CollectiveIntelligence.ProblemSolving.Optimization do
  @moduledoc """
  Implements distributed optimization problem solving.
  
  This module provides mechanisms for solving optimization problems through
  distributed collaboration, supporting various optimization methods such as
  gradient-based, evolutionary, swarm-based, and simulated annealing approaches.
  """
  
  alias Automata.CollectiveIntelligence.ProblemSolving.DistributedProblem
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @behaviour DistributedProblem
  
  @optimization_methods [
    :gradient_descent,
    :evolutionary,
    :particle_swarm,
    :simulated_annealing,
    :genetic_algorithm,
    :bayesian_optimization
  ]
  
  # DistributedProblem callbacks
  
  @impl DistributedProblem
  def initialize(config) do
    # Validate config
    with :ok <- validate_config(config) do
      # Extract domain information
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
          optimization_method: Map.get(config.custom_parameters, :optimization_method, :gradient_descent),
          best_objective_value: nil,
          convergence_history: [],
          current_iteration: 0,
          max_iterations: Map.get(config.custom_parameters, :max_iterations, 100),
          domain_bounds: extract_domain_bounds(domain_space),
          constraints_evaluation: %{},
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
          # Set solver properties based on optimization method
          solver_role = determine_solver_role(
            Map.get(problem_data.metadata, :optimization_method),
            map_size(problem_data.solvers),
            params
          )
          
          updated_solvers = Map.put(problem_data.solvers, solver_id, %{
            registered_at: DateTime.utc_now(),
            params: params,
            role: solver_role,
            solutions_submitted: 0,
            best_contribution: nil
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
        with :ok <- validate_solution_format(solution, problem_data.config.domain_space) do
          # Evaluate solution quality
          case evaluate_solution(problem_data, solution) do
            {:ok, objective_value, is_feasible} ->
              if is_feasible do
                # Record the solution
                partial_solution_record = %{
                  solver: solver_id,
                  solution: solution,
                  objective_value: objective_value,
                  timestamp: DateTime.utc_now(),
                  iteration: problem_data.metadata.current_iteration
                }
                
                updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
                
                # Update solver stats
                updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
                  updated_best = 
                    if solver.best_contribution == nil || 
                       better_solution?(objective_value, solver.best_contribution.objective_value, problem_data.config) do
                      %{solution: solution, objective_value: objective_value}
                    else
                      solver.best_contribution
                    end
                  
                  %{solver |
                    solutions_submitted: solver.solutions_submitted + 1,
                    best_contribution: updated_best
                  }
                end)
                
                # Update best solution if better
                {updated_best_solution, updated_best_value} = 
                  case problem_data.best_solution do
                    nil -> 
                      {solution, objective_value}
                      
                    current_best ->
                      current_best_value = problem_data.metadata.best_objective_value
                      
                      if better_solution?(objective_value, current_best_value, problem_data.config) do
                        {solution, objective_value}
                      else
                        {current_best, current_best_value}
                      end
                  end
                
                # Update convergence history
                updated_convergence_history = [
                  %{
                    iteration: problem_data.metadata.current_iteration,
                    best_value: updated_best_value,
                    submitted_by: solver_id,
                    timestamp: DateTime.utc_now()
                  } 
                  | problem_data.metadata.convergence_history
                ]
                
                # Increment iteration counter
                next_iteration = problem_data.metadata.current_iteration + 1
                
                # Update metadata
                updated_metadata = %{
                  problem_data.metadata |
                  best_objective_value: updated_best_value,
                  convergence_history: updated_convergence_history,
                  current_iteration: next_iteration
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
              else
                # Solution is not feasible
                {:error, :solution_not_feasible}
              end
              
            {:error, reason} ->
              {:error, reason}
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end
  
  @impl DistributedProblem
  def evaluate_solution(problem_data, solution) do
    # Check solution against constraints
    constraints_satisfied = check_constraints(problem_data.config.constraints, solution)
    
    if constraints_satisfied do
      # Evaluate objective function
      try do
        objective_value = apply_objective_function(problem_data.config.objective_function, solution)
        {:ok, objective_value, true}
      rescue
        e ->
          {:error, {:objective_function_error, e}}
      end
    else
      {:ok, nil, false}
    end
  end
  
  @impl DistributedProblem
  def combine_solutions(problem_data, partial_solutions) do
    # For optimization problems, the combined solution is typically the best one
    # But some methods require actual combination (like genetic algorithms)
    method = problem_data.metadata.optimization_method
    
    case method do
      :genetic_algorithm ->
        combine_genetic_solutions(partial_solutions, problem_data.config)
        
      :particle_swarm ->
        combine_swarm_solutions(partial_solutions, problem_data.config)
        
      _ ->
        # For most methods, just select the best solution
        sorted_solutions = 
          Enum.sort_by(partial_solutions, fn %{objective_value: value} -> 
            if problem_data.config.custom_parameters.minimize, do: value, else: -value
          end)
        
        best_partial = hd(sorted_solutions)
        {:ok, best_partial.solution}
    end
  end
  
  @impl DistributedProblem
  def check_termination(problem_data) do
    # Check termination conditions
    cond do
      # Check max iterations
      problem_data.metadata.current_iteration >= problem_data.metadata.max_iterations ->
        if problem_data.best_solution != nil do
          {:solved, problem_data, problem_data.best_solution}
        else
          {:unsolvable, problem_data, :max_iterations_reached_without_solution}
        end
      
      # Check convergence criteria if defined
      has_converged?(problem_data) ->
        {:solved, problem_data, problem_data.best_solution}
      
      # Continue solving
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
      # Validate custom parameters for optimization
      custom_params = config.custom_parameters || %{}
      
      optimization_method = Map.get(custom_params, :optimization_method, :gradient_descent)
      
      if optimization_method not in @optimization_methods do
        {:error, {:invalid_optimization_method, optimization_method, @optimization_methods}}
      else
        # Validate objective function
        if not is_function(config.objective_function) do
          {:error, :missing_objective_function}
        else
          # Validate domain space
          if not is_map(config.domain_space) or Enum.empty?(config.domain_space) do
            {:error, :invalid_domain_space}
          else
            # Method-specific validation
            case optimization_method do
              :gradient_descent when not Map.has_key?(custom_params, :learning_rate) ->
                {:error, :missing_learning_rate_for_gradient_descent}
                
              _ ->
                :ok
            end
          end
        end
      end
    end
  end
  
  defp extract_domain_bounds(domain_space) do
    Map.new(domain_space, fn {variable, bounds} ->
      {variable, bounds}
    end)
  end
  
  defp determine_solver_role(optimization_method, existing_solvers_count, params) do
    case optimization_method do
      :evolutionary ->
        # Assign different roles in evolutionary algorithms
        roles = [:explorer, :exploiter, :mutator, :recombinator]
        role_idx = rem(existing_solvers_count, length(roles))
        Enum.at(roles, role_idx)
        
      :particle_swarm ->
        # Special role for first solver as global best keeper
        if existing_solvers_count == 0 do
          :global_best_keeper
        else
          :particle
        end
        
      :genetic_algorithm ->
        # Population manager or individual
        if existing_solvers_count == 0 do
          :population_manager
        else
          :individual
        end
        
      _ ->
        # Default role based on params or standard solver
        Map.get(params, :role, :standard_solver)
    end
  end
  
  defp validate_solution_format(solution, domain_space) do
    # Check if solution contains values for all domain variables
    missing_vars = 
      Map.keys(domain_space)
      |> Enum.filter(fn var -> not Map.has_key?(solution, var) end)
    
    if length(missing_vars) > 0 do
      {:error, {:missing_variables, missing_vars}}
    else
      # Check if values are within bounds
      out_of_bounds = 
        Enum.filter(domain_space, fn {var, bounds} ->
          value = Map.get(solution, var)
          {min_val, max_val} = bounds
          
          value < min_val or value > max_val
        end)
        |> Enum.map(fn {var, _} -> var end)
      
      if length(out_of_bounds) > 0 do
        {:error, {:variables_out_of_bounds, out_of_bounds}}
      else
        :ok
      end
    end
  end
  
  defp check_constraints(constraints, solution) do
    # Check each constraint
    Enum.all?(constraints, fn constraint ->
      check_constraint(constraint, solution)
    end)
  end
  
  defp check_constraint(constraint, solution) do
    case constraint.type do
      :equality ->
        # Equality constraint: lhs == rhs
        evaluate_expression(constraint.lhs, solution) == 
        evaluate_expression(constraint.rhs, solution)
        
      :inequality ->
        # Inequality constraint: lhs <= rhs
        evaluate_expression(constraint.lhs, solution) <= 
        evaluate_expression(constraint.rhs, solution)
        
      :custom ->
        # Custom constraint with a function
        constraint.function.(solution)
    end
  end
  
  defp evaluate_expression(expression, solution) do
    case expression do
      # Variable reference
      {:var, var_name} when is_atom(var_name) or is_binary(var_name) ->
        Map.get(solution, var_name)
        
      # Constant value
      {:const, value} ->
        value
        
      # Simple binary operations
      {:add, lhs, rhs} ->
        evaluate_expression(lhs, solution) + evaluate_expression(rhs, solution)
        
      {:sub, lhs, rhs} ->
        evaluate_expression(lhs, solution) - evaluate_expression(rhs, solution)
        
      {:mul, lhs, rhs} ->
        evaluate_expression(lhs, solution) * evaluate_expression(rhs, solution)
        
      {:div, lhs, rhs} ->
        evaluate_expression(lhs, solution) / evaluate_expression(rhs, solution)
        
      # Advanced operations
      {:pow, base, exp} ->
        :math.pow(evaluate_expression(base, solution), evaluate_expression(exp, solution))
        
      {:sqrt, arg} ->
        :math.sqrt(evaluate_expression(arg, solution))
        
      {:sin, arg} ->
        :math.sin(evaluate_expression(arg, solution))
        
      {:cos, arg} ->
        :math.cos(evaluate_expression(arg, solution))
        
      {:exp, arg} ->
        :math.exp(evaluate_expression(arg, solution))
        
      {:log, arg} ->
        :math.log(evaluate_expression(arg, solution))
        
      # Direct value (number)
      value when is_number(value) ->
        value
        
      # Direct variable reference
      var_name when is_atom(var_name) or is_binary(var_name) ->
        Map.get(solution, var_name)
    end
  end
  
  defp apply_objective_function(objective_function, solution) do
    case objective_function do
      f when is_function(f, 1) ->
        f.(solution)
        
      expr when is_tuple(expr) ->
        # Symbolic expression
        evaluate_expression(expr, solution)
    end
  end
  
  defp better_solution?(new_value, current_value, config) do
    minimize = Map.get(config.custom_parameters, :minimize, true)
    
    if current_value == nil do
      true
    else
      if minimize, do: new_value < current_value, else: new_value > current_value
    end
  end
  
  defp has_converged?(problem_data) do
    convergence_criteria = problem_data.config.convergence_criteria || %{}
    history = problem_data.metadata.convergence_history
    
    cond do
      # Need at least a few iterations to check convergence
      length(history) < 5 ->
        false
        
      # Check absolute tolerance
      absolute_tolerance = Map.get(convergence_criteria, :absolute_tolerance) ->
        check_absolute_convergence(history, absolute_tolerance)
        
      # Check relative tolerance
      relative_tolerance = Map.get(convergence_criteria, :relative_tolerance) ->
        check_relative_convergence(history, relative_tolerance)
        
      # No convergence criteria defined
      true ->
        false
    end
  end
  
  defp check_absolute_convergence(history, tolerance) do
    # Check if the absolute change in objective value is below tolerance
    # over the last few iterations
    [latest | rest] = Enum.take(history, 5)
    
    Enum.all?(rest, fn h ->
      abs(latest.best_value - h.best_value) < tolerance
    end)
  end
  
  defp check_relative_convergence(history, tolerance) do
    # Check if the relative change in objective value is below tolerance
    # over the last few iterations
    [latest | rest] = Enum.take(history, 5)
    
    Enum.all?(rest, fn h ->
      if h.best_value != 0 do
        abs((latest.best_value - h.best_value) / h.best_value) < tolerance
      else
        abs(latest.best_value) < tolerance
      end
    end)
  end
  
  defp combine_genetic_solutions(partial_solutions, config) do
    # Implement genetic algorithm combination
    # Select best individuals based on fitness
    min_or_max = if Map.get(config.custom_parameters, :minimize, true), do: :min, else: :max
    
    # Sort by fitness
    sorted = 
      Enum.sort_by(partial_solutions, fn %{objective_value: value} -> 
        if min_or_max == :min, do: value, else: -value
      end)
    
    # Select top solutions as parents
    parents = Enum.take(sorted, 2)
    
    # Create offspring through crossover
    if length(parents) >= 2 do
      [parent1, parent2] = Enum.take(parents, 2)
      
      # Crossover their solutions
      offspring = crossover_solutions(parent1.solution, parent2.solution)
      
      # Apply mutation
      mutation_rate = Map.get(config.custom_parameters, :mutation_rate, 0.1)
      mutated = mutate_solution(offspring, config.domain_space, mutation_rate)
      
      {:ok, mutated}
    else
      # Not enough parents, return the best solution
      {:ok, hd(sorted).solution}
    end
  end
  
  defp crossover_solutions(solution1, solution2) do
    # Implement single-point crossover
    variables = Map.keys(solution1)
    crossover_point = :rand.uniform(length(variables) - 1)
    
    {vars1, vars2} = Enum.split(variables, crossover_point)
    
    # Create offspring with genes from both parents
    offspring = 
      Enum.reduce(vars1, %{}, fn var, acc ->
        Map.put(acc, var, Map.get(solution1, var))
      end)
      
    Enum.reduce(vars2, offspring, fn var, acc ->
      Map.put(acc, var, Map.get(solution2, var))
    end)
  end
  
  defp mutate_solution(solution, domain_space, mutation_rate) do
    # Implement random mutation
    Enum.reduce(solution, %{}, fn {var, value}, acc ->
      if :rand.uniform() < mutation_rate do
        # Mutate this variable
        {min_val, max_val} = Map.get(domain_space, var)
        new_value = min_val + :rand.uniform() * (max_val - min_val)
        Map.put(acc, var, new_value)
      else
        # Keep the original value
        Map.put(acc, var, value)
      end
    end)
  end
  
  defp combine_swarm_solutions(partial_solutions, config) do
    # Implement particle swarm optimization combination
    # Extract global best from the solutions
    min_or_max = if Map.get(config.custom_parameters, :minimize, true), do: :min, else: :max
    
    # Find the global best solution
    global_best = 
      Enum.min_by(partial_solutions, fn %{objective_value: value} -> 
        if min_or_max == :min, do: value, else: -value
      end)
    
    # PSO doesn't combine solutions; it just tracks global best
    {:ok, global_best.solution}
  end
  
  defp initialize_algorithm_state(config) do
    method = Map.get(config.custom_parameters, :optimization_method, :gradient_descent)
    
    case method do
      :gradient_descent ->
        %{
          learning_rate: Map.get(config.custom_parameters, :learning_rate, 0.01),
          momentum: Map.get(config.custom_parameters, :momentum, 0.9),
          previous_gradients: %{}
        }
        
      :evolutionary ->
        %{
          population_size: Map.get(config.custom_parameters, :population_size, 20),
          mutation_rate: Map.get(config.custom_parameters, :mutation_rate, 0.1),
          crossover_rate: Map.get(config.custom_parameters, :crossover_rate, 0.8),
          population: []
        }
        
      :particle_swarm ->
        %{
          inertia: Map.get(config.custom_parameters, :inertia, 0.7),
          cognitive: Map.get(config.custom_parameters, :cognitive, 1.5),
          social: Map.get(config.custom_parameters, :social, 1.5),
          global_best: nil,
          particle_states: %{}
        }
        
      :simulated_annealing ->
        %{
          initial_temperature: Map.get(config.custom_parameters, :initial_temperature, 100.0),
          cooling_rate: Map.get(config.custom_parameters, :cooling_rate, 0.95),
          current_temperature: Map.get(config.custom_parameters, :initial_temperature, 100.0)
        }
        
      :genetic_algorithm ->
        %{
          population_size: Map.get(config.custom_parameters, :population_size, 20),
          mutation_rate: Map.get(config.custom_parameters, :mutation_rate, 0.1),
          crossover_rate: Map.get(config.custom_parameters, :crossover_rate, 0.8),
          selection_method: Map.get(config.custom_parameters, :selection_method, :tournament),
          elitism_count: Map.get(config.custom_parameters, :elitism_count, 2),
          population: []
        }
        
      :bayesian_optimization ->
        %{
          exploration_weight: Map.get(config.custom_parameters, :exploration_weight, 2.0),
          kernel_lengthscale: Map.get(config.custom_parameters, :kernel_lengthscale, 1.0),
          kernel_variance: Map.get(config.custom_parameters, :kernel_variance, 1.0),
          observation_noise: Map.get(config.custom_parameters, :observation_noise, 0.01),
          samples: []
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