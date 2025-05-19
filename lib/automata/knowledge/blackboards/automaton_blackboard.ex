defmodule Automaton.Blackboard do
  @moduledoc """
    The "brain" of each agent implemented with Automata is organized into a
    collection of discrete systems that communicate through an internal
    blackboard.

    The Node Blackboard for Individual Agent Postings (OBJECT_OF_ATTENTION, etc.)
    
    This blackboard is agent-specific, providing memory and state management for
    behavior tree nodes within a single agent. It serves as a memory pool for
    both short-term and persistent behavior state.
  """
  use GenServer
  
  # Type definitions for blackboard storage categories
  @type per_behavior_persistent :: map()
  @type per_behavior_short_term :: map()
  @type per_object :: map()
  @type per_object_per_behavior :: map()
  
  # Client API
  
  @doc """
  Starts a blackboard server for an agent.
  """
  def start_link(opts \\ []) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    name = via_tuple(agent_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Returns a tuple for accessing the blackboard server
  """
  def via_tuple(agent_id) do
    {:via, Registry, {:automaton_blackboard_registry, agent_id}}
  end
  
  @doc """
  Stores a value in the per-behavior persistent memory.
  Used for state that needs to persist between behavior tree executions.
  """
  def store_persistent(blackboard, behavior_id, key, value) do
    GenServer.call(blackboard, {:store_persistent, behavior_id, key, value})
  end
  
  @doc """
  Retrieves a value from the per-behavior persistent memory.
  """
  def get_persistent(blackboard, behavior_id, key) do
    GenServer.call(blackboard, {:get_persistent, behavior_id, key})
  end
  
  @doc """
  Stores a value in the per-behavior short-term memory.
  Used for state that only needs to exist during behavior execution.
  """
  def store_short_term(blackboard, behavior_id, key, value) do
    GenServer.call(blackboard, {:store_short_term, behavior_id, key, value})
  end
  
  @doc """
  Retrieves a value from the per-behavior short-term memory.
  """
  def get_short_term(blackboard, behavior_id, key) do
    GenServer.call(blackboard, {:get_short_term, behavior_id, key})
  end
  
  @doc """
  Stores object perception information.
  """
  def store_object_info(blackboard, object_id, key, value) do
    GenServer.call(blackboard, {:store_object_info, object_id, key, value})
  end
  
  @doc """
  Retrieves object perception information.
  """
  def get_object_info(blackboard, object_id, key) do
    GenServer.call(blackboard, {:get_object_info, object_id, key})
  end
  
  @doc """
  Stores information specific to a behavior's interaction with an object.
  """
  def store_behavior_object_info(blackboard, behavior_id, object_id, key, value) do
    GenServer.call(blackboard, {:store_behavior_object_info, behavior_id, object_id, key, value})
  end
  
  @doc """
  Retrieves information specific to a behavior's interaction with an object.
  """
  def get_behavior_object_info(blackboard, behavior_id, object_id, key) do
    GenServer.call(blackboard, {:get_behavior_object_info, behavior_id, object_id, key})
  end
  
  @doc """
  Clears all short-term memory for a specific behavior.
  Called when a behavior completes execution.
  """
  def clear_short_term(blackboard, behavior_id) do
    GenServer.call(blackboard, {:clear_short_term, behavior_id})
  end
  
  @doc """
  Subscribes to changes in the blackboard.
  """
  def subscribe(blackboard, category, ids, key) do
    GenServer.cast(blackboard, {:subscribe, self(), category, ids, key})
  end
  
  @doc """
  Unsubscribes from changes in the blackboard.
  """
  def unsubscribe(blackboard, category, ids, key) do
    GenServer.cast(blackboard, {:unsubscribe, self(), category, ids, key})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    
    initial_state = %{
      agent_id: agent_id,
      per_behavior_persistent: %{},
      per_behavior_short_term: %{},
      per_object: %{},
      per_object_per_behavior: %{},
      subscribers: %{},
      opts: opts
    }
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:store_persistent, behavior_id, key, value}, _from, state) do
    behavior_data = get_in(state.per_behavior_persistent, [behavior_id]) || %{}
    updated_data = Map.put(behavior_data, key, value)
    
    new_persistent = Map.put(state.per_behavior_persistent, behavior_id, updated_data)
    new_state = %{state | per_behavior_persistent: new_persistent}
    
    notify_subscribers(state.subscribers, :persistent, [behavior_id], key, value)
    
    {:reply, {:ok, value}, new_state}
  end
  
  @impl true
  def handle_call({:get_persistent, behavior_id, key}, _from, state) do
    behavior_data = get_in(state.per_behavior_persistent, [behavior_id]) || %{}
    value = Map.get(behavior_data, key)
    
    {:reply, {:ok, value}, state}
  end
  
  @impl true
  def handle_call({:store_short_term, behavior_id, key, value}, _from, state) do
    behavior_data = get_in(state.per_behavior_short_term, [behavior_id]) || %{}
    updated_data = Map.put(behavior_data, key, value)
    
    new_short_term = Map.put(state.per_behavior_short_term, behavior_id, updated_data)
    new_state = %{state | per_behavior_short_term: new_short_term}
    
    notify_subscribers(state.subscribers, :short_term, [behavior_id], key, value)
    
    {:reply, {:ok, value}, new_state}
  end
  
  @impl true
  def handle_call({:get_short_term, behavior_id, key}, _from, state) do
    behavior_data = get_in(state.per_behavior_short_term, [behavior_id]) || %{}
    value = Map.get(behavior_data, key)
    
    {:reply, {:ok, value}, state}
  end
  
  @impl true
  def handle_call({:store_object_info, object_id, key, value}, _from, state) do
    object_data = get_in(state.per_object, [object_id]) || %{}
    updated_data = Map.put(object_data, key, value)
    
    new_per_object = Map.put(state.per_object, object_id, updated_data)
    new_state = %{state | per_object: new_per_object}
    
    notify_subscribers(state.subscribers, :object, [object_id], key, value)
    
    {:reply, {:ok, value}, new_state}
  end
  
  @impl true
  def handle_call({:get_object_info, object_id, key}, _from, state) do
    object_data = get_in(state.per_object, [object_id]) || %{}
    value = Map.get(object_data, key)
    
    {:reply, {:ok, value}, state}
  end
  
  @impl true
  def handle_call({:store_behavior_object_info, behavior_id, object_id, key, value}, _from, state) do
    behavior_data = get_in(state.per_object_per_behavior, [behavior_id]) || %{}
    object_data = get_in(behavior_data, [object_id]) || %{}
    updated_object_data = Map.put(object_data, key, value)
    
    updated_behavior_data = Map.put(behavior_data, object_id, updated_object_data)
    new_per_object_per_behavior = Map.put(state.per_object_per_behavior, behavior_id, updated_behavior_data)
    new_state = %{state | per_object_per_behavior: new_per_object_per_behavior}
    
    notify_subscribers(state.subscribers, :behavior_object, [behavior_id, object_id], key, value)
    
    {:reply, {:ok, value}, new_state}
  end
  
  @impl true
  def handle_call({:get_behavior_object_info, behavior_id, object_id, key}, _from, state) do
    value = 
      state.per_object_per_behavior
      |> get_in([behavior_id])
      |> case do
        nil -> nil
        behavior_data -> get_in(behavior_data, [object_id, key])
      end
    
    {:reply, {:ok, value}, state}
  end
  
  @impl true
  def handle_call({:clear_short_term, behavior_id}, _from, state) do
    new_short_term = Map.delete(state.per_behavior_short_term, behavior_id)
    new_state = %{state | per_behavior_short_term: new_short_term}
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_cast({:subscribe, pid, category, ids, key}, state) do
    subscription_key = {category, ids, key}
    subscribers = Map.get(state.subscribers, subscription_key, [])
    
    unless Enum.member?(subscribers, pid) do
      Process.monitor(pid)
      
      new_subscribers = Map.put(
        state.subscribers,
        subscription_key,
        [pid | subscribers]
      )
      
      {:noreply, %{state | subscribers: new_subscribers}}
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast({:unsubscribe, pid, category, ids, key}, state) do
    subscription_key = {category, ids, key}
    subscribers = Map.get(state.subscribers, subscription_key, [])
    
    if Enum.member?(subscribers, pid) do
      new_subscribers = Map.put(
        state.subscribers,
        subscription_key,
        List.delete(subscribers, pid)
      )
      
      {:noreply, %{state | subscribers: new_subscribers}}
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove the dead subscriber from all subscription lists
    new_subscribers = Enum.reduce(state.subscribers, %{}, fn {key, subscribers}, acc ->
      updated_subscribers = List.delete(subscribers, pid)
      Map.put(acc, key, updated_subscribers)
    end)
    
    {:noreply, %{state | subscribers: new_subscribers}}
  end
  
  # Private helper functions
  
  defp notify_subscribers(subscribers, category, ids, key, value) do
    subscription_key = {category, ids, key}
    
    case Map.get(subscribers, subscription_key) do
      nil -> :ok
      subscriber_list ->
        Enum.each(subscriber_list, fn pid ->
          Process.send(pid, {:blackboard_update, category, ids, key, value}, [:noconnect])
        end)
    end
  end
  
  defmacro __using__(opts) do
    quote do
      alias Automaton.Blackboard
      
      @doc """
      Returns the current blackboard for this agent.
      """
      def blackboard() do
        agent_id = case Process.info(self(), :registered_name) do
          {:registered_name, name} -> name
          _ -> self()
        end
        
        Automaton.Blackboard.via_tuple(agent_id)
      end
      
      @doc """
      Stores a persistent value for a behavior.
      """
      def store_persistent(behavior_id, key, value) do
        Automaton.Blackboard.store_persistent(blackboard(), behavior_id, key, value)
      end
      
      @doc """
      Retrieves a persistent value for a behavior.
      """
      def get_persistent(behavior_id, key) do
        Automaton.Blackboard.get_persistent(blackboard(), behavior_id, key)
      end
      
      @doc """
      Stores a short-term value for a behavior.
      """
      def store_short_term(behavior_id, key, value) do
        Automaton.Blackboard.store_short_term(blackboard(), behavior_id, key, value)
      end
      
      @doc """
      Retrieves a short-term value for a behavior.
      """
      def get_short_term(behavior_id, key) do
        Automaton.Blackboard.get_short_term(blackboard(), behavior_id, key)
      end
      
      @doc """
      Stores object perception information.
      """
      def store_object_info(object_id, key, value) do
        Automaton.Blackboard.store_object_info(blackboard(), object_id, key, value)
      end
      
      @doc """
      Retrieves object perception information.
      """
      def get_object_info(object_id, key) do
        Automaton.Blackboard.get_object_info(blackboard(), object_id, key)
      end
      
      @doc """
      Stores information specific to a behavior's interaction with an object.
      """
      def store_behavior_object_info(behavior_id, object_id, key, value) do
        Automaton.Blackboard.store_behavior_object_info(blackboard(), behavior_id, object_id, key, value)
      end
      
      @doc """
      Retrieves information specific to a behavior's interaction with an object.
      """
      def get_behavior_object_info(behavior_id, object_id, key) do
        Automaton.Blackboard.get_behavior_object_info(blackboard(), behavior_id, object_id, key)
      end
      
      @doc """
      Clears all short-term memory for a specific behavior.
      """
      def clear_short_term(behavior_id) do
        Automaton.Blackboard.clear_short_term(blackboard(), behavior_id)
      end
      
      @doc """
      Subscribes to changes in the blackboard.
      """
      def subscribe_to_changes(category, ids, key) do
        Automaton.Blackboard.subscribe(blackboard(), category, ids, key)
      end
      
      @doc """
      Unsubscribes from changes in the blackboard.
      """
      def unsubscribe_from_changes(category, ids, key) do
        Automaton.Blackboard.unsubscribe(blackboard(), category, ids, key)
      end
    end
  end
end