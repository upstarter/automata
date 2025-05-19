defmodule Automata.CollectiveIntelligence.DecisionProcesses.DecisionProcess do
  @moduledoc """
  Base module for collective decision processes.
  
  This module defines the core behavior and structure for all decision processes,
  providing a common interface and lifecycle management for different decision
  mechanisms including consensus, voting, argumentation, and preference aggregation.
  """
  use GenServer
  
  alias Automata.CollectiveIntelligence.KnowledgeSynthesis.KnowledgeSystem
  
  @type process_id :: String.t()
  @type participant_id :: String.t()
  @type input :: map()
  @type result :: map()
  @type process_state :: :initializing | :collecting | :deliberating | :decided | :closed
  @type process_type :: :consensus | :voting | :argumentation | :preference
  
  @type decision_config :: %{
    type: process_type(),
    topic: String.t(),
    description: String.t(),
    knowledge_context: KnowledgeSystem.context_id() | nil,
    options: map(),
    min_participants: pos_integer(),
    max_participants: pos_integer() | :unlimited,
    timeout: pos_integer() | nil,
    quorum: float() | nil,
    custom_parameters: map()
  }
  
  @type process_data :: %{
    id: process_id(),
    config: decision_config(),
    state: process_state(),
    participants: %{participant_id() => map()},
    inputs: %{participant_id() => input()},
    result: result() | nil,
    started_at: DateTime.t(),
    updated_at: DateTime.t(),
    ended_at: DateTime.t() | nil,
    metadata: map()
  }
  
  @callback initialize(decision_config()) :: {:ok, process_data()} | {:error, term()}
  @callback register_participant(process_data(), participant_id(), map()) :: 
    {:ok, process_data()} | {:error, term()}
  @callback submit_input(process_data(), participant_id(), input()) :: 
    {:ok, process_data()} | {:error, term()}
  @callback compute_result(process_data()) :: 
    {:ok, process_data(), result()} | {:error, term()}
  @callback can_close?(process_data()) :: boolean()
  @callback close(process_data()) :: {:ok, process_data()} | {:error, term()}
  
  # GenServer implementation
  
  def start_link(type, config) when type in [:consensus, :voting, :argumentation, :preference] do
    config = Map.put(config, :type, type)
    GenServer.start_link(__MODULE__, config, name: via_tuple(config.id))
  end
  
  def init(config) do
    module = get_implementation_module(config.type)
    
    with {:ok, process_data} <- module.initialize(config) do
      {:ok, %{
        data: process_data,
        implementation: module
      }}
    else
      {:error, reason} -> {:stop, reason}
    end
  end
  
  # Client API
  
  @spec register_participant(process_id(), participant_id(), map()) :: 
    {:ok, :registered} | {:error, term()}
  def register_participant(process_id, participant_id, params \\ %{}) do
    GenServer.call(via_tuple(process_id), {:register_participant, participant_id, params})
  end
  
  @spec submit_input(process_id(), participant_id(), input()) ::
    {:ok, :submitted} | {:error, term()}
  def submit_input(process_id, participant_id, input) do
    GenServer.call(via_tuple(process_id), {:submit_input, participant_id, input})
  end
  
  @spec get_status(process_id()) :: 
    {:ok, process_state(), map()} | {:error, term()}
  def get_status(process_id) do
    GenServer.call(via_tuple(process_id), :get_status)
  end
  
  @spec get_result(process_id()) :: 
    {:ok, result()} | {:error, term()}
  def get_result(process_id) do
    GenServer.call(via_tuple(process_id), :get_result)
  end
  
  @spec close_process(process_id()) :: 
    {:ok, :closed} | {:error, term()}
  def close_process(process_id) do
    GenServer.call(via_tuple(process_id), :close)
  end
  
  # GenServer callbacks
  
  def handle_call({:register_participant, participant_id, params}, _from, %{data: data, implementation: impl} = state) do
    case impl.register_participant(data, participant_id, params) do
      {:ok, updated_data} ->
        {:reply, {:ok, :registered}, %{state | data: updated_data}}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:submit_input, participant_id, input}, _from, %{data: data, implementation: impl} = state) do
    case impl.submit_input(data, participant_id, input) do
      {:ok, updated_data} ->
        new_state = %{state | data: updated_data}
        
        if impl.can_close?(updated_data) do
          case impl.compute_result(updated_data) do
            {:ok, result_data, _result} ->
              {:reply, {:ok, :submitted}, %{new_state | data: result_data}}
            {:error, reason} ->
              {:reply, {:error, reason}, new_state}
          end
        else
          {:reply, {:ok, :submitted}, new_state}
        end
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call(:get_status, _from, %{data: data} = state) do
    status_info = %{
      id: data.id,
      state: data.state,
      participants_count: map_size(data.participants),
      inputs_count: map_size(data.inputs),
      started_at: data.started_at,
      updated_at: data.updated_at
    }
    
    {:reply, {:ok, data.state, status_info}, state}
  end
  
  def handle_call(:get_result, _from, %{data: data} = state) do
    case data.result do
      nil -> {:reply, {:error, :no_result_available}, state}
      result -> {:reply, {:ok, result}, state}
    end
  end
  
  def handle_call(:close, _from, %{data: data, implementation: impl} = state) do
    case impl.close(data) do
      {:ok, updated_data} ->
        {:reply, {:ok, :closed}, %{state | data: updated_data}}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  # Private helpers
  
  defp via_tuple(process_id) do
    {:via, Registry, {Automata.Registry, {__MODULE__, process_id}}}
  end
  
  defp get_implementation_module(:consensus),
    do: Automata.CollectiveIntelligence.DecisionProcesses.Consensus

  defp get_implementation_module(:voting),
    do: Automata.CollectiveIntelligence.DecisionProcesses.Voting
    
  defp get_implementation_module(:argumentation),
    do: Automata.CollectiveIntelligence.DecisionProcesses.Argumentation
    
  defp get_implementation_module(:preference),
    do: Automata.CollectiveIntelligence.DecisionProcesses.Preference
end