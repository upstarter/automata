defmodule Automata.Infrastructure.State.DistributedBlackboard do
  @moduledoc """
  Implements a distributed blackboard using Delta CRDTs.
  
  The blackboard provides a shared memory space that works across distributed
  nodes with eventual consistency guarantees. It handles:
  
  - Eventually consistent state across nodes
  - Automatic conflict resolution
  - Namespace-based segmentation of state
  - Subscription to state changes
  """
  use GenServer
  require Logger

  defmodule Stats do
    @moduledoc "Statistics tracking for the blackboard"
    defstruct reads: 0, 
              writes: 0, 
              removes: 0, 
              conflicts: 0, 
              segments: %{}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.info("Starting Distributed Blackboard")
    
    # Initialize CRDT
    {:ok, crdt} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap)
    
    # Set up node synchronization
    :net_kernel.monitor_nodes(true)
    sync_with_all_nodes(crdt)
    
    # Set up subscription registry
    {:ok, _} = Registry.start_link(
      keys: :duplicate, 
      name: Automata.Infrastructure.State.BlackboardRegistry
    )
    
    # Initialize state
    {:ok, %{
      crdt: crdt,
      stats: %Stats{},
      last_sync: DateTime.utc_now()
    }}
  end

  @impl true
  def handle_call({:get, key}, _from, %{crdt: crdt, stats: stats} = state) do
    value = DeltaCrdt.read(crdt)[key]
    
    # Update stats
    segment = get_segment(key)
    segment_stats = Map.get(stats.segments, segment, %{reads: 0, writes: 0, removes: 0})
    updated_segment_stats = %{segment_stats | reads: segment_stats.reads + 1}
    updated_segments = Map.put(stats.segments, segment, updated_segment_stats)
    updated_stats = %{stats | reads: stats.reads + 1, segments: updated_segments}
    
    {:reply, value, %{state | stats: updated_stats}}
  end

  @impl true
  def handle_call({:put, key, value, opts}, _from, %{crdt: crdt, stats: stats} = state) do
    prev_value = DeltaCrdt.read(crdt)[key]
    
    :ok = DeltaCrdt.mutate(crdt, :add, [key, value])
    
    # Update stats
    segment = get_segment(key)
    segment_stats = Map.get(stats.segments, segment, %{reads: 0, writes: 0, removes: 0})
    updated_segment_stats = %{segment_stats | writes: segment_stats.writes + 1}
    updated_segments = Map.put(stats.segments, segment, updated_segment_stats)
    
    # Check if this was a conflicting update
    conflict = prev_value != nil && prev_value != value
    updated_conflicts = if conflict, do: stats.conflicts + 1, else: stats.conflicts
    
    updated_stats = %{stats | 
      writes: stats.writes + 1, 
      conflicts: updated_conflicts,
      segments: updated_segments
    }
    
    # Notify subscribers if enabled
    if Keyword.get(opts, :notify, true) do
      notify_subscribers(key, :put, prev_value, value)
    end
    
    # Record the operation
    if Keyword.get(opts, :record_history, false) do
      record_operation(key, :put, prev_value, value)
    end
    
    {:reply, :ok, %{state | stats: updated_stats}}
  end

  @impl true
  def handle_call({:remove, key, opts}, _from, %{crdt: crdt, stats: stats} = state) do
    prev_value = DeltaCrdt.read(crdt)[key]
    
    :ok = DeltaCrdt.mutate(crdt, :remove, [key])
    
    # Update stats
    segment = get_segment(key)
    segment_stats = Map.get(stats.segments, segment, %{reads: 0, writes: 0, removes: 0})
    updated_segment_stats = %{segment_stats | removes: segment_stats.removes + 1}
    updated_segments = Map.put(stats.segments, segment, updated_segment_stats)
    updated_stats = %{stats | removes: stats.removes + 1, segments: updated_segments}
    
    # Notify subscribers if enabled
    if Keyword.get(opts, :notify, true) do
      notify_subscribers(key, :remove, prev_value, nil)
    end
    
    # Record the operation
    if Keyword.get(opts, :record_history, false) do
      record_operation(key, :remove, prev_value, nil)
    end
    
    {:reply, :ok, %{state | stats: updated_stats}}
  end

  @impl true
  def handle_call({:get_segment, segment}, _from, %{crdt: crdt} = state) do
    values = DeltaCrdt.read(crdt)
      |> Enum.filter(fn {key, _value} -> get_segment(key) == segment end)
      |> Map.new()
      
    {:reply, values, state}
  end

  @impl true
  def handle_call(:get_all, _from, %{crdt: crdt} = state) do
    values = DeltaCrdt.read(crdt)
    {:reply, values, state}
  end

  @impl true
  def handle_call(:get_stats, _from, %{stats: stats} = state) do
    {:reply, stats, state}
  end

  @impl true
  def handle_call({:subscribe, pattern}, {pid, _}, state) do
    Registry.register(
      Automata.Infrastructure.State.BlackboardRegistry, 
      pattern, 
      pid
    )
    
    Process.monitor(pid)
    
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:nodeup, node}, %{crdt: crdt} = state) do
    Logger.info("Node joined: #{node}, syncing CRDT")
    add_node_to_crdt(crdt, node)
    {:noreply, %{state | last_sync: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("Node left: #{node}")
    # Nodes will automatically be removed from the CRDT replication
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Clean up subscriptions when a subscriber process dies
    Registry.unregister_match(
      Automata.Infrastructure.State.BlackboardRegistry,
      pid,
      :_
    )
    
    {:noreply, state}
  end

  @doc """
  Gets a value from the distributed blackboard.
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Puts a value in the distributed blackboard.
  
  Options:
  - notify: boolean, whether to notify subscribers (default: true)
  - record_history: boolean, whether to record operation in history (default: false)
  """
  def put(key, value, opts \\ []) do
    GenServer.call(__MODULE__, {:put, key, value, opts})
  end

  @doc """
  Removes a value from the distributed blackboard.
  
  Options:
  - notify: boolean, whether to notify subscribers (default: true)
  - record_history: boolean, whether to record operation in history (default: false)
  """
  def remove(key, opts \\ []) do
    GenServer.call(__MODULE__, {:remove, key, opts})
  end
  
  @doc """
  Gets all values from a specific segment of the blackboard.
  
  A segment is determined by the first element of the key tuple.
  """
  def get_segment(segment) when is_atom(segment) do
    GenServer.call(__MODULE__, {:get_segment, segment})
  end

  @doc """
  Gets all values from the distributed blackboard.
  """
  def get_all do
    GenServer.call(__MODULE__, :get_all)
  end
  
  @doc """
  Gets statistics about blackboard usage.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Subscribes to changes in the blackboard matching the given pattern.
  
  The pattern can be:
  - :all - All changes
  - {:segment, segment_name} - Changes to a specific segment
  - key - Changes to a specific key
  """
  def subscribe(pattern) do
    GenServer.call(__MODULE__, {:subscribe, pattern})
  end
  
  # Private functions
  
  defp get_segment(key) when is_tuple(key) do
    elem(key, 0)
  end
  
  defp get_segment(_), do: :other
  
  defp sync_with_all_nodes(crdt) do
    Node.list()
    |> Enum.each(fn node -> add_node_to_crdt(crdt, node) end)
  end

  defp add_node_to_crdt(crdt, node) do
    case :rpc.call(node, Process, :whereis, [__MODULE__]) do
      pid when is_pid(pid) ->
        case :rpc.call(node, Process, :info, [pid]) do
          {:badrpc, _} -> :ok
          info when is_list(info) ->
            remote_crdt = :proplists.get_value(:dictionary, info)
                          |> Enum.find_value(fn
                              {{DeltaCrdt, _key}, remote_crdt} -> remote_crdt
                              _ -> nil
                            end)
            if remote_crdt do
              DeltaCrdt.add_neighbours(crdt, [remote_crdt])
              Logger.debug("Added #{node} to CRDT neighbours")
            end
        end
      _ -> :ok
    end
  end
  
  defp notify_subscribers(key, operation, old_value, new_value) do
    segment = get_segment(key)
    timestamp = System.system_time(:millisecond)
    
    # Create change notification
    change = %{
      key: key,
      operation: operation,
      old_value: old_value,
      new_value: new_value,
      timestamp: timestamp,
      node: Node.self()
    }
    
    # Notify subscribers to this specific key
    Registry.dispatch(
      Automata.Infrastructure.State.BlackboardRegistry,
      key,
      fn entries ->
        for {pid, _} <- entries do
          send(pid, {:blackboard_change, change})
        end
      end
    )
    
    # Notify subscribers to this segment
    Registry.dispatch(
      Automata.Infrastructure.State.BlackboardRegistry,
      {:segment, segment},
      fn entries ->
        for {pid, _} <- entries do
          send(pid, {:blackboard_change, change})
        end
      end
    )
    
    # Notify subscribers to all changes
    Registry.dispatch(
      Automata.Infrastructure.State.BlackboardRegistry,
      :all,
      fn entries ->
        for {pid, _} <- entries do
          send(pid, {:blackboard_change, change})
        end
      end
    )
  end
  
  defp record_operation(key, operation, old_value, new_value) do
    timestamp = System.system_time(:millisecond)
    history_key = {:history, timestamp, key}
    
    # Create history entry
    entry = %{
      key: key,
      operation: operation,
      old_value: old_value,
      new_value: new_value,
      timestamp: timestamp,
      node: Node.self()
    }
    
    # Store in blackboard without notifications to avoid recursion
    GenServer.call(__MODULE__, {:put, history_key, entry, [notify: false]})
  end
end