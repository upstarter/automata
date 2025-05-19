defmodule Automata.CollectiveIntelligence.ProblemSolving.Planning do
  @moduledoc """
  Implements distributed planning problem solving.
  
  This module provides mechanisms for solving planning problems through
  distributed collaboration, supporting various planning approaches such as
  classical planning, hierarchical task networks, temporal planning, and
  contingent planning.
  """
  
  alias Automata.CollectiveIntelligence.ProblemSolving.DistributedProblem
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @behaviour DistributedProblem
  
  @planning_approaches [
    :classical,
    :hierarchical,
    :temporal,
    :contingent,
    :probabilistic,
    :continuous
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
          planning_approach: Map.get(config.custom_parameters, :planning_approach, :classical),
          initial_state: Map.get(config.custom_parameters, :initial_state),
          goal_specification: Map.get(config.custom_parameters, :goal_specification),
          actions: Map.get(config.custom_parameters, :actions, []),
          constraints: Map.get(config.custom_parameters, :constraints, []),
          partial_plans: [],
          candidate_plans: [],
          planning_stats: %{
            actions_evaluated: 0,
            max_plan_length: 0,
            candidate_plans_generated: 0
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
          # Set solver properties based on planning approach
          planning_role = determine_planning_role(
            Map.get(problem_data.metadata, :planning_approach),
            map_size(problem_data.solvers),
            params
          )
          
          updated_solvers = Map.put(problem_data.solvers, solver_id, %{
            registered_at: DateTime.utc_now(),
            params: params,
            role: planning_role,
            plans_submitted: 0,
            best_plan: nil
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
        # Validate solution format (plan, partial plan, or action evaluation)
        with :ok <- validate_solution_format(solution, problem_data) do
          case solution.type do
            :complete_plan ->
              # Solution is a complete plan
              process_complete_plan(problem_data, solver_id, solution)
              
            :partial_plan ->
              # Solution is a partial plan
              process_partial_plan(problem_data, solver_id, solution)
              
            :action_evaluations ->
              # Solution contains action evaluation results
              process_action_evaluations(problem_data, solver_id, solution)
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end
  
  @impl DistributedProblem
  def evaluate_solution(problem_data, solution) do
    # For planning problems, evaluation is typically checking if the plan is valid
    # and achieves the goal, along with measuring plan quality
    
    if solution.type == :complete_plan do
      # Check if plan is valid
      case validate_plan(solution.plan, problem_data) do
        :ok ->
          # Calculate plan quality
          plan_quality = calculate_plan_quality(solution.plan, problem_data)
          # Check if achieves goal
          achieves_goal = plan_achieves_goal?(solution.plan, problem_data)
          
          {:ok, plan_quality, achieves_goal}
          
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
    # For planning problems, combining typically means selecting the best plan
    # or merging partial plans
    
    # Filter for complete plan solutions
    plan_solutions = Enum.filter(partial_solutions, fn s -> 
      s.solution.type == :complete_plan 
    end)
    
    if Enum.empty?(plan_solutions) do
      # Try to combine partial plans
      combined_plan = 
        combine_partial_plans(
          Enum.filter(partial_solutions, fn s -> s.solution.type == :partial_plan end),
          problem_data
        )
        
      if combined_plan != nil do
        {:ok, %{type: :complete_plan, plan: combined_plan}}
      else
        # No complete plan created
        {:error, :unable_to_combine_partial_plans}
      end
    else
      # Find the best complete plan
      best_plan = 
        Enum.min_by(plan_solutions, fn s -> 
          s.solution.quality || Float.max_value()
        end)
        
      {:ok, best_plan.solution}
    end
  end
  
  @impl DistributedProblem
  def check_termination(problem_data) do
    # Check termination conditions
    cond do
      # Check if problem is solved (best solution is a valid plan)
      problem_data.best_solution != nil && 
      problem_data.best_solution.type == :complete_plan &&
      plan_achieves_goal?(problem_data.best_solution.plan, problem_data) ->
        {:solved, problem_data, problem_data.best_solution}
      
      # Check timeout condition
      has_planning_timeout?(problem_data) ->
        if problem_data.best_solution != nil do
          {:solved, problem_data, problem_data.best_solution}
        else
          {:unsolvable, problem_data, :timeout_without_solution}
        end
      
      # Check if planning space exhausted
      is_planning_exhausted?(problem_data) ->
        {:unsolvable, problem_data, :planning_space_exhausted}
      
      # Continue planning
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
      # Validate custom parameters for planning
      custom_params = config.custom_parameters || %{}
      
      planning_approach = Map.get(custom_params, :planning_approach, :classical)
      
      if planning_approach not in @planning_approaches do
        {:error, {:invalid_planning_approach, planning_approach, @planning_approaches}}
      else
        # Validate initial state and goal
        cond do
          not Map.has_key?(custom_params, :initial_state) ->
            {:error, :missing_initial_state}
            
          not Map.has_key?(custom_params, :goal_specification) ->
            {:error, :missing_goal_specification}
            
          not Map.has_key?(custom_params, :actions) or Enum.empty?(custom_params.actions) ->
            {:error, :missing_actions}
            
          planning_approach == :temporal and not Map.has_key?(custom_params, :durations) ->
            {:error, :missing_durations_for_temporal_planning}
            
          planning_approach == :probabilistic and not Map.has_key?(custom_params, :probabilities) ->
            {:error, :missing_probabilities_for_probabilistic_planning}
            
          planning_approach == :hierarchical and not Map.has_key?(custom_params, :task_network) ->
            {:error, :missing_task_network_for_hierarchical_planning}
            
          true ->
            :ok
        end
      end
    end
  end
  
  defp determine_planning_role(planning_approach, existing_solvers_count, params) do
    case planning_approach do
      :hierarchical ->
        # Assign different roles for hierarchical planning
        roles = [:task_decomposer, :constraint_checker, :plan_validator]
        role_idx = rem(existing_solvers_count, length(roles))
        Enum.at(roles, role_idx)
        
      :temporal ->
        # First solver handles temporal constraints
        if existing_solvers_count == 0 do
          :temporal_scheduler
        else
          :action_sequencer
        end
        
      :contingent ->
        # Different roles for contingent planning
        if existing_solvers_count == 0 do
          :uncertainty_analyzer
        else
          :policy_generator
        end
        
      :probabilistic ->
        # Different roles for probabilistic planning
        if existing_solvers_count == 0 do
          :probability_estimator
        else
          :expected_utility_calculator
        end
        
      _ ->
        # Default role based on params or standard planner
        Map.get(params, :role, :standard_planner)
    end
  end
  
  defp validate_solution_format(solution, problem_data) do
    # Different validation based on solution type
    case solution.type do
      :complete_plan ->
        validate_complete_plan(solution, problem_data)
        
      :partial_plan ->
        validate_partial_plan(solution, problem_data)
        
      :action_evaluations ->
        validate_action_evaluations(solution, problem_data)
        
      _ ->
        {:error, {:invalid_solution_type, solution.type}}
    end
  end
  
  defp validate_complete_plan(solution, problem_data) do
    # Check that solution contains a plan
    if not Map.has_key?(solution, :plan) do
      {:error, :missing_plan}
    else
      # Check that plan is a sequence of actions
      plan = solution.plan
      
      if not is_list(plan) then
        {:error, :invalid_plan_format}
      else
        # Check that actions in plan are valid
        invalid_actions = 
          Enum.filter(plan, fn action ->
            not is_valid_action?(action, problem_data.metadata.actions)
          end)
          
        if not Enum.empty?(invalid_actions) do
          {:error, {:invalid_actions_in_plan, invalid_actions}}
        else
          # Basic format is valid
          :ok
        end
      end
    end
  end
  
  defp validate_partial_plan(solution, problem_data) do
    # Check that solution contains a partial plan
    if not Map.has_key?(solution, :partial_plan) do
      {:error, :missing_partial_plan}
    else
      partial_plan = solution.partial_plan
      
      # Check that partial plan has required elements
      required_keys = [:actions, :orderings, :causal_links]
      
      missing_keys = Enum.filter(required_keys, &(not Map.has_key?(partial_plan, &1)))
      
      if not Enum.empty?(missing_keys) do
        {:error, {:missing_partial_plan_elements, missing_keys}}
      else
        # Check that actions are valid
        invalid_actions = 
          Enum.filter(partial_plan.actions, fn action ->
            not is_valid_action?(action, problem_data.metadata.actions)
          end)
          
        if not Enum.empty?(invalid_actions) do
          {:error, {:invalid_actions_in_partial_plan, invalid_actions}}
        else
          # Basic format is valid
          :ok
        end
      end
    end
  end
  
  defp validate_action_evaluations(solution, problem_data) do
    # Check that solution contains action evaluations
    if not Map.has_key?(solution, :evaluations) do
      {:error, :missing_evaluations}
    else
      evaluations = solution.evaluations
      
      if not is_list(evaluations) do
        {:error, :invalid_evaluations_format}
      else
        # Check that evaluations reference valid actions
        invalid_evaluations = 
          Enum.filter(evaluations, fn eval ->
            not is_map(eval) or 
            not Map.has_key?(eval, :action) or
            not Map.has_key?(eval, :state) or
            not Map.has_key?(eval, :applicable) or
            not is_valid_action?(eval.action, problem_data.metadata.actions)
          end)
          
        if not Enum.empty?(invalid_evaluations) do
          {:error, {:invalid_evaluations, invalid_evaluations}}
        else
          # Basic format is valid
          :ok
        end
      end
    end
  end
  
  defp is_valid_action?(action, available_actions) do
    # Check if action is in the list of available actions
    # This is a simple name-based check; real systems would be more complex
    action_name = extract_action_name(action)
    
    Enum.any?(available_actions, fn avail_action ->
      extract_action_name(avail_action) == action_name
    end)
  end
  
  defp extract_action_name(action) do
    case action do
      %{name: name} -> name
      %{action: name} when is_binary(name) or is_atom(name) -> name
      {name, _params} when is_binary(name) or is_atom(name) -> name
      name when is_binary(name) or is_atom(name) -> name
      _ -> nil
    end
  end
  
  defp validate_plan(plan, problem_data) do
    # Execute plan from initial state to check if it's valid
    initial_state = problem_data.metadata.initial_state
    
    # Get action model (effects function)
    action_model = get_action_model(problem_data)
    
    # Apply each action in sequence
    execution_result = 
      Enum.reduce_while(plan, {:ok, initial_state}, fn action, {:ok, current_state} ->
        # Check if action is applicable
        if is_applicable?(action, current_state, problem_data) do
          # Apply action effects
          next_state = action_model.(action, current_state)
          {:cont, {:ok, next_state}}
        else
          # Action not applicable in current state
          {:halt, {:error, {:action_not_applicable, action, current_state}}}
        end
      end)
    
    case execution_result do
      {:ok, _final_state} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp is_applicable?(action, state, problem_data) do
    # Get precondition checker
    precondition_checker = get_precondition_checker(problem_data)
    
    # Check if action is applicable in current state
    precondition_checker.(action, state)
  end
  
  defp get_precondition_checker(problem_data) do
    # Extract precondition function from problem configuration
    case problem_data.config.custom_parameters do
      %{precondition_checker: f} when is_function(f, 2) ->
        f
        
      %{actions: actions} ->
        # Create checker from action definitions
        fn action, state ->
          # Find matching action
          action_name = extract_action_name(action)
          
          action_def = Enum.find(actions, fn act ->
            extract_action_name(act) == action_name
          end)
          
          case action_def do
            %{preconditions: preconditions} ->
              check_conditions(preconditions, state, action)
              
            %{pre: pre} ->
              check_conditions(pre, state, action)
              
            _ ->
              # No preconditions specified, assume always applicable
              true
          end
        end
        
      _ ->
        # Default checker always returns true
        fn _action, _state -> true end
    end
  end
  
  defp get_action_model(problem_data) do
    # Extract effects function from problem configuration
    case problem_data.config.custom_parameters do
      %{effects_function: f} when is_function(f, 2) ->
        f
        
      %{action_model: f} when is_function(f, 2) ->
        f
        
      %{actions: actions} ->
        # Create model from action definitions
        fn action, state ->
          # Find matching action
          action_name = extract_action_name(action)
          
          action_def = Enum.find(actions, fn act ->
            extract_action_name(act) == action_name
          end)
          
          case action_def do
            %{effects: effects} ->
              apply_effects(effects, state, action)
              
            %{post: post} ->
              apply_effects(post, state, action)
              
            _ ->
              # No effects specified, state unchanged
              state
          end
        end
        
      _ ->
        # Default model returns unchanged state
        fn _action, state -> state end
    end
  end
  
  defp check_conditions(conditions, state, action) do
    # Different formats of conditions
    case conditions do
      f when is_function(f, 2) ->
        # Function takes state and action, returns boolean
        f.(state, action)
        
      f when is_function(f, 1) ->
        # Function takes state, returns boolean
        f.(state)
        
      list when is_list(list) ->
        # List of atomic conditions, all must be true
        Enum.all?(list, fn condition ->
          check_atomic_condition(condition, state, action)
        end)
        
      map when is_map(map) ->
        # Map of state variables that must match
        Enum.all?(map, fn {key, value} ->
          Map.get(state, key) == value
        end)
        
      _ ->
        # Unrecognized format, assume true
        true
    end
  end
  
  defp check_atomic_condition(condition, state, action) do
    case condition do
      {:eq, var, value} ->
        # Check if variable equals value
        Map.get(state, var) == value
        
      {:neq, var, value} ->
        # Check if variable not equals value
        Map.get(state, var) != value
        
      {:gt, var, value} ->
        # Check if variable greater than value
        Map.get(state, var) > value
        
      {:lt, var, value} ->
        # Check if variable less than value
        Map.get(state, var) < value
        
      {:in, var, values} when is_list(values) ->
        # Check if variable is in list
        Enum.member?(values, Map.get(state, var))
        
      {:has, var} ->
        # Check if variable exists
        Map.has_key?(state, var)
        
      {:not, subcond} ->
        # Negation
        not check_atomic_condition(subcond, state, action)
        
      {:and, conds} when is_list(conds) ->
        # Conjunction
        Enum.all?(conds, &check_atomic_condition(&1, state, action))
        
      {:or, conds} when is_list(conds) ->
        # Disjunction
        Enum.any?(conds, &check_atomic_condition(&1, state, action))
        
      _ when is_function(condition, 1) ->
        # Function that takes state
        condition.(state)
        
      _ when is_function(condition, 2) ->
        # Function that takes state and action
        condition.(state, action)
        
      _ ->
        # Unrecognized format, assume true
        true
    end
  end
  
  defp apply_effects(effects, state, action) do
    # Different formats of effects
    case effects do
      f when is_function(f, 2) ->
        # Function takes state and action, returns new state
        f.(state, action)
        
      f when is_function(f, 1) ->
        # Function takes state, returns new state
        f.(state)
        
      list when is_list(list) ->
        # List of atomic effects, applied in sequence
        Enum.reduce(list, state, fn effect, current_state ->
          apply_atomic_effect(effect, current_state, action)
        end)
        
      map when is_map(map) ->
        # Map of state variable assignments
        Map.merge(state, map)
        
      _ ->
        # Unrecognized format, state unchanged
        state
    end
  end
  
  defp apply_atomic_effect(effect, state, action) do
    case effect do
      {:set, var, value} ->
        # Set variable to value
        Map.put(state, var, value)
        
      {:inc, var, amount} ->
        # Increment variable by amount
        Map.update(state, var, amount, &(&1 + amount))
        
      {:dec, var, amount} ->
        # Decrement variable by amount
        Map.update(state, var, -amount, &(&1 - amount))
        
      {:mult, var, factor} ->
        # Multiply variable by factor
        Map.update(state, var, factor, &(&1 * factor))
        
      {:div, var, divisor} ->
        # Divide variable by divisor
        Map.update(state, var, 1, &(&1 / divisor))
        
      {:remove, var} ->
        # Remove variable
        Map.delete(state, var)
        
      {:apply, f} when is_function(f, 1) ->
        # Apply function to state
        f.(state)
        
      {:apply, f} when is_function(f, 2) ->
        # Apply function to state and action
        f.(state, action)
        
      _ ->
        # Unrecognized format, state unchanged
        state
    end
  end
  
  defp calculate_plan_quality(plan, problem_data) do
    # Measure plan quality (typically a cost function)
    case problem_data.config.custom_parameters do
      %{plan_cost: f} when is_function(f, 1) ->
        # Function that calculates cost for entire plan
        f.(plan)
        
      %{action_cost: f} when is_function(f, 1) ->
        # Function that calculates cost per action
        Enum.reduce(plan, 0, fn action, acc -> acc + f.(action) end)
        
      _ ->
        # Default: use plan length as cost
        length(plan)
    end
  end
  
  defp plan_achieves_goal?(plan, problem_data) do
    # Check if executing the plan achieves the goal
    
    # Get initial state and apply plan
    initial_state = problem_data.metadata.initial_state
    action_model = get_action_model(problem_data)
    
    # Apply each action in sequence
    final_state = 
      Enum.reduce_while(plan, initial_state, fn action, current_state ->
        if is_applicable?(action, current_state, problem_data) do
          next_state = action_model.(action, current_state)
          {:cont, next_state}
        else
          {:halt, current_state}
        end
      end)
    
    # Check if goal is satisfied in final state
    goal_checker = get_goal_checker(problem_data)
    goal_checker.(final_state)
  end
  
  defp get_goal_checker(problem_data) do
    # Extract goal checking function
    case problem_data.metadata do
      %{goal_specification: f} when is_function(f, 1) ->
        # Direct function
        f
        
      %{goal_specification: conditions} ->
        # Create checker from conditions
        fn state -> check_conditions(conditions, state, nil) end
        
      _ ->
        # Default always returns false
        fn _state -> false end
    end
  end
  
  defp process_complete_plan(problem_data, solver_id, solution) do
    # Evaluate the plan
    case evaluate_solution(problem_data, solution) do
      {:ok, plan_quality, achieves_goal} ->
        # Update the solution with quality
        solution_with_quality = Map.put(solution, :quality, plan_quality)
        
        # Record the solution
        partial_solution_record = %{
          solver: solver_id,
          solution: solution_with_quality,
          achieves_goal: achieves_goal,
          timestamp: DateTime.utc_now()
        }
        
        updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
        
        # Update candidate plans
        updated_candidate_plans = 
          if achieves_goal do
            [solution_with_quality | problem_data.metadata.candidate_plans]
          else
            problem_data.metadata.candidate_plans
          end
        
        # Update solver stats
        updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
          updated_best = 
            if solver.best_plan == nil || 
                (achieves_goal && 
                (not Map.get(solver.best_plan, :achieves_goal, false) || 
                 plan_quality < solver.best_plan.quality)) do
              %{plan: solution.plan, quality: plan_quality, achieves_goal: achieves_goal}
            else
              solver.best_plan
            end
          
          %{solver |
            plans_submitted: solver.plans_submitted + 1,
            best_plan: updated_best
          }
        end)
        
        # Update best solution if better
        updated_best_solution = 
          cond do
            # First solution that achieves goal
            achieves_goal && 
            (problem_data.best_solution == nil || 
             not Map.get(problem_data.best_solution, :achieves_goal, false)) ->
              solution_with_quality
              
            # Better solution that achieves goal
            achieves_goal && 
            Map.get(problem_data.best_solution, :achieves_goal, false) &&
            plan_quality < problem_data.best_solution.quality ->
              solution_with_quality
              
            # Keep current best
            true ->
              problem_data.best_solution
          end
        
        # Update planning statistics
        planning_stats = %{
          problem_data.metadata.planning_stats |
          max_plan_length: max(
            problem_data.metadata.planning_stats.max_plan_length,
            length(solution.plan)
          ),
          candidate_plans_generated: problem_data.metadata.planning_stats.candidate_plans_generated + 1
        }
        
        # Update metadata
        updated_metadata = %{
          problem_data.metadata |
          planning_stats: planning_stats,
          candidate_plans: updated_candidate_plans
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
  
  defp process_partial_plan(problem_data, solver_id, solution) do
    # Store the partial plan
    partial_plan = solution.partial_plan
    
    # Record the solution
    partial_solution_record = %{
      solver: solver_id,
      solution: solution,
      timestamp: DateTime.utc_now()
    }
    
    updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
    
    # Update partial plans in metadata
    updated_partial_plans = [partial_plan | problem_data.metadata.partial_plans]
    
    # Update solver stats
    updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
      %{solver | plans_submitted: solver.plans_submitted + 1}
    end)
    
    # Update metadata
    updated_metadata = %{
      problem_data.metadata |
      partial_plans: updated_partial_plans
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
  end
  
  defp process_action_evaluations(problem_data, solver_id, solution) do
    # Store the action evaluations
    evaluations = solution.evaluations
    
    # Record the solution
    partial_solution_record = %{
      solver: solver_id,
      solution: solution,
      timestamp: DateTime.utc_now()
    }
    
    updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
    
    # Update planning statistics
    planning_stats = %{
      problem_data.metadata.planning_stats |
      actions_evaluated: problem_data.metadata.planning_stats.actions_evaluated + length(evaluations)
    }
    
    # Update metadata
    updated_metadata = %{
      problem_data.metadata |
      planning_stats: planning_stats
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
  
  defp combine_partial_plans(partial_solutions, problem_data) do
    # For simplicity, this implementation just takes the most complete partial plan
    # A real implementation would merge partial plans
    
    partial_plans = 
      Enum.map(partial_solutions, fn solution ->
        solution.solution.partial_plan
      end)
    
    if Enum.empty?(partial_plans) do
      nil
    else
      # Find the partial plan with most actions
      most_complete = 
        Enum.max_by(partial_plans, fn plan ->
          length(plan.actions)
        end)
      
      # Try to convert to linear plan if complete
      case linearize_partial_plan(most_complete, problem_data) do
        {:ok, linear_plan} -> linear_plan
        _ -> nil
      end
    end
  end
  
  defp linearize_partial_plan(partial_plan, problem_data) do
    # Check if partial plan has all necessary actions
    goal_checker = get_goal_checker(problem_data)
    initial_state = problem_data.metadata.initial_state
    action_model = get_action_model(problem_data)
    
    # Try to find a valid linearization of the actions
    # This is a simplistic approach - real planners use more sophisticated algorithms
    case topological_sort(partial_plan.actions, partial_plan.orderings) do
      {:ok, ordered_actions} ->
        # Check if this ordering achieves the goal
        final_state = 
          Enum.reduce_while(ordered_actions, initial_state, fn action, current_state ->
            if is_applicable?(action, current_state, problem_data) do
              next_state = action_model.(action, current_state)
              {:cont, next_state}
            else
              {:halt, nil}
            end
          end)
        
        if final_state != nil && goal_checker.(final_state) do
          {:ok, ordered_actions}
        else
          {:error, :linearization_does_not_achieve_goal}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp topological_sort(actions, orderings) do
    # Build a graph from orderings
    graph = 
      Enum.reduce(orderings, %{}, fn {before_action, after_action}, acc ->
        Map.update(acc, before_action, [after_action], fn existing -> [after_action | existing] end)
      end)
    
    # Initialize nodes with no incoming edges
    no_incoming = 
      actions -- Enum.flat_map(orderings, fn {_, after_action} -> [after_action] end)
    
    # Run topological sort
    do_topological_sort(no_incoming, graph, [], MapSet.new(actions))
  end
  
  defp do_topological_sort([], _graph, result, remaining) do
    if MapSet.size(remaining) == 0 do
      {:ok, Enum.reverse(result)}
    else
      {:error, {:cycle_detected, MapSet.to_list(remaining)}}
    end
  end
  
  defp do_topological_sort([node | rest], graph, result, remaining) do
    # Remove node from remaining
    new_remaining = MapSet.delete(remaining, node)
    
    # Find nodes that depend on this one
    dependents = Map.get(graph, node, [])
    
    # Find which of those have no other dependencies
    new_no_incoming = 
      Enum.filter(dependents, fn dependent ->
        not Enum.any?(graph, fn {source, targets} ->
          source != node && Enum.member?(targets, dependent) && MapSet.member?(new_remaining, source)
        end)
      end)
    
    do_topological_sort(rest ++ new_no_incoming, graph, [node | result], new_remaining)
  end
  
  defp has_planning_timeout?(problem_data) do
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
  
  defp is_planning_exhausted?(problem_data) do
    # Check if all possible plans have been explored
    # This is a simplistic approach
    max_iterations = get_max_iterations(problem_data)
    
    problem_data.metadata.planning_stats.candidate_plans_generated >= max_iterations
  end
  
  defp get_max_iterations(problem_data) do
    # Get maximum planning iterations
    case problem_data.config.custom_parameters do
      %{max_iterations: max} when is_integer(max) ->
        max
        
      _ ->
        # Default value
        1000
    end
  end
  
  defp initialize_algorithm_state(config) do
    approach = Map.get(config.custom_parameters, :planning_approach, :classical)
    
    case approach do
      :classical ->
        %{
          planning_graph: %{},
          current_level: 0,
          max_level: Map.get(config.custom_parameters, :max_level, 10),
          heuristic: Map.get(config.custom_parameters, :heuristic)
        }
        
      :hierarchical ->
        %{
          task_network: config.custom_parameters.task_network,
          decomposition_methods: Map.get(config.custom_parameters, :decomposition_methods, %{}),
          current_tasks: [config.custom_parameters.task_network.root_task],
          primitive_tasks: []
        }
        
      :temporal ->
        %{
          timeline: [],
          durations: config.custom_parameters.durations,
          earliest_start_times: %{},
          latest_finish_times: %{},
          current_time: 0,
          scheduling_constraints: Map.get(config.custom_parameters, :scheduling_constraints, [])
        }
        
      :contingent ->
        %{
          belief_states: [config.custom_parameters.initial_state],
          observations: Map.get(config.custom_parameters, :possible_observations, []),
          observation_model: Map.get(config.custom_parameters, :observation_model),
          policy: %{}
        }
        
      :probabilistic ->
        %{
          probabilities: config.custom_parameters.probabilities,
          expected_values: %{},
          discount_factor: Map.get(config.custom_parameters, :discount_factor, 0.9),
          horizon: Map.get(config.custom_parameters, :horizon, 10),
          current_policy: %{}
        }
        
      :continuous ->
        %{
          discretization: Map.get(config.custom_parameters, :discretization, %{}),
          trajectory: [],
          planning_horizon: Map.get(config.custom_parameters, :planning_horizon, 10),
          time_step: Map.get(config.custom_parameters, :time_step, 0.1)
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