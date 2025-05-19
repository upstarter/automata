defmodule Automata.DistributedCognition.BeliefArchitecture.DecentralizedBeliefSystem do
  @moduledoc """
  Decentralized Belief System

  This module serves as the main entry point for the Decentralized Belief Architecture,
  providing a unified interface for belief management, propagation, and consistency.

  The decentralized belief system enables:
  - Asynchronous belief updates with convergence guarantees
  - Belief conflict resolution with provable properties
  - Consistency management with bounded time guarantees
  - Local-global belief alignment mechanisms
  """

  alias Automata.DistributedCognition.BeliefArchitecture.BeliefPropagation
  alias Automata.DistributedCognition.BeliefArchitecture.BeliefPropagation.{BeliefAtom, BeliefSet}
  alias Automata.DistributedCognition.BeliefArchitecture.ConsistencyManagement
  alias Automata.DistributedCognition.BeliefArchitecture.ConsistencyManagement.ConsistencyTracker

  # Agent implementation
  use GenServer

  defmodule State do
    @moduledoc """
    Internal state for the belief system agent
    """

    @type t :: %__MODULE__{
            agent_id: atom() | pid(),
            belief_set: BeliefSet.t(),
            config: map(),
            last_sync: DateTime.t(),
            neighbors: list(pid()),
            metrics: map(),
            consistency_tracker: ConsistencyTracker.t()
          }

    defstruct [
      :agent_id,
      :belief_set,
      :config,
      :last_sync,
      :neighbors,
      :metrics,
      :consistency_tracker
    ]
  end

  @doc """
  Starts a new belief system agent
  """
  @spec start_link(atom(), keyword()) :: GenServer.on_start()
  def start_link(agent_id, options \\ []) do
    GenServer.start_link(__MODULE__, {agent_id, options}, name: process_name(agent_id))
  end

  @doc """
  Generates a process name for an agent
  """
  @spec process_name(atom()) :: atom()
  def process_name(agent_id) when is_atom(agent_id) do
    :"#{agent_id}_belief_system"
  end

  @doc """
  Initializes the belief system agent
  """
  @impl true
  def init({agent_id, options}) do
    # Create initial belief set
    belief_set = BeliefPropagation.create_belief_set(agent_id)
    
    # Set default configuration
    default_config = %{
      sync_interval: Keyword.get(options, :sync_interval, 5000),
      conflict_strategy: Keyword.get(options, :conflict_strategy, :probabilistic),
      acceptance_threshold: Keyword.get(options, :acceptance_threshold, 0.5),
      auto_sync: Keyword.get(options, :auto_sync, true),
      metrics_enabled: Keyword.get(options, :metrics_enabled, true)
    }
    
    # Initialize empty metrics
    metrics = %{
      updates_received: 0,
      updates_accepted: 0,
      updates_rejected: 0,
      beliefs_sent: 0,
      conflicts_resolved: 0,
      last_convergence_score: 0.0
    }
    
    # Initialize state
    state = %State{
      agent_id: agent_id,
      belief_set: belief_set,
      config: default_config,
      last_sync: DateTime.utc_now(),
      neighbors: Keyword.get(options, :neighbors, []),
      metrics: metrics,
      consistency_tracker: ConsistencyManagement.create_consistency_tracker()
    }
    
    # Start automatic sync if enabled
    if state.config.auto_sync do
      schedule_sync(state.config.sync_interval)
    end
    
    {:ok, state}
  end

  # API Functions

  @doc """
  Adds a new belief to the agent's belief set
  """
  @spec add_belief(pid() | atom(), any(), float(), keyword()) :: :ok
  def add_belief(agent, content, confidence, options \\ []) do
    GenServer.cast(ensure_pid(agent), {:add_belief, content, confidence, options})
  end

  @doc """
  Adds a pre-constructed belief to the agent's belief set
  """
  @spec add_belief_atom(pid() | atom(), BeliefAtom.t()) :: :ok
  def add_belief_atom(agent, belief) do
    GenServer.cast(ensure_pid(agent), {:add_belief_atom, belief})
  end

  @doc """
  Retrieves the agent's current belief set
  """
  @spec get_belief_set(pid() | atom()) :: BeliefSet.t()
  def get_belief_set(agent) do
    GenServer.call(ensure_pid(agent), :get_belief_set)
  end

  @doc """
  Retrieves a specific belief by ID
  """
  @spec get_belief(pid() | atom(), String.t()) :: BeliefAtom.t() | nil
  def get_belief(agent, belief_id) do
    GenServer.call(ensure_pid(agent), {:get_belief, belief_id})
  end

  @doc """
  Retrieves all beliefs that match a given predicate
  """
  @spec query_beliefs(pid() | atom(), (BeliefAtom.t() -> boolean())) :: list(BeliefAtom.t())
  def query_beliefs(agent, predicate) do
    GenServer.call(ensure_pid(agent), {:query_beliefs, predicate})
  end

  @doc """
  Updates the agent's neighbors list
  """
  @spec update_neighbors(pid() | atom(), list(pid())) :: :ok
  def update_neighbors(agent, new_neighbors) do
    GenServer.cast(ensure_pid(agent), {:update_neighbors, new_neighbors})
  end

  @doc """
  Triggers an immediate synchronization with neighbors
  """
  @spec sync_with_neighbors(pid() | atom()) :: :ok
  def sync_with_neighbors(agent) do
    GenServer.cast(ensure_pid(agent), :sync_with_neighbors)
  end

  @doc """
  Synchronizes with a specific agent
  """
  @spec sync_with_agent(pid() | atom(), pid() | atom()) :: :ok
  def sync_with_agent(agent, target_agent) do
    GenServer.cast(ensure_pid(agent), {:sync_with_agent, ensure_pid(target_agent)})
  end

  @doc """
  Updates the agent's configuration
  """
  @spec update_config(pid() | atom(), map()) :: :ok
  def update_config(agent, config_updates) do
    GenServer.cast(ensure_pid(agent), {:update_config, config_updates})
  end

  @doc """
  Retrieves the agent's current metrics
  """
  @spec get_metrics(pid() | atom()) :: map()
  def get_metrics(agent) do
    GenServer.call(ensure_pid(agent), :get_metrics)
  end

  @doc """
  Propagates a belief to specific target agents
  """
  @spec propagate_belief(pid() | atom(), String.t(), list(pid() | atom()), keyword()) :: :ok
  def propagate_belief(agent, belief_id, target_agents, options \\ []) do
    GenServer.cast(ensure_pid(agent), {:propagate_belief, belief_id, Enum.map(target_agents, &ensure_pid/1), options})
  end

  # Global system functions (not tied to specific agent)

  @doc """
  Creates a global belief state from multiple agents
  """
  @spec global_belief_state(list(pid() | atom()), keyword()) :: BeliefSet.t()
  def global_belief_state(agents, options \\ []) do
    # Collect belief sets from all agents
    belief_sets = Enum.map(agents, fn agent ->
      get_belief_set(agent)
    end)
    
    # Construct global state
    ConsistencyManagement.construct_global_belief_state(belief_sets, options)
  end

  @doc """
  Creates and executes a consistency plan for a group of agents
  """
  @spec ensure_consistency(list(pid() | atom()), keyword()) :: map()
  def ensure_consistency(agents, options \\ []) do
    # Collect belief sets from all agents
    agent_belief_sets = 
      agents
      |> Enum.map(fn agent -> {agent, get_belief_set(agent)} end)
      |> Map.new()
    
    # Create consistency plan
    plan = ConsistencyManagement.create_consistency_plan(agents, options)
    
    # Execute the plan
    ConsistencyManagement.execute_consistency_plan(plan, agent_belief_sets, options)
  end

  @doc """
  Verifies consistency across a group of agents
  """
  @spec verify_consistency(list(pid() | atom()), keyword()) :: map()
  def verify_consistency(agents, options \\ []) do
    # Collect belief sets from all agents
    agent_belief_sets = 
      agents
      |> Enum.map(fn agent -> {agent, get_belief_set(agent)} end)
      |> Map.new()
    
    # Verify consistency
    ConsistencyManagement.verify_consistency(agent_belief_sets, options)
  end

  @doc """
  Aligns all agents with the global belief state
  """
  @spec align_with_global(list(pid() | atom()), keyword()) :: map()
  def align_with_global(agents, options \\ []) do
    # Collect belief sets from all agents
    agent_belief_sets = 
      agents
      |> Enum.map(fn agent -> {agent, get_belief_set(agent)} end)
      |> Map.new()
    
    # Construct global state
    global_set = ConsistencyManagement.construct_global_belief_state(Map.values(agent_belief_sets), options)
    
    # Identify misaligned agents
    misaligned = ConsistencyManagement.identify_misaligned_agents(
      agent_belief_sets,
      global_set,
      Keyword.get(options, :alignment_threshold, 0.7)
    )
    
    # If no misaligned agents, return early
    if Enum.empty?(misaligned) do
      %{
        status: :aligned,
        agents: length(agents),
        misaligned: 0,
        global_belief_count: map_size(global_set.beliefs)
      }
    else
      # Create alignment plan
      plan = ConsistencyManagement.create_alignment_plan(misaligned, global_set, options)
      
      # Execute the plan
      result = ConsistencyManagement.execute_alignment_plan(plan, agent_belief_sets, global_set, options)
      
      # Update each agent with its aligned belief set
      Enum.each(result.belief_sets, fn {agent, belief_set} ->
        update_belief_set(agent, belief_set)
      end)
      
      # Return summary
      %{
        status: :realigned,
        agents: length(agents),
        misaligned: length(misaligned),
        aligned: result.results.agents_aligned,
        global_belief_count: map_size(global_set.beliefs)
      }
    end
  end

  @doc """
  Updates an agent's entire belief set
  """
  @spec update_belief_set(pid() | atom(), BeliefSet.t()) :: :ok
  def update_belief_set(agent, belief_set) do
    GenServer.cast(ensure_pid(agent), {:update_belief_set, belief_set})
  end

  # GenServer Callbacks

  @impl true
  def handle_call(:get_belief_set, _from, state) do
    {:reply, state.belief_set, state}
  end

  @impl true
  def handle_call({:get_belief, belief_id}, _from, state) do
    belief = BeliefSet.get_belief(state.belief_set, belief_id)
    {:reply, belief, state}
  end

  @impl true
  def handle_call({:query_beliefs, predicate}, _from, state) do
    matching_beliefs = BeliefSet.filter_beliefs(state.belief_set, predicate)
    {:reply, matching_beliefs, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_cast({:add_belief, content, confidence, options}, state) do
    # Create the belief
    belief = BeliefPropagation.create_belief(content, state.agent_id, confidence, options)
    
    # Add to belief set
    updated_belief_set = BeliefSet.add_belief(state.belief_set, belief)
    
    # Auto-propagate if requested
    if Keyword.get(options, :propagate, false) do
      Task.start(fn ->
        propagate_to_neighbors(belief, state.neighbors, state.config)
      end)
    end
    
    {:noreply, %{state | belief_set: updated_belief_set}}
  end

  @impl true
  def handle_cast({:add_belief_atom, belief}, state) do
    # Add to belief set
    updated_belief_set = BeliefSet.add_belief(state.belief_set, belief)
    {:noreply, %{state | belief_set: updated_belief_set}}
  end

  @impl true
  def handle_cast({:update_neighbors, new_neighbors}, state) do
    {:noreply, %{state | neighbors: new_neighbors}}
  end

  @impl true
  def handle_cast(:sync_with_neighbors, state) do
    # Sync with each neighbor
    Enum.each(state.neighbors, fn neighbor ->
      Task.start(fn ->
        sync_with_neighbor(self(), neighbor, state.belief_set, state.config)
      end)
    end)
    
    # Schedule next sync if auto_sync is enabled
    if state.config.auto_sync do
      schedule_sync(state.config.sync_interval)
    end
    
    # Update last sync time
    updated_state = %{state | last_sync: DateTime.utc_now()}
    
    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:sync_with_agent, target_agent}, state) do
    # Sync with the specified agent
    Task.start(fn ->
      sync_with_neighbor(self(), target_agent, state.belief_set, state.config)
    end)
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_config, config_updates}, state) do
    # Update configuration
    updated_config = Map.merge(state.config, config_updates)
    
    # If sync interval changed and auto_sync is enabled, reschedule
    if Map.has_key?(config_updates, :sync_interval) and state.config.auto_sync do
      schedule_sync(updated_config.sync_interval)
    end
    
    # If auto_sync changed from false to true, schedule sync
    if not state.config.auto_sync and updated_config.auto_sync do
      schedule_sync(updated_config.sync_interval)
    end
    
    {:noreply, %{state | config: updated_config}}
  end

  @impl true
  def handle_cast({:propagate_belief, belief_id, target_agents, options}, state) do
    # Get the belief
    case BeliefSet.get_belief(state.belief_set, belief_id) do
      nil ->
        # Belief not found
        {:noreply, state}
        
      belief ->
        # Propagate the belief
        Task.start(fn ->
          BeliefPropagation.propagate_belief(belief, target_agents, options)
        end)
        
        # Update metrics
        updated_metrics = Map.update!(state.metrics, :beliefs_sent, &(&1 + 1))
        
        {:noreply, %{state | metrics: updated_metrics}}
    end
  end

  @impl true
  def handle_cast({:update_belief_set, new_belief_set}, state) do
    # Replace entire belief set
    {:noreply, %{state | belief_set: new_belief_set}}
  end

  @impl true
  def handle_info({:belief_update, belief}, state) do
    # Process incoming belief update
    {updated_belief_set, status} = BeliefPropagation.process_belief_update(
      belief,
      state.belief_set,
      [
        acceptance_threshold: state.config.acceptance_threshold,
        conflict_strategy: state.config.conflict_strategy
      ]
    )
    
    # Update metrics
    updated_metrics = Map.update!(state.metrics, :updates_received, &(&1 + 1))
    
    updated_metrics = 
      case status do
        :accepted ->
          updated_metrics
          |> Map.update!(:updates_accepted, &(&1 + 1))
          
        :rejected ->
          updated_metrics
          |> Map.update!(:updates_rejected, &(&1 + 1))
      end
    
    # Update state
    {:noreply, %{state | belief_set: updated_belief_set, metrics: updated_metrics}}
  end

  @impl true
  def handle_info({:belief_update, belief, sender, ref}, state) do
    # Process incoming belief update (with acknowledgement)
    {updated_belief_set, status} = BeliefPropagation.process_belief_update(
      belief,
      state.belief_set,
      [
        acceptance_threshold: state.config.acceptance_threshold,
        conflict_strategy: state.config.conflict_strategy
      ]
    )
    
    # Send acknowledgement
    send(sender, {:belief_ack, ref, status})
    
    # Update metrics
    updated_metrics = Map.update!(state.metrics, :updates_received, &(&1 + 1))
    
    updated_metrics = 
      case status do
        :accepted ->
          updated_metrics
          |> Map.update!(:updates_accepted, &(&1 + 1))
          
        :rejected ->
          updated_metrics
          |> Map.update!(:updates_rejected, &(&1 + 1))
      end
    
    # Update state
    {:noreply, %{state | belief_set: updated_belief_set, metrics: updated_metrics}}
  end

  @impl true
  def handle_info(:sync_timeout, state) do
    # Time to sync with neighbors
    handle_cast(:sync_with_neighbors, state)
  end

  @impl true
  def handle_info(_, state) do
    # Ignore unknown messages
    {:noreply, state}
  end

  # Helper Functions

  @doc """
  Ensures we have a pid from an agent identifier
  """
  @spec ensure_pid(pid() | atom()) :: pid()
  defp ensure_pid(agent) when is_pid(agent), do: agent
  defp ensure_pid(agent) when is_atom(agent), do: Process.whereis(process_name(agent))

  @doc """
  Schedules a sync operation
  """
  @spec schedule_sync(non_neg_integer()) :: reference()
  defp schedule_sync(interval) do
    Process.send_after(self(), :sync_timeout, interval)
  end

  @doc """
  Propagates a belief to all neighbors
  """
  @spec propagate_to_neighbors(BeliefAtom.t(), list(pid()), map()) :: map()
  defp propagate_to_neighbors(belief, neighbors, config) do
    # Use the belief propagation module
    BeliefPropagation.propagate_belief(belief, neighbors, [
      mode: :async,
      timeout: Map.get(config, :propagation_timeout, 5000)
    ])
  end

  @doc """
  Synchronizes belief sets with a neighbor
  """
  @spec sync_with_neighbor(pid(), pid(), BeliefSet.t(), map()) :: {BeliefSet.t(), BeliefSet.t()}
  defp sync_with_neighbor(self_pid, neighbor_pid, self_belief_set, config) do
    # Get neighbor's belief set
    case GenServer.call(neighbor_pid, :get_belief_set, Map.get(config, :sync_timeout, 5000)) do
      neighbor_belief_set when is_map(neighbor_belief_set) ->
        # Synchronize belief sets
        {updated_self, updated_neighbor} = BeliefPropagation.synchronize_beliefs(
          self_belief_set,
          neighbor_belief_set,
          [conflict_strategy: config.conflict_strategy]
        )
        
        # Update own belief set
        GenServer.cast(self_pid, {:update_belief_set, updated_self})
        
        # Update neighbor's belief set
        GenServer.cast(neighbor_pid, {:update_belief_set, updated_neighbor})
        
        {updated_self, updated_neighbor}
        
      _ ->
        # Failed to get neighbor's belief set
        {self_belief_set, nil}
    end
  rescue
    e ->
      # Error during synchronization
      {self_belief_set, nil}
  end
end