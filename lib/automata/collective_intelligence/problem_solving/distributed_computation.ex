defmodule Automata.CollectiveIntelligence.ProblemSolving.DistributedComputation do
  @moduledoc """
  Implements distributed computation for complex problems.
  
  This module provides mechanisms for solving computationally intensive problems
  through distributed processing, supporting various distributed computing paradigms
  such as MapReduce, parallel processing, and grid computing approaches.
  """
  
  alias Automata.CollectiveIntelligence.ProblemSolving.DistributedProblem
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @behaviour DistributedProblem
  
  @computation_paradigms [
    :map_reduce,
    :parallel_processing,
    :actor_model,
    :grid_computing,
    :stream_processing,
    :divide_and_conquer
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
          computation_paradigm: Map.get(config.custom_parameters, :computation_paradigm, :map_reduce),
          input_data: Map.get(config.custom_parameters, :input_data),
          processing_function: Map.get(config.custom_parameters, :processing_function),
          reduction_function: Map.get(config.custom_parameters, :reduction_function),
          partitions: Map.get(config.custom_parameters, :partitions, []),
          processed_partitions: %{},
          intermediate_results: [],
          computation_stats: %{
            tasks_completed: 0,
            data_processed: 0,
            parallel_workers: 0,
            max_memory_used: 0
          },
          algorithm_state: initialize_algorithm_state(config)
        }
      }
      
      # Partition the input data if not already partitioned
      problem_data = 
        if Enum.empty?(problem_data.metadata.partitions) do
          create_partitions(problem_data)
        else
          problem_data
        end
      
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
          # Set solver properties based on computation paradigm
          computation_role = determine_computation_role(
            Map.get(problem_data.metadata, :computation_paradigm),
            map_size(problem_data.solvers),
            params
          )
          
          # Assign partitions to this solver
          assigned_partitions = assign_partitions(
            problem_data.metadata.partitions,
            problem_data.metadata.processed_partitions,
            computation_role
          )
          
          updated_solvers = Map.put(problem_data.solvers, solver_id, %{
            registered_at: DateTime.utc_now(),
            params: params,
            role: computation_role,
            assigned_partitions: assigned_partitions,
            results_submitted: 0,
            data_processed: 0
          })
          
          # Update computation stats
          computation_stats = %{
            problem_data.metadata.computation_stats |
            parallel_workers: map_size(problem_data.solvers) + 1
          }
          
          # Update metadata
          updated_metadata = %{
            problem_data.metadata |
            computation_stats: computation_stats
          }
          
          updated_data = %{
            problem_data |
            solvers: updated_solvers,
            metadata: updated_metadata,
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
            :processed_partition ->
              # Solution is a processed data partition
              process_partition_result(problem_data, solver_id, solution)
              
            :intermediate_result ->
              # Solution is an intermediate computation result
              process_intermediate_result(problem_data, solver_id, solution)
              
            :final_result ->
              # Solution is a complete computation result
              process_final_result(problem_data, solver_id, solution)
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end
  
  @impl DistributedProblem
  def evaluate_solution(problem_data, solution) do
    # For distributed computations, evaluation is typically checking result correctness
    # and measuring performance metrics
    
    case solution.type do
      :final_result ->
        # Verify final result if verification function is provided
        if Map.has_key?(problem_data.config.custom_parameters, :verification_function) do
          verification_fn = problem_data.config.custom_parameters.verification_function
          
          case verification_fn.(solution.result) do
            true ->
              # Calculate quality metrics
              quality = calculate_result_quality(solution.result, problem_data)
              
              {:ok, quality, true}
              
            false ->
              {:ok, nil, false}
              
            {quality, true} ->
              {:ok, quality, true}
              
            {_quality, false} ->
              {:ok, nil, false}
          end
        else
          # No verification function, assume result is correct
          # Use computation time as a quality metric (lower is better)
          quality = 
            if Map.has_key?(solution, :computation_time) do
              solution.computation_time
            else
              # Default quality value
              0
            end
            
          {:ok, quality, true}
        end
        
      _ ->
        # For other solution types, just validate format
        {:ok, nil, true}
    end
  end
  
  @impl DistributedProblem
  def combine_solutions(problem_data, partial_solutions) do
    # For distributed computations, combining typically means aggregating
    # results according to the computation paradigm
    
    paradigm = problem_data.metadata.computation_paradigm
    
    case paradigm do
      :map_reduce ->
        combine_map_reduce_results(partial_solutions, problem_data)
        
      :divide_and_conquer ->
        combine_divide_and_conquer_results(partial_solutions, problem_data)
        
      _ ->
        # For other paradigms, check if we have a final result
        final_solutions = 
          Enum.filter(partial_solutions, fn s -> 
            s.solution.type == :final_result 
          end)
          
        if not Enum.empty?(final_solutions) do
          # Just return the first final result
          {:ok, hd(final_solutions).solution}
        else
          # No final result yet
          {:error, :no_final_result}
        end
    end
  end
  
  @impl DistributedProblem
  def check_termination(problem_data) do
    # Check termination conditions
    cond do
      # Check if problem is solved (best solution is a final result)
      problem_data.best_solution != nil && 
      problem_data.best_solution.type == :final_result ->
        {:solved, problem_data, problem_data.best_solution}
      
      # Check if all partitions are processed and combined
      are_all_partitions_processed?(problem_data) ->
        # If all partitions are processed, try to combine results
        combined_result = combine_all_results(problem_data)
        
        case combined_result do
          {:ok, result} ->
            final_solution = %{
              type: :final_result,
              result: result,
              computation_time: compute_total_time(problem_data)
            }
            
            updated_data = %{problem_data | best_solution: final_solution}
            
            {:solved, updated_data, final_solution}
            
          {:error, _reason} ->
            {:continue, problem_data}
        end
      
      # Check timeout condition
      has_computation_timeout?(problem_data) ->
        if problem_data.best_solution != nil do
          {:solved, problem_data, problem_data.best_solution}
        else
          partial_result = combine_partial_results(problem_data)
          
          case partial_result do
            {:ok, result} ->
              final_solution = %{
                type: :final_result,
                result: result,
                is_partial: true,
                computation_time: compute_total_time(problem_data)
              }
              
              updated_data = %{problem_data | best_solution: final_solution}
              
              {:solved, updated_data, final_solution}
              
            {:error, reason} ->
              {:unsolvable, problem_data, reason}
          end
        end
      
      # Continue computation
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
      # Validate custom parameters for distributed computation
      custom_params = config.custom_parameters || %{}
      
      computation_paradigm = Map.get(custom_params, :computation_paradigm, :map_reduce)
      
      if computation_paradigm not in @computation_paradigms do
        {:error, {:invalid_computation_paradigm, computation_paradigm, @computation_paradigms}}
      else
        # Validate required parameters based on paradigm
        case computation_paradigm do
          :map_reduce ->
            cond do
              not Map.has_key?(custom_params, :input_data) ->
                {:error, :missing_input_data}
                
              not Map.has_key?(custom_params, :processing_function) ->
                {:error, :missing_processing_function}
                
              not Map.has_key?(custom_params, :reduction_function) ->
                {:error, :missing_reduction_function}
                
              true ->
                :ok
            end
            
          :divide_and_conquer ->
            cond do
              not Map.has_key?(custom_params, :input_data) ->
                {:error, :missing_input_data}
                
              not Map.has_key?(custom_params, :processing_function) ->
                {:error, :missing_processing_function}
                
              not Map.has_key?(custom_params, :combine_function) ->
                {:error, :missing_combine_function}
                
              true ->
                :ok
            end
            
          _ ->
            # General validation for other paradigms
            cond do
              not Map.has_key?(custom_params, :input_data) ->
                {:error, :missing_input_data}
                
              not Map.has_key?(custom_params, :processing_function) ->
                {:error, :missing_processing_function}
                
              true ->
                :ok
            end
        end
      end
    end
  end
  
  defp create_partitions(problem_data) do
    # Create partitions of the input data
    input_data = problem_data.metadata.input_data
    paradigm = problem_data.metadata.computation_paradigm
    
    partitions = 
      case paradigm do
        :map_reduce ->
          # For MapReduce, partition data into chunks
          chunk_size = 
            Map.get(
              problem_data.config.custom_parameters,
              :chunk_size,
              default_chunk_size(input_data)
            )
            
          partition_for_map_reduce(input_data, chunk_size)
          
        :divide_and_conquer ->
          # For divide and conquer, create recursive partitions
          divide_function = 
            Map.get(
              problem_data.config.custom_parameters,
              :divide_function,
              &default_divide/1
            )
            
          partition_for_divide_and_conquer(input_data, divide_function)
          
        _ ->
          # Default partitioning strategy
          default_partitioning(input_data)
      end
      
    # Update metadata with partitions
    updated_metadata = %{problem_data.metadata | partitions: partitions}
    
    %{problem_data | metadata: updated_metadata}
  end
  
  defp default_chunk_size(input_data) do
    # Determine default chunk size based on input data size
    cond do
      is_list(input_data) ->
        max(1, div(length(input_data), 10))
        
      is_map(input_data) ->
        max(1, div(map_size(input_data), 10))
        
      is_binary(input_data) ->
        max(1024, div(byte_size(input_data), 10))
        
      true ->
        # Default for unknown data types
        1
    end
  end
  
  defp partition_for_map_reduce(input_data, chunk_size) do
    case input_data do
      data when is_list(data) ->
        # Partition list into chunks
        Enum.chunk_every(data, chunk_size)
        |> Enum.with_index()
        |> Enum.map(fn {chunk, idx} -> 
          %{id: "partition_#{idx}", data: chunk, type: :list_chunk}
        end)
        
      data when is_map(data) ->
        # Partition map into chunks
        Enum.chunk_every(Map.to_list(data), chunk_size)
        |> Enum.with_index()
        |> Enum.map(fn {chunk, idx} -> 
          %{id: "partition_#{idx}", data: Map.new(chunk), type: :map_chunk}
        end)
        
      data when is_binary(data) ->
        # Partition binary into chunks
        0..(div(byte_size(data), chunk_size))
        |> Enum.map(fn i ->
          start_pos = i * chunk_size
          chunk_data = binary_part(data, start_pos, min(chunk_size, byte_size(data) - start_pos))
          %{id: "partition_#{i}", data: chunk_data, type: :binary_chunk}
        end)
        
      data ->
        # Single partition for unknown data types
        [%{id: "partition_0", data: data, type: :single_item}]
    end
  end
  
  defp default_divide(data) do
    # Default divide function for divide-and-conquer
    case data do
      [] -> {[], []}
      [single] -> {[single], []}
      list when is_list(list) ->
        mid = div(length(list), 2)
        {Enum.take(list, mid), Enum.drop(list, mid)}
        
      map when is_map(map) ->
        list = Map.to_list(map)
        mid = div(length(list), 2)
        {Map.new(Enum.take(list, mid)), Map.new(Enum.drop(list, mid))}
        
      bin when is_binary(bin) ->
        mid = div(byte_size(bin), 2)
        {binary_part(bin, 0, mid), binary_part(bin, mid, byte_size(bin) - mid)}
        
      data ->
        # Cannot divide further
        {data, nil}
    end
  end
  
  defp partition_for_divide_and_conquer(data, divide_function, depth \\ 0, max_depth \\ 4, id_prefix \\ "") do
    # Stop dividing at max depth or when data can't be divided further
    if depth >= max_depth or is_nil(data) or (is_list(data) and Enum.empty?(data)) do
      if is_nil(data) or (is_list(data) and Enum.empty?(data)) do
        []
      else
        [%{id: "#{id_prefix}#{depth}", data: data, type: :leaf, depth: depth}]
      end
    else
      # Divide data
      {left, right} = divide_function.(data)
      
      # If division didn't actually split the data, return as leaf
      if right == nil or right == [] or left == right do
        [%{id: "#{id_prefix}#{depth}", data: data, type: :leaf, depth: depth}]
      else
        # Create node and continue dividing
        node = %{id: "#{id_prefix}#{depth}", data: data, type: :internal, depth: depth}
        
        left_partitions = partition_for_divide_and_conquer(
          left, divide_function, depth + 1, max_depth, "#{id_prefix}#{depth}_L"
        )
        
        right_partitions = partition_for_divide_and_conquer(
          right, divide_function, depth + 1, max_depth, "#{id_prefix}#{depth}_R"
        )
        
        [node] ++ left_partitions ++ right_partitions
      end
    end
  end
  
  defp default_partitioning(input_data) do
    # Simple default partitioning for generic data
    cond do
      is_list(input_data) ->
        # Simple split into 10 partitions or fewer
        chunk_size = max(1, div(length(input_data), 10))
        Enum.chunk_every(input_data, chunk_size)
        |> Enum.with_index()
        |> Enum.map(fn {chunk, idx} -> 
          %{id: "partition_#{idx}", data: chunk, type: :default}
        end)
        
      is_map(input_data) ->
        # Split map into 10 partitions or fewer
        chunk_size = max(1, div(map_size(input_data), 10))
        Enum.chunk_every(Map.to_list(input_data), chunk_size)
        |> Enum.with_index()
        |> Enum.map(fn {chunk, idx} -> 
          %{id: "partition_#{idx}", data: Map.new(chunk), type: :default}
        end)
        
      true ->
        # Single partition for other data types
        [%{id: "partition_0", data: input_data, type: :default}]
    end
  end
  
  defp determine_computation_role(paradigm, existing_solvers_count, params) do
    case paradigm do
      :map_reduce ->
        # First solver is reducer, rest are mappers
        if existing_solvers_count == 0 and not Map.get(params, :force_mapper, false) do
          %{type: :reducer}
        else
          %{type: :mapper}
        end
        
      :actor_model ->
        # Different actor roles
        role_type = Map.get(params, :actor_role, :worker)
        
        %{type: role_type}
        
      :stream_processing ->
        # Different stream processing roles
        if existing_solvers_count == 0 and not Map.get(params, :force_processor, false) do
          %{type: :stream_coordinator}
        else
          %{type: :stream_processor}
        end
        
      _ ->
        # Generic worker role for other paradigms
        %{type: :worker}
    end
  end
  
  defp assign_partitions(all_partitions, processed_partitions, role) do
    # Find unprocessed partitions
    unprocessed = 
      Enum.filter(all_partitions, fn partition ->
        not Map.has_key?(processed_partitions, partition.id)
      end)
    
    # Assign based on role
    case role do
      %{type: :mapper} ->
        # Assign a subset of partitions to mapper
        # For simplicity, just assign all unprocessed (in reality would limit)
        unprocessed
        
      %{type: :reducer} ->
        # Reducer doesn't get assigned partitions directly
        []
        
      %{type: :worker} ->
        # Assign a subset of partitions to worker
        unprocessed
        
      _ ->
        # Default assignment
        unprocessed
    end
  end
  
  defp validate_solution_format(solution, problem_data) do
    # Different validation based on solution type
    case solution.type do
      :processed_partition ->
        validate_processed_partition(solution, problem_data)
        
      :intermediate_result ->
        validate_intermediate_result(solution, problem_data)
        
      :final_result ->
        validate_final_result(solution, problem_data)
        
      _ ->
        {:error, {:invalid_solution_type, solution.type}}
    end
  end
  
  defp validate_processed_partition(solution, problem_data) do
    # Check that solution contains partition ID and result
    if not Map.has_key?(solution, :partition_id) do
      {:error, :missing_partition_id}
    else
      if not Map.has_key?(solution, :result) do
        {:error, :missing_result}
      else
        # Check that partition ID is valid
        partition_id = solution.partition_id
        
        if not Enum.any?(problem_data.metadata.partitions, fn p -> p.id == partition_id end) do
          {:error, {:invalid_partition_id, partition_id}}
        else
          :ok
        end
      end
    end
  end
  
  defp validate_intermediate_result(solution, problem_data) do
    # Check that solution contains result data
    if not Map.has_key?(solution, :result) do
      {:error, :missing_result}
    else
      # For intermediate results, we don't need much validation
      :ok
    end
  end
  
  defp validate_final_result(solution, problem_data) do
    # Check that solution contains result data
    if not Map.has_key?(solution, :result) do
      {:error, :missing_result}
    else
      # For final results, we can validate format based on expected output type
      if Map.has_key?(problem_data.config.custom_parameters, :result_validator) do
        validator = problem_data.config.custom_parameters.result_validator
        
        if validator.(solution.result) do
          :ok
        else
          {:error, :invalid_result_format}
        end
      else
        # No specific validator, accept as is
        :ok
      end
    end
  end
  
  defp calculate_result_quality(result, problem_data) do
    # Calculate quality of result based on configured metrics
    if Map.has_key?(problem_data.config.custom_parameters, :quality_function) do
      quality_fn = problem_data.config.custom_parameters.quality_function
      quality_fn.(result)
    else
      # Default quality is computation performance
      stats = problem_data.metadata.computation_stats
      stats.tasks_completed
    end
  end
  
  defp process_partition_result(problem_data, solver_id, solution) do
    # Process a completed partition
    partition_id = solution.partition_id
    result = solution.result
    
    # Record the solution
    partial_solution_record = %{
      solver: solver_id,
      solution: solution,
      timestamp: DateTime.utc_now()
    }
    
    updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
    
    # Update processed partitions
    updated_processed_partitions = 
      Map.put(problem_data.metadata.processed_partitions, partition_id, %{
        result: result,
        processor: solver_id,
        timestamp: DateTime.utc_now()
      })
    
    # Find the partition to get the data size
    partition = 
      Enum.find(problem_data.metadata.partitions, fn p -> p.id == partition_id end)
      
    data_size = measure_data_size(partition.data)
    
    # Update computation stats
    updated_stats = %{
      problem_data.metadata.computation_stats |
      tasks_completed: problem_data.metadata.computation_stats.tasks_completed + 1,
      data_processed: problem_data.metadata.computation_stats.data_processed + data_size
    }
    
    # Update solver stats
    updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
      %{solver |
        results_submitted: solver.results_submitted + 1,
        data_processed: solver.data_processed + data_size
      }
    end)
    
    # Update metadata
    updated_metadata = %{
      problem_data.metadata |
      processed_partitions: updated_processed_partitions,
      computation_stats: updated_stats
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
  
  defp process_intermediate_result(problem_data, solver_id, solution) do
    # Process an intermediate result
    result = solution.result
    
    # Record the solution
    partial_solution_record = %{
      solver: solver_id,
      solution: solution,
      timestamp: DateTime.utc_now()
    }
    
    updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
    
    # Update intermediate results
    updated_intermediate_results = [
      %{
        result: result,
        solver: solver_id,
        timestamp: DateTime.utc_now()
      } 
      | problem_data.metadata.intermediate_results
    ]
    
    # Update solver stats
    updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
      %{solver |
        results_submitted: solver.results_submitted + 1
      }
    end)
    
    # Update metadata
    updated_metadata = %{
      problem_data.metadata |
      intermediate_results: updated_intermediate_results
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
  
  defp process_final_result(problem_data, solver_id, solution) do
    # Process a final result
    result = solution.result
    
    # Evaluate the result
    case evaluate_solution(problem_data, solution) do
      {:ok, quality, is_valid} ->
        # Record the solution
        partial_solution_record = %{
          solver: solver_id,
          solution: solution,
          is_valid: is_valid,
          quality: quality,
          timestamp: DateTime.utc_now()
        }
        
        updated_partial_solutions = [partial_solution_record | problem_data.partial_solutions]
        
        # Update solver stats
        updated_solvers = Map.update!(problem_data.solvers, solver_id, fn solver ->
          %{solver |
            results_submitted: solver.results_submitted + 1
          }
        end)
        
        # Update best solution if this is valid
        updated_best_solution = 
          if is_valid and problem_data.best_solution == nil do
            solution
          else
            problem_data.best_solution
          end
        
        # Update problem data
        updated_data = %{
          problem_data |
          partial_solutions: updated_partial_solutions,
          solvers: updated_solvers,
          best_solution: updated_best_solution,
          updated_at: DateTime.utc_now()
        }
        
        {:ok, updated_data}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp measure_data_size(data) do
    # Approximate data size measurement
    cond do
      is_list(data) -> length(data)
      is_map(data) -> map_size(data)
      is_binary(data) -> byte_size(data)
      is_tuple(data) -> tuple_size(data)
      true -> 1
    end
  end
  
  defp combine_map_reduce_results(partial_solutions, problem_data) do
    # For MapReduce, combine mapper results and apply reducer
    
    # Get mapper results (processed partitions)
    map_results = 
      Enum.filter(partial_solutions, fn solution ->
        solution.solution.type == :processed_partition
      end)
      |> Enum.map(fn solution -> solution.solution.result end)
    
    if Enum.empty?(map_results) do
      {:error, :no_mapper_results}
    else
      # Apply reduce function
      reduce_fn = problem_data.metadata.reduction_function
      
      try do
        reduced_result = reduce_fn.(map_results)
        
        final_solution = %{
          type: :final_result,
          result: reduced_result,
          computation_time: compute_total_time(problem_data)
        }
        
        {:ok, final_solution}
      rescue
        e -> {:error, {:reduction_error, e}}
      end
    end
  end
  
  defp combine_divide_and_conquer_results(partial_solutions, problem_data) do
    # For divide and conquer, combine results according to the problem structure
    
    # Filter for processed partitions
    processed = 
      Enum.filter(partial_solutions, fn solution ->
        solution.solution.type == :processed_partition
      end)
      
    if Enum.empty?(processed) do
      {:error, :no_processed_partitions}
    else
      # Get combine function
      combine_fn = problem_data.config.custom_parameters.combine_function
      
      # Convert to map of partition ID -> result
      results_map = 
        Enum.map(processed, fn solution ->
          {solution.solution.partition_id, solution.solution.result}
        end)
        |> Map.new()
      
      # Find root partition
      root_partition = 
        Enum.find(problem_data.metadata.partitions, fn p -> 
          p.id == "0" or p.depth == 0 
        end)
      
      if root_partition == nil do
        {:error, :cannot_find_root_partition}
      else
        # Start combining from leaf nodes up
        try do
          combined_result = combine_tree_results(
            root_partition, 
            problem_data.metadata.partitions,
            results_map, 
            combine_fn
          )
          
          final_solution = %{
            type: :final_result,
            result: combined_result,
            computation_time: compute_total_time(problem_data)
          }
          
          {:ok, final_solution}
        rescue
          e -> {:error, {:combination_error, e}}
        end
      end
    end
  end
  
  defp combine_tree_results(node, all_partitions, results_map, combine_fn) do
    node_id = node.id
    
    case node.type do
      :leaf ->
        # Leaf node, just return result
        Map.get(results_map, node_id)
        
      :internal ->
        # Internal node, combine child results
        # Find direct children
        left_id = "#{node_id}_L0"
        right_id = "#{node_id}_R0"
        
        left_node = Enum.find(all_partitions, fn p -> p.id == left_id end)
        right_node = Enum.find(all_partitions, fn p -> p.id == right_id end)
        
        if left_node == nil or right_node == nil do
          # Try alternate naming pattern
          left_id = "#{node_id}_L1"
          right_id = "#{node_id}_R1"
          
          left_node = Enum.find(all_partitions, fn p -> p.id == left_id end)
          right_node = Enum.find(all_partitions, fn p -> p.id == right_id end)
        end
        
        cond do
          left_node != nil and right_node != nil ->
            # Recursively combine left and right subtrees
            left_result = combine_tree_results(left_node, all_partitions, results_map, combine_fn)
            right_result = combine_tree_results(right_node, all_partitions, results_map, combine_fn)
            
            # Apply combine function
            combine_fn.(left_result, right_result)
            
          left_node != nil ->
            # Only left subtree exists
            combine_tree_results(left_node, all_partitions, results_map, combine_fn)
            
          right_node != nil ->
            # Only right subtree exists
            combine_tree_results(right_node, all_partitions, results_map, combine_fn)
            
          true ->
            # No children found, return node's own result
            Map.get(results_map, node_id)
        end
        
      _ ->
        # Unknown node type, return result if available
        Map.get(results_map, node_id)
    end
  end
  
  defp are_all_partitions_processed?(problem_data) do
    # Check if all partitions have been processed
    all_partitions = problem_data.metadata.partitions
    processed_partitions = problem_data.metadata.processed_partitions
    
    # For some paradigms, we might not need to process all partitions
    paradigm = problem_data.metadata.computation_paradigm
    
    case paradigm do
      :divide_and_conquer ->
        # For divide and conquer, we need at least all leaf nodes processed
        leaf_partitions = Enum.filter(all_partitions, fn p -> p.type == :leaf end)
        
        Enum.all?(leaf_partitions, fn partition ->
          Map.has_key?(processed_partitions, partition.id)
        end)
        
      _ ->
        # For other paradigms, check all partitions
        Enum.all?(all_partitions, fn partition ->
          Map.has_key?(processed_partitions, partition.id)
        end)
    end
  end
  
  defp combine_all_results(problem_data) do
    # Combine all processed partitions into a final result
    paradigm = problem_data.metadata.computation_paradigm
    
    case paradigm do
      :map_reduce ->
        # Apply reduce function to all mapped results
        processed = Map.values(problem_data.metadata.processed_partitions)
        map_results = Enum.map(processed, fn p -> p.result end)
        
        if Enum.empty?(map_results) do
          {:error, :no_mapped_results}
        else
          reduce_fn = problem_data.metadata.reduction_function
          
          try do
            {:ok, reduce_fn.(map_results)}
          rescue
            e -> {:error, {:reduction_error, e}}
          end
        end
        
      :divide_and_conquer ->
        # Find root partition
        root_partition = 
          Enum.find(problem_data.metadata.partitions, fn p -> 
            p.id == "0" or p.depth == 0 
          end)
          
        if root_partition == nil do
          {:error, :cannot_find_root_partition}
        else
          # Convert processed partitions to map
          results_map = 
            Enum.map(problem_data.metadata.processed_partitions, fn {id, data} ->
              {id, data.result}
            end)
            |> Map.new()
            
          # Combine from leaves up
          combine_fn = problem_data.config.custom_parameters.combine_function
          
          try do
            result = combine_tree_results(
              root_partition, 
              problem_data.metadata.partitions,
              results_map, 
              combine_fn
            )
            
            {:ok, result}
          rescue
            e -> {:error, {:combination_error, e}}
          end
        end
        
      _ ->
        # For other paradigms, try to use a custom combination function
        if Map.has_key?(problem_data.config.custom_parameters, :combine_function) do
          combine_fn = problem_data.config.custom_parameters.combine_function
          processed = Map.values(problem_data.metadata.processed_partitions)
          results = Enum.map(processed, fn p -> p.result end)
          
          try do
            {:ok, combine_fn.(results)}
          rescue
            e -> {:error, {:combination_error, e}}
          end
        else
          # No combine function, cannot produce final result
          {:error, :no_combine_function}
        end
    end
  end
  
  defp compute_total_time(problem_data) do
    # Calculate total computation time
    created_at = problem_data.created_at
    now = DateTime.utc_now()
    
    DateTime.diff(now, created_at, :millisecond)
  end
  
  defp has_computation_timeout?(problem_data) do
    # Check if timeout has occurred
    case problem_data.config.timeout do
      nil ->
        false
        
      timeout when is_integer(timeout) ->
        # Calculate elapsed time
        compute_total_time(problem_data) >= timeout
    end
  end
  
  defp combine_partial_results(problem_data) do
    # Try to combine partial results for early termination
    paradigm = problem_data.metadata.computation_paradigm
    
    case paradigm do
      :map_reduce ->
        # Apply reduce to whatever mapping results we have
        processed = Map.values(problem_data.metadata.processed_partitions)
        map_results = Enum.map(processed, fn p -> p.result end)
        
        if Enum.empty?(map_results) do
          {:error, :no_results_yet}
        else
          reduce_fn = problem_data.metadata.reduction_function
          
          try do
            {:ok, reduce_fn.(map_results)}
          rescue
            e -> {:error, {:reduction_error, e}}
          end
        end
        
      _ ->
        # For other paradigms, check if there's a partial result combiner
        if Map.has_key?(problem_data.config.custom_parameters, :partial_result_combiner) do
          combiner = problem_data.config.custom_parameters.partial_result_combiner
          processed = Map.values(problem_data.metadata.processed_partitions)
          
          if Enum.empty?(processed) do
            {:error, :no_results_yet}
          else
            results = Enum.map(processed, fn p -> p.result end)
            
            try do
              {:ok, combiner.(results)}
            rescue
              e -> {:error, {:combination_error, e}}
            end
          end
        else
          # No partial result combiner
          {:error, :cannot_combine_partial_results}
        end
    end
  end
  
  defp initialize_algorithm_state(config) do
    paradigm = Map.get(config.custom_parameters, :computation_paradigm, :map_reduce)
    
    case paradigm do
      :map_reduce ->
        %{
          map_phase_complete: false,
          mapped_results: %{},
          reducer_state: nil
        }
        
      :parallel_processing ->
        %{
          task_counter: 0,
          completed_tasks: %{},
          result_combining_stage: :not_started
        }
        
      :actor_model ->
        %{
          actor_registry: %{},
          message_count: 0,
          state_snapshots: []
        }
        
      :grid_computing ->
        %{
          grid_nodes: %{},
          task_allocation: %{},
          node_performance: %{}
        }
        
      :stream_processing ->
        %{
          stream_position: 0,
          windowed_results: [],
          window_size: Map.get(config.custom_parameters, :window_size, 100),
          current_window: []
        }
        
      :divide_and_conquer ->
        %{
          divide_function: Map.get(config.custom_parameters, :divide_function, &default_divide/1),
          combine_function: config.custom_parameters.combine_function,
          threshold_function: Map.get(config.custom_parameters, :threshold_function, fn data -> length(data) <= 1 end),
          divide_count: 0,
          combine_count: 0
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