defmodule Automata.FoundationDemo do
  @moduledoc """
  A simplified demonstration of the Automata foundation architecture.
  
  This module contains minimalistic implementations of the key components
  to show how they work together in a distributed system.
  """
  
  @doc """
  Runs a demonstration of the foundation layer.
  """
  def run do
    IO.puts("Starting Automata Foundation Demo...")
    
    # Start the registry
    {:ok, _registry} = Registry.start_link(keys: :unique, name: AutomataRegistry)
    IO.puts("Registry started")
    
    # Start a world process
    {:ok, world_pid} = World.start_link("test-world")
    IO.puts("World started with PID: #{inspect(world_pid)}")
    
    # Start an agent
    {:ok, agent_pid} = Agent.start_link("test-agent", world_pid)
    IO.puts("Agent started with PID: #{inspect(agent_pid)}")
    
    # Check world state
    world_state = World.get_state(world_pid)
    IO.puts("World state: #{inspect(world_state)}")
    
    # Check agent state
    agent_state = Agent.get_state(agent_pid)
    IO.puts("Agent state: #{inspect(agent_state)}")
    
    # Simulate a tick
    Agent.tick(agent_pid)
    IO.puts("Agent ticked")
    
    # Check agent state after tick
    :timer.sleep(100) # Give it time to process
    agent_state_after = Agent.get_state(agent_pid)
    IO.puts("Agent state after tick: #{inspect(agent_state_after)}")
    
    IO.puts("Demo completed successfully!")
  end
end

defmodule World do
  @moduledoc "A simplified world implementation"
  use GenServer
  
  def start_link(id) do
    GenServer.start_link(__MODULE__, id)
  end
  
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end
  
  @impl true
  def init(id) do
    # Register world with registry
    Registry.register(AutomataRegistry, {:world, id}, nil)
    
    state = %{
      id: id,
      status: :ready,
      agents: [],
      started_at: System.system_time(:millisecond)
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  
  @impl true
  def handle_call({:register_agent, agent_pid}, _from, state) do
    # Add agent to world's agent list
    new_state = %{state | agents: [agent_pid | state.agents]}
    {:reply, :ok, new_state}
  end
end

defmodule Agent do
  @moduledoc "A simplified agent implementation"
  use GenServer
  
  def start_link(id, world_pid) do
    GenServer.start_link(__MODULE__, {id, world_pid})
  end
  
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end
  
  def tick(pid) do
    GenServer.cast(pid, :tick)
  end
  
  @impl true
  def init({id, world_pid}) do
    # Register agent with registry
    Registry.register(AutomataRegistry, {:agent, id}, nil)
    
    # Register with world
    GenServer.call(world_pid, {:register_agent, self()})
    
    state = %{
      id: id,
      world_pid: world_pid,
      status: :ready,
      tick_count: 0,
      started_at: System.system_time(:millisecond)
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  
  @impl true
  def handle_cast(:tick, state) do
    # Simulate processing a tick
    IO.puts("Agent #{state.id} processing tick #{state.tick_count}")
    
    # Update state with incremented tick count
    new_state = %{state | 
      tick_count: state.tick_count + 1
    }
    
    {:noreply, new_state}
  end
end
