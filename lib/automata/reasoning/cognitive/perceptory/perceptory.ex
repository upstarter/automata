defmodule Automata.Perceptory do
  @moduledoc """
    Classification hierarchy (Perception System) Once the stimulus from the world
    has been "sensed," it can then be "perceived." The distinction between sensing
    and perceiving is important. An agent, for example, may "sense" an acoustic
    event, but it is up to the perception system to recognize it as an instance of a
    specific type of acoustic event that has some meaning to the agent. A segment of
    agents may interpret an UtteranceDataRecord as just another noise, but one should
    classify the utterance as the word "hello". Similarly with multicast, unicast,
    broadcast events. Thus, it is within the Perception System that each agent assigns a
    unique "meaning" to events in the world.

    Once the stimulus from the world has been "sensed" it can then be "perceived."
    The distinction between sensing and perceiving is important. A agent may "sense"
    an acoustic event, but it is up to the Perception System to recognize and
    process the event as something that has meaning to the agent. Thus, it is within
    the Perception System that "meaning" is assigned to events in the world.
  """
  use GenServer
  alias Automata.Perceptory.PerceptTree
  alias Automata.Perceptory.PercepMem
  
  # Client API
  
  @doc """
  Starts a perceptory server for an agent.
  """
  def start_link(opts \\ []) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    name = via_tuple(agent_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Returns a tuple for accessing the perceptory server.
  """
  def via_tuple(agent_id) do
    {:via, Registry, {:perceptory_registry, agent_id}}
  end
  
  @doc """
  Processes a sensory input and returns a perception memory.
  """
  def perceive(perceptory, sensory_input) do
    GenServer.call(perceptory, {:perceive, sensory_input})
  end
  
  @doc """
  Retrieves all active perception memories.
  """
  def get_active_memories(perceptory) do
    GenServer.call(perceptory, :get_active_memories)
  end
  
  @doc """
  Adds a new percept to the percept tree.
  """
  def add_percept(perceptory, percept, parent_path \\ []) do
    GenServer.call(perceptory, {:add_percept, percept, parent_path})
  end
  
  @doc """
  Sets the attention focus of the perceptory system.
  """
  def set_attention(perceptory, focus) do
    GenServer.cast(perceptory, {:set_attention, focus})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    
    initial_state = %{
      agent_id: agent_id,
      percept_tree: PerceptTree.new(),
      active_memories: %{},
      attention_focus: nil,
      memory_lifetime: Keyword.get(opts, :memory_lifetime, 10_000), # In milliseconds
      opts: opts
    }
    
    # Schedule cleanup of old memories
    schedule_memory_cleanup(initial_state.memory_lifetime)
    
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:perceive, sensory_input}, _from, state) do
    # Process the sensory input through the percept tree
    {matches, updated_tree} = PerceptTree.process(state.percept_tree, sensory_input)
    
    # Create a perception memory from the matches
    timestamp = :os.system_time(:millisecond)
    memory = PercepMem.new(sensory_input, matches, timestamp)
    
    # Try to match this memory with existing memories
    {memory_id, updated_memories} = match_or_create_memory(memory, state.active_memories)
    
    {:reply, {memory_id, memory}, %{state | 
      percept_tree: updated_tree,
      active_memories: updated_memories
    }}
  end
  
  @impl true
  def handle_call(:get_active_memories, _from, state) do
    {:reply, state.active_memories, state}
  end
  
  @impl true
  def handle_call({:add_percept, percept, parent_path}, _from, state) do
    updated_tree = PerceptTree.add_percept(state.percept_tree, percept, parent_path)
    {:reply, :ok, %{state | percept_tree: updated_tree}}
  end
  
  @impl true
  def handle_cast({:set_attention, focus}, state) do
    {:noreply, %{state | attention_focus: focus}}
  end
  
  @impl true
  def handle_info(:cleanup_memories, state) do
    # Remove expired memories
    now = :os.system_time(:millisecond)
    threshold = now - state.memory_lifetime
    
    updated_memories = Enum.reduce(state.active_memories, %{}, fn {id, memory}, acc ->
      if PercepMem.last_updated(memory) < threshold do
        # Memory has expired
        acc
      else
        Map.put(acc, id, memory)
      end
    end)
    
    # Reschedule cleanup
    schedule_memory_cleanup(state.memory_lifetime)
    
    {:noreply, %{state | active_memories: updated_memories}}
  end
  
  # Private helpers
  
  defp match_or_create_memory(new_memory, existing_memories) do
    # Try to find a matching memory
    case find_matching_memory(new_memory, existing_memories) do
      {id, matching_memory} ->
        # Update the matching memory
        updated_memory = PercepMem.merge(matching_memory, new_memory)
        {id, Map.put(existing_memories, id, updated_memory)}
        
      nil ->
        # Create a new memory
        id = generate_memory_id()
        {id, Map.put(existing_memories, id, new_memory)}
    end
  end
  
  defp find_matching_memory(new_memory, existing_memories) do
    Enum.find(existing_memories, fn {_id, memory} -> 
      PercepMem.match(memory, new_memory)
    end)
  end
  
  defp generate_memory_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp schedule_memory_cleanup(lifetime) do
    # Schedule cleanup at half the lifetime interval
    cleanup_interval = max(lifetime div 2, 1000)
    Process.send_after(self(), :cleanup_memories, cleanup_interval)
  end
  
  defmacro __using__(opts) do
    quote do
      alias Automata.Perceptory
      
      @doc """
      Returns the perceptory for this agent.
      """
      def perceptory() do
        agent_id = case Process.info(self(), :registered_name) do
          {:registered_name, name} -> name
          _ -> self()
        end
        
        Automata.Perceptory.via_tuple(agent_id)
      end
      
      @doc """
      Processes a sensory input and returns a perception memory.
      """
      def perceive(sensory_input) do
        Automata.Perceptory.perceive(perceptory(), sensory_input)
      end
      
      @doc """
      Retrieves all active perception memories.
      """
      def get_active_memories() do
        Automata.Perceptory.get_active_memories(perceptory())
      end
      
      @doc """
      Adds a new percept to the percept tree.
      """
      def add_percept(percept, parent_path \\ []) do
        Automata.Perceptory.add_percept(perceptory(), percept, parent_path)
      end
      
      @doc """
      Sets the attention focus of the perceptory system.
      """
      def set_attention(focus) do
        Automata.Perceptory.set_attention(perceptory(), focus)
      end
    end
  end
end