defmodule Automata.DistributedCognition.CoalitionFormation.CoalitionFormationSystem do
  @moduledoc """
  Main entry point for the Coalition Formation Framework.
  
  This module integrates the dynamic protocols, incentive alignment, and other components
  of the Coalition Formation Framework into a cohesive system for managing distributed
  agent coalitions.
  """
  
  use GenServer
  
  alias Automata.DistributedCognition.CoalitionFormation.DynamicProtocols
  alias Automata.DistributedCognition.CoalitionFormation.IncentiveAlignment
  alias Automata.DistributedCognition.BeliefArchitecture.DecentralizedBeliefSystem
  
  # Client API
  
  @doc """
  Starts the Coalition Formation System.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Forms a new coalition with the given initiator, members, and parameters.
  """
  def form_coalition(server \\ __MODULE__, initiator, members, params) do
    GenServer.call(server, {:form_coalition, initiator, members, params})
  end
  
  @doc """
  Gets information about a specific coalition.
  """
  def get_coalition(server \\ __MODULE__, coalition_id) do
    GenServer.call(server, {:get_coalition, coalition_id})
  end
  
  @doc """
  Lists all active coalitions in the system.
  """
  def list_coalitions(server \\ __MODULE__) do
    GenServer.call(server, :list_coalitions)
  end
  
  @doc """
  Dissolves a coalition, releasing all resources and notifying members.
  """
  def dissolve_coalition(server \\ __MODULE__, coalition_id, reason) do
    GenServer.call(server, {:dissolve_coalition, coalition_id, reason})
  end
  
  @doc """
  Adds a new member to an existing coalition.
  """
  def add_member(server \\ __MODULE__, coalition_id, new_member, member_contract) do
    GenServer.call(server, {:add_member, coalition_id, new_member, member_contract})
  end
  
  @doc """
  Removes a member from an existing coalition.
  """
  def remove_member(server \\ __MODULE__, coalition_id, member, reason) do
    GenServer.call(server, {:remove_member, coalition_id, member, reason})
  end
  
  @doc """
  Analyzes the stability of a coalition.
  """
  def analyze_stability(server \\ __MODULE__, coalition_id) do
    GenServer.call(server, {:analyze_stability, coalition_id})
  end
  
  @doc """
  Reinforces the stability of a coalition.
  """
  def reinforce_stability(server \\ __MODULE__, coalition_id, strategy) do
    GenServer.call(server, {:reinforce_stability, coalition_id, strategy})
  end
  
  @doc """
  Allocates resources among coalition members.
  """
  def allocate_resources(server \\ __MODULE__, coalition_id, strategy) do
    GenServer.call(server, {:allocate_resources, coalition_id, strategy})
  end
  
  @doc """
  Merges two or more coalitions into a single larger coalition.
  """
  def merge_coalitions(server \\ __MODULE__, coalition_ids, merge_strategy) do
    GenServer.call(server, {:merge_coalitions, coalition_ids, merge_strategy})
  end
  
  @doc """
  Splits a coalition into two or more smaller coalitions.
  """
  def split_coalition(server \\ __MODULE__, coalition_id, partition_strategy) do
    GenServer.call(server, {:split_coalition, coalition_id, partition_strategy})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    registry_name = Keyword.get(opts, :registry_name, CoalitionRegistry)
    
    # Initialize the registry for storing coalitions
    {:ok, _} = Registry.start_link(keys: :unique, name: registry_name)
    
    # Initialize state
    initial_state = %{
      coalitions: %{},
      registry: registry_name,
      next_id: 1,
      config: Keyword.get(opts, :config, default_config())
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:form_coalition, initiator, members, params}, _from, state) do
    # Generate coalition ID
    coalition_id = generate_coalition_id(state.next_id)
    
    # Create contract
    contract_params = Map.merge(default_contract_params(), params)
    
    # Form the coalition
    case DynamicProtocols.LifecycleManager.form_coalition(initiator, members, contract_params) do
      {:ok, coalition} ->
        # Register coalition
        new_coalitions = Map.put(state.coalitions, coalition_id, coalition)
        
        # Update state
        new_state = %{
          state |
          coalitions: new_coalitions,
          next_id: state.next_id + 1
        }
        
        # Create belief set for the coalition
        DecentralizedBeliefSystem.create_belief_set(coalition_id)
        
        {:reply, {:ok, coalition_id}, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
        
      {:negotiation_failed, reasons} ->
        {:reply, {:error, {:negotiation_failed, reasons}}, state}
    end
  end
  
  @impl true
  def handle_call({:get_coalition, coalition_id}, _from, state) do
    case Map.fetch(state.coalitions, coalition_id) do
      {:ok, coalition} ->
        {:reply, {:ok, coalition}, state}
        
      :error ->
        {:reply, {:error, :coalition_not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:list_coalitions, _from, state) do
    active_coalitions = state.coalitions
    |> Enum.filter(fn {_id, coalition} -> coalition.state == :active end)
    |> Enum.map(fn {id, coalition} -> 
      %{
        id: id,
        members: coalition.active_members,
        created_at: coalition.created_at,
        state: coalition.state
      }
    end)
    
    {:reply, {:ok, active_coalitions}, state}
  end
  
  @impl true
  def handle_call({:dissolve_coalition, coalition_id, reason}, _from, state) do
    case Map.fetch(state.coalitions, coalition_id) do
      {:ok, coalition} ->
        case DynamicProtocols.LifecycleManager.dissolve_coalition(coalition_id, reason) do
          {:ok, dissolved_coalition} ->
            # Update coalition in state
            new_coalitions = Map.put(state.coalitions, coalition_id, dissolved_coalition)
            
            # Delete belief set for the coalition
            DecentralizedBeliefSystem.delete_belief_set(coalition_id)
            
            {:reply, {:ok, dissolved_coalition}, %{state | coalitions: new_coalitions}}
            
          {:error, error_reason} ->
            {:reply, {:error, error_reason}, state}
        end
        
      :error ->
        {:reply, {:error, :coalition_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:add_member, coalition_id, new_member, member_contract}, _from, state) do
    case Map.fetch(state.coalitions, coalition_id) do
      {:ok, coalition} ->
        case DynamicProtocols.LifecycleManager.add_member(coalition_id, new_member, member_contract) do
          {:ok, updated_coalition} ->
            # Update coalition in state
            new_coalitions = Map.put(state.coalitions, coalition_id, updated_coalition)
            
            {:reply, {:ok, updated_coalition}, %{state | coalitions: new_coalitions}}
            
          {:error, error_reason} ->
            {:reply, {:error, error_reason}, state}
        end
        
      :error ->
        {:reply, {:error, :coalition_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:remove_member, coalition_id, member, reason}, _from, state) do
    case Map.fetch(state.coalitions, coalition_id) do
      {:ok, coalition} ->
        case DynamicProtocols.LifecycleManager.remove_member(coalition_id, member, reason) do
          {:ok, updated_coalition} ->
            # Update coalition in state
            new_coalitions = Map.put(state.coalitions, coalition_id, updated_coalition)
            
            {:reply, {:ok, updated_coalition}, %{state | coalitions: new_coalitions}}
            
          {:error, error_reason} ->
            {:reply, {:error, error_reason}, state}
        end
        
      :error ->
        {:reply, {:error, :coalition_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:analyze_stability, coalition_id}, _from, state) do
    case Map.fetch(state.coalitions, coalition_id) do
      {:ok, _coalition} ->
        result = IncentiveAlignment.StabilityMechanisms.analyze_stability(coalition_id)
        {:reply, result, state}
        
      :error ->
        {:reply, {:error, :coalition_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:reinforce_stability, coalition_id, strategy}, _from, state) do
    case Map.fetch(state.coalitions, coalition_id) do
      {:ok, _coalition} ->
        case IncentiveAlignment.StabilityMechanisms.reinforce_stability(coalition_id, strategy) do
          {:ok, updated_coalition} ->
            # Update coalition in state
            new_coalitions = Map.put(state.coalitions, coalition_id, updated_coalition)
            
            {:reply, {:ok, updated_coalition}, %{state | coalitions: new_coalitions}}
            
          {:error, error_reason} ->
            {:reply, {:error, error_reason}, state}
        end
        
      :error ->
        {:reply, {:error, :coalition_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:allocate_resources, coalition_id, strategy}, _from, state) do
    case Map.fetch(state.coalitions, coalition_id) do
      {:ok, coalition} ->
        case IncentiveAlignment.ResourceAllocation.allocate_resources(coalition, strategy) do
          {:ok, allocation} ->
            # Update coalition with new allocation
            updated_coalition = %{
              coalition |
              resources: allocation,
              updated_at: DateTime.utc_now()
            }
            
            new_coalitions = Map.put(state.coalitions, coalition_id, updated_coalition)
            
            {:reply, {:ok, allocation}, %{state | coalitions: new_coalitions}}
            
          {:error, error_reason} ->
            {:reply, {:error, error_reason}, state}
        end
        
      :error ->
        {:reply, {:error, :coalition_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:merge_coalitions, coalition_ids, merge_strategy}, _from, state) do
    # Check if all coalitions exist
    coalitions_exist = Enum.all?(coalition_ids, fn id -> Map.has_key?(state.coalitions, id) end)
    
    if coalitions_exist do
      case DynamicProtocols.AdaptiveCoalitionStructures.merge_coalitions(coalition_ids, merge_strategy) do
        {:ok, merged_coalition} ->
          # Generate a new coalition ID
          new_coalition_id = generate_coalition_id(state.next_id)
          
          # Add merged coalition to state
          new_coalitions = Map.put(state.coalitions, new_coalition_id, merged_coalition)
          
          # Remove old coalitions
          new_coalitions = Enum.reduce(coalition_ids, new_coalitions, fn id, acc ->
            Map.delete(acc, id)
          end)
          
          # Create belief set for the new coalition
          DecentralizedBeliefSystem.create_belief_set(new_coalition_id)
          
          # Delete belief sets for old coalitions
          Enum.each(coalition_ids, fn id ->
            DecentralizedBeliefSystem.delete_belief_set(id)
          end)
          
          {:reply, {:ok, new_coalition_id}, %{state | coalitions: new_coalitions, next_id: state.next_id + 1}}
          
        {:error, error_reason} ->
          {:reply, {:error, error_reason}, state}
      end
    else
      {:reply, {:error, :one_or_more_coalitions_not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:split_coalition, coalition_id, partition_strategy}, _from, state) do
    case Map.fetch(state.coalitions, coalition_id) do
      {:ok, _coalition} ->
        case DynamicProtocols.AdaptiveCoalitionStructures.split_coalition(coalition_id, partition_strategy) do
          {:ok, new_coalitions} ->
            # Generate IDs for new coalitions
            coalition_map = new_coalitions
            |> Enum.with_index(fn coalition, index -> 
              id = generate_coalition_id(state.next_id + index)
              {id, coalition}
            end)
            |> Enum.into(%{})
            
            # Remove old coalition
            updated_coalitions = Map.delete(state.coalitions, coalition_id)
            
            # Add new coalitions
            updated_coalitions = Map.merge(updated_coalitions, coalition_map)
            
            # Create belief sets for new coalitions
            Enum.each(Map.keys(coalition_map), fn id ->
              DecentralizedBeliefSystem.create_belief_set(id)
            end)
            
            # Delete belief set for old coalition
            DecentralizedBeliefSystem.delete_belief_set(coalition_id)
            
            {:reply, {:ok, Map.keys(coalition_map)}, %{
              state | 
              coalitions: updated_coalitions, 
              next_id: state.next_id + map_size(coalition_map)
            }}
            
          {:error, error_reason} ->
            {:reply, {:error, error_reason}, state}
        end
        
      :error ->
        {:reply, {:error, :coalition_not_found}, state}
    end
  end
  
  # Private functions
  
  defp generate_coalition_id(next_id) do
    "coalition_" <> Integer.to_string(next_id)
  end
  
  defp default_config do
    %{
      max_coalitions: 100,
      default_stability_threshold: 0.6,
      default_resource_allocation_strategy: :proportional,
      default_stability_reinforcement_strategy: :auto,
      periodic_stability_check: true,
      stability_check_interval: 60_000, # 1 minute
      enable_manipulation_detection: true,
      manipulation_check_interval: 300_000 # 5 minutes
    }
  end
  
  defp default_contract_params do
    %{
      obligations: %{},
      permissions: %{},
      resource_commitments: %{},
      expected_outcomes: [],
      termination_conditions: [
        %{type: :time_limit, threshold: 3600} # 1 hour
      ]
    }
  end
end

defmodule Automata.DistributedCognition.CoalitionFormation.CoalitionRegistry do
  @moduledoc """
  Registry for tracking coalitions in the system.
  
  This module provides a facade over the underlying Registry to make it more convenient
  to work with coalitions.
  """
  
  @doc """
  Registers a coalition with the registry.
  """
  def register(registry, coalition_id, coalition) do
    Registry.register(registry, :coalitions, {coalition_id, coalition})
  end
  
  @doc """
  Unregisters a coalition from the registry.
  """
  def unregister(registry, coalition_id) do
    Registry.unregister(registry, {:coalition, coalition_id})
  end
  
  @doc """
  Looks up a coalition in the registry.
  """
  def lookup(registry, coalition_id) do
    case Registry.lookup(registry, {:coalition, coalition_id}) do
      [{_pid, coalition}] -> {:ok, coalition}
      [] -> {:error, :not_found}
    end
  end
  
  @doc """
  Lists all coalitions in the registry.
  """
  def list_all(registry) do
    Registry.select(registry, [{{:coalitions, :"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}])
  end
  
  @doc """
  Returns the count of coalitions in the registry.
  """
  def count(registry) do
    Registry.count(registry)
  end
end