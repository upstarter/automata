defmodule Automata.CollectiveIntelligence.ProblemSolving.ProblemManager do
  @moduledoc """
  Manages the lifecycle of distributed problem solving processes.
  
  This module provides functionality for creating, tracking, and managing
  different types of distributed problem-solving processes. It maintains a registry 
  of active problems and handles their coordination and lifecycle events.
  """
  use GenServer
  
  alias Automata.CollectiveIntelligence.ProblemSolving.DistributedProblem
  
  @type problem_id :: DistributedProblem.problem_id()
  @type problem_type :: DistributedProblem.problem_type()
  @type problem_config :: DistributedProblem.problem_config()
  
  # Client API
  
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @spec create_problem(problem_type(), map()) :: 
    {:ok, problem_id()} | {:error, term()}
  def create_problem(type, config) when type in [:optimization, :search, :planning, :constraint_satisfaction, :distributed_computation] do
    GenServer.call(__MODULE__, {:create_problem, type, config})
  end
  
  @spec list_problems() :: {:ok, [%{id: problem_id(), type: problem_type(), state: atom()}]}
  def list_problems do
    GenServer.call(__MODULE__, :list_problems)
  end
  
  @spec get_problem_info(problem_id()) :: {:ok, map()} | {:error, :not_found}
  def get_problem_info(problem_id) do
    GenServer.call(__MODULE__, {:get_problem_info, problem_id})
  end
  
  @spec filter_problems(map()) :: {:ok, [%{id: problem_id(), type: problem_type(), state: atom()}]}
  def filter_problems(criteria) do
    GenServer.call(__MODULE__, {:filter_problems, criteria})
  end
  
  # GenServer callbacks
  
  @impl true
  def init(_opts) do
    {:ok, %{
      problems: %{},
      problem_count: 0
    }}
  end
  
  @impl true
  def handle_call({:create_problem, type, config}, _from, state) do
    problem_id = config.id || generate_problem_id(type, state.problem_count)
    
    # Ensure config has an ID
    full_config = Map.put(config, :id, problem_id)
    
    case DistributedProblem.start_link(type, full_config) do
      {:ok, pid} ->
        problem_info = %{
          id: problem_id,
          type: type,
          pid: pid,
          created_at: DateTime.utc_now(),
          config: full_config,
        }
        
        new_state = %{
          state | 
          problems: Map.put(state.problems, problem_id, problem_info),
          problem_count: state.problem_count + 1
        }
        
        {:reply, {:ok, problem_id}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:list_problems, _from, state) do
    problem_summaries = 
      state.problems
      |> Enum.map(fn {id, info} ->
        {:ok, problem_state, _} = DistributedProblem.get_status(id)
        
        %{
          id: id,
          type: info.type,
          state: problem_state,
          created_at: info.created_at
        }
      end)
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
    
    {:reply, {:ok, problem_summaries}, state}
  end
  
  @impl true
  def handle_call({:get_problem_info, problem_id}, _from, state) do
    case Map.get(state.problems, problem_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      
      info ->
        {:ok, status_state, status_info} = DistributedProblem.get_status(problem_id)
        
        problem_info = Map.merge(info, %{
          state: status_state,
          status: status_info
        })
        
        {:reply, {:ok, problem_info}, state}
    end
  end
  
  @impl true
  def handle_call({:filter_problems, criteria}, _from, state) do
    filtered_summaries = 
      state.problems
      |> Enum.map(fn {id, info} ->
        {:ok, problem_state, _} = DistributedProblem.get_status(id)
        
        %{
          id: id,
          type: info.type,
          state: problem_state,
          created_at: info.created_at,
          name: info.config.name,
          description: info.config.description
        }
      end)
      |> Enum.filter(fn problem ->
        matches_criteria?(problem, criteria)
      end)
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
    
    {:reply, {:ok, filtered_summaries}, state}
  end
  
  # Private helpers
  
  defp generate_problem_id(type, count) do
    type_prefix = String.slice(Atom.to_string(type), 0, 3)
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "#{type_prefix}_#{timestamp}_#{count}"
  end
  
  defp matches_criteria?(problem, criteria) do
    Enum.all?(criteria, fn {key, value} ->
      case key do
        :type when is_atom(value) ->
          problem.type == value
          
        :type when is_list(value) ->
          problem.type in value
          
        :state when is_atom(value) ->
          problem.state == value
          
        :state when is_list(value) ->
          problem.state in value
          
        :name_contains when is_binary(value) ->
          String.contains?(problem.name, value)
          
        :description_contains when is_binary(value) ->
          String.contains?(problem.description, value)
          
        :created_after when is_struct(value, DateTime) ->
          DateTime.compare(problem.created_at, value) in [:gt, :eq]
          
        :created_before when is_struct(value, DateTime) ->
          DateTime.compare(problem.created_at, value) in [:lt, :eq]
          
        _ ->
          false
      end
    end)
  end
end