defmodule Automata.Blackboard do
  @moduledoc """
    A global Blackboard for knowledge representations

    Memory and Interaction Protocols

      With large trees, we face another challenge: storage. In an ideal world,
    each AI would have an entire tree allocated to it, with each behavior having
    a persistent amount of storage allocated to it, so that any state necessary
    for its functioning would simply always be available. However, assuming
    about 100 actors allocated at a time about 60 behaviors in the average tree,
    and each behavior taking up about 32 bytes of memory, this gives us about
    192K of persistent behavior storage. Clearly, as the tree grows even further
    this becomes even more of a memory burden, initially for a platform like
    the Xbox.

      We can cut down on this burden considerably if we note that in the vast majority
    of cases, we are only really interested in a small number of behaviors - those
    that are actually running (the current leaf, its parent, it grandparent and so
    on up the tree). The obvious optimization to make is to create a small pool of
    state memory for each actor divided into chunks corresponding to levels of the
    hierarchy. The tree becomes a free-standing static structure (i.e. is not
    allocated per actor) and the behaviors themselves become code fragments that
    operate on a chunk. (The same sort of memory usage can be obtained in an object
    oriented way if parent behavior objects only instantiate their children at the
    time that the children are selected. This was the approach taken in [Alt04]).
    Our memory usage suddenly becomes far more efficient: 100 actors times 64 bytes
    (an upper bound on the amount behavior storage needed) times 4 layers (in the
    case of Halo 2), or about 25K. Very importantly, this number only grows with the
    maximum depth of the tree, not the number of behaviors.

    This leaves us with another problem however, the problem of persistent
    behavior state. There are numerous instances in the Halo 2 repertoire
    where behaviors are disallowed for a certain amount of time after their
    last successful performance (grenade-throwing, for example). In the ideal
    world, this information about "last execution time" would be stored in the
    persistently allocated grenade behavior. However, as that storage in the
    above scheme is only temporarily allocated, we need somewhere else to
    store the persistent behavior data.

    There is an even worse example - what about per-target persistent behavior
    state? Consider the search behavior. Search would like to indicate when it
    fails in its operation on a particular target. This lets the actor know to
    forget about that target and concentrate its efforts elsewhere. However,
    this doesn't preclude the actor going and searching for a different target -
    so the behavior cannot simply be turned off once it has failed.

    Memory - in the psychological sense of stored information on past actions
    and events, not in the sense of RAM - presents a problem that is inherent to
    the tree structure. The solution in any world besides the ideal one is to
    create a memory pool - or a number of memory pools - outside the tree to act
    as its storage proxy.

    When we consider our memory needs more generally, we can quickly distinguish
    at least four different categories:

      Per-behavior (persistent): grenade throws, recent vehicle actions
      Per-behavior (short-term): state lost when the behavior finishes
      Per-object: perception information, last seen position, last seen orientation
      Per-object per-behavior: last-meleed time, search failures, pathfinding-to failures
  """
  use GenServer
  
  @registry_name :automata_blackboard_registry

  # Client API
  
  @doc """
  Starts a blackboard server with a given name.
  The name will be used to register the blackboard in the registry.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, :global_blackboard)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end
  
  @doc """
  Generates a via tuple for registry lookups
  """
  def via_tuple(name), do: {:via, Registry, {@registry_name, name}}
  
  @doc """
  Writes a value to the blackboard at the given key path.
  The key path is a list of keys that form a path in the nested map.
  Returns {:ok, new_value} on success.
  """
  def write(blackboard, key_path, value) when is_list(key_path) do
    GenServer.call(blackboard, {:write, key_path, value})
  end
  
  @doc """
  Reads a value from the blackboard at the given key path.
  Returns {:ok, value} if the key exists, or {:error, :not_found} otherwise.
  """
  def read(blackboard, key_path) when is_list(key_path) do
    GenServer.call(blackboard, {:read, key_path})
  end
  
  @doc """
  Deletes a value from the blackboard at the given key path.
  Returns {:ok, value} if the key was deleted, or {:error, :not_found} otherwise.
  """
  def delete(blackboard, key_path) when is_list(key_path) do
    GenServer.call(blackboard, {:delete, key_path})
  end
  
  @doc """
  Subscribes to changes at a specific key path.
  When the value at the path changes, the subscriber will receive a message in the format:
  {:blackboard_update, key_path, new_value}
  """
  def subscribe(blackboard, key_path) when is_list(key_path) do
    GenServer.cast(blackboard, {:subscribe, self(), key_path})
  end
  
  @doc """
  Unsubscribes from changes at a specific key path.
  """
  def unsubscribe(blackboard, key_path) when is_list(key_path) do
    GenServer.cast(blackboard, {:unsubscribe, self(), key_path})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    # In a complete implementation, this would use a proper CRDT library
    # For now, we'll use a simple map with a version counter as a basic mechanism
    initial_state = %{
      data: %{},
      version: 0,
      subscribers: %{}, # Map of key_paths to lists of subscriber PIDs
      opts: opts
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:write, key_path, value}, _from, state) do
    # Update the nested map with the new value
    new_data = update_in_path(state.data, key_path, fn _ -> value end)
    
    # Increment version for change tracking
    new_state = %{state | data: new_data, version: state.version + 1}
    
    # Notify subscribers of this key_path
    notify_subscribers(state.subscribers, key_path, value)
    
    {:reply, {:ok, value}, new_state}
  end
  
  @impl true
  def handle_call({:read, key_path}, _from, state) do
    case get_in_path(state.data, key_path) do
      {:ok, value} -> {:reply, {:ok, value}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:delete, key_path}, _from, state) do
    case get_in_path(state.data, key_path) do
      {:ok, value} ->
        new_data = delete_in_path(state.data, key_path)
        new_state = %{state | data: new_data, version: state.version + 1}
        notify_subscribers(state.subscribers, key_path, nil)
        {:reply, {:ok, value}, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_cast({:subscribe, pid, key_path}, state) do
    # Add subscriber to the list for this key_path
    subscribers_for_path = Map.get(state.subscribers, key_path, [])
    
    unless Enum.member?(subscribers_for_path, pid) do
      # Monitor the subscriber to clean up if they die
      Process.monitor(pid)
      
      # Add to subscribers list
      new_subscribers = Map.put(
        state.subscribers,
        key_path,
        [pid | subscribers_for_path]
      )
      
      {:noreply, %{state | subscribers: new_subscribers}}
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast({:unsubscribe, pid, key_path}, state) do
    subscribers_for_path = Map.get(state.subscribers, key_path, [])
    
    if Enum.member?(subscribers_for_path, pid) do
      # Remove from subscribers list
      new_subscribers = Map.put(
        state.subscribers,
        key_path,
        List.delete(subscribers_for_path, pid)
      )
      
      {:noreply, %{state | subscribers: new_subscribers}}
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove the dead subscriber from all subscription lists
    new_subscribers = Enum.reduce(state.subscribers, %{}, fn {key_path, subscribers}, acc ->
      updated_subscribers = List.delete(subscribers, pid)
      Map.put(acc, key_path, updated_subscribers)
    end)
    
    {:noreply, %{state | subscribers: new_subscribers}}
  end
  
  # Private helper functions
  
  # Update a value in a nested map based on a key path
  defp update_in_path(data, [key], update_fn) do
    Map.put(data, key, update_fn.(Map.get(data, key)))
  end
  
  defp update_in_path(data, [key | rest], update_fn) do
    sub_map = Map.get(data, key, %{})
    Map.put(data, key, update_in_path(sub_map, rest, update_fn))
  end
  
  # Get a value from a nested map based on a key path
  defp get_in_path(data, [key]) do
    if Map.has_key?(data, key) do
      {:ok, Map.get(data, key)}
    else
      {:error, :not_found}
    end
  end
  
  defp get_in_path(data, [key | rest]) do
    case Map.fetch(data, key) do
      {:ok, sub_data} -> get_in_path(sub_data, rest)
      :error -> {:error, :not_found}
    end
  end
  
  # Delete a value from a nested map based on a key path
  defp delete_in_path(data, [key]) do
    Map.delete(data, key)
  end
  
  defp delete_in_path(data, [key | rest]) do
    case Map.fetch(data, key) do
      {:ok, sub_data} ->
        updated_sub_data = delete_in_path(sub_data, rest)
        Map.put(data, key, updated_sub_data)
      :error ->
        data
    end
  end
  
  # Notify subscribers of changes
  defp notify_subscribers(subscribers, key_path, value) do
    case Map.get(subscribers, key_path) do
      nil -> :ok
      subscriber_list ->
        Enum.each(subscriber_list, fn pid ->
          Process.send(pid, {:blackboard_update, key_path, value}, [:noconnect])
        end)
    end
  end
  
  defmacro __using__(opts) do
    quote do
      alias Automata.Blackboard
      
      def get_blackboard() do
        name = unquote(opts[:name] || :global_blackboard)
        Automata.Blackboard.via_tuple(name)
      end
      
      def write_to_blackboard(key_path, value) when is_list(key_path) do
        Automata.Blackboard.write(get_blackboard(), key_path, value)
      end
      
      def read_from_blackboard(key_path) when is_list(key_path) do
        Automata.Blackboard.read(get_blackboard(), key_path)
      end
      
      def delete_from_blackboard(key_path) when is_list(key_path) do
        Automata.Blackboard.delete(get_blackboard(), key_path)
      end
      
      def subscribe_to_blackboard(key_path) when is_list(key_path) do
        Automata.Blackboard.subscribe(get_blackboard(), key_path)
      end
      
      def unsubscribe_from_blackboard(key_path) when is_list(key_path) do
        Automata.Blackboard.unsubscribe(get_blackboard(), key_path)
      end
    end
  end
end