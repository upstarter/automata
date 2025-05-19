defmodule Automata.CollectiveIntelligence.DecisionProcesses.ProcessManager do
  @moduledoc """
  Manages the lifecycle of decision processes.
  
  This module provides functionality for creating, tracking, and managing
  different types of decision processes. It maintains a registry of active
  processes and handles their coordination and lifecycle events.
  """
  use GenServer
  
  alias Automata.CollectiveIntelligence.DecisionProcesses.DecisionProcess
  
  @type process_id :: DecisionProcess.process_id()
  @type process_type :: DecisionProcess.process_type()
  @type decision_config :: DecisionProcess.decision_config()
  
  # Client API
  
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @spec create_process(process_type(), map()) :: 
    {:ok, process_id()} | {:error, term()}
  def create_process(type, config) when type in [:consensus, :voting, :argumentation, :preference] do
    GenServer.call(__MODULE__, {:create_process, type, config})
  end
  
  @spec list_processes() :: {:ok, [%{id: process_id(), type: process_type(), state: atom()}]}
  def list_processes do
    GenServer.call(__MODULE__, :list_processes)
  end
  
  @spec get_process_info(process_id()) :: {:ok, map()} | {:error, :not_found}
  def get_process_info(process_id) do
    GenServer.call(__MODULE__, {:get_process_info, process_id})
  end
  
  # GenServer callbacks
  
  @impl true
  def init(_opts) do
    {:ok, %{
      processes: %{},
      process_count: 0
    }}
  end
  
  @impl true
  def handle_call({:create_process, type, config}, _from, state) do
    process_id = generate_process_id(type, state.process_count)
    
    # Ensure config has an ID
    full_config = Map.put(config, :id, process_id)
    
    case DecisionProcess.start_link(type, full_config) do
      {:ok, pid} ->
        process_info = %{
          id: process_id,
          type: type,
          pid: pid,
          created_at: DateTime.utc_now(),
          config: full_config,
        }
        
        new_state = %{
          state | 
          processes: Map.put(state.processes, process_id, process_info),
          process_count: state.process_count + 1
        }
        
        {:reply, {:ok, process_id}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:list_processes, _from, state) do
    process_summaries = 
      state.processes
      |> Enum.map(fn {id, info} ->
        {:ok, process_state, _} = DecisionProcess.get_status(id)
        
        %{
          id: id,
          type: info.type,
          state: process_state,
          created_at: info.created_at
        }
      end)
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
    
    {:reply, {:ok, process_summaries}, state}
  end
  
  @impl true
  def handle_call({:get_process_info, process_id}, _from, state) do
    case Map.get(state.processes, process_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      
      info ->
        {:ok, status_state, status_info} = DecisionProcess.get_status(process_id)
        
        process_info = Map.merge(info, %{
          state: status_state,
          status: status_info
        })
        
        {:reply, {:ok, process_info}, state}
    end
  end
  
  # Private helpers
  
  defp generate_process_id(type, count) do
    type_prefix = String.slice(Atom.to_string(type), 0, 3)
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "#{type_prefix}_#{timestamp}_#{count}"
  end
end