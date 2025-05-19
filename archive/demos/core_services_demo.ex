defmodule Automata.CoreServicesDemo do
  @moduledoc """
  A demonstration of Automata's Core Services Phase components.
  
  This module shows how configuration, state management, and event-driven
  communication work together to create a robust foundation for autonomous agents.
  """
  
  @doc """
  Runs the demonstration.
  """
  def run do
    IO.puts("Starting Core Services Phase Demo...")
    
    mock_config_system()
    
    demo_distributed_blackboard()
    
    demo_event_system()
    
    IO.puts("\nCore Services Phase Demo completed successfully!")
  end
  
  defp mock_config_system do
    IO.puts("\n=== Configuration System Demo ===")
    
    # Start registry for config changes
    {:ok, _} = Registry.start_link(keys: :duplicate, name: Automata.Infrastructure.Config.Registry)
    
    # Create a mock config provider
    config_provider = MockConfigProvider.start()
    
    # Demonstrate config validation
    world_config = %{
      name: "Test World",
      description: "A test world for demonstration",
      tick_rate: 100,
      persistence_enabled: true
    }
    
    IO.puts("World config created: #{inspect(world_config)}")
    
    # Mock validation
    valid_config = Map.put(world_config, :id, "world-#{:rand.uniform(1000)}")
    IO.puts("World config validated successfully: #{inspect(valid_config)}")
    
    # Update the config
    updated_config = Map.put(valid_config, :tick_rate, 200)
    IO.puts("Updated world config: #{inspect(updated_config)}")
    
    # Clean up
    Process.exit(config_provider, :normal)
  end
  
  defp demo_distributed_blackboard do
    IO.puts("\n=== Distributed Blackboard Demo ===")
    
    # Start registry for blackboard notifications
    {:ok, _} = Registry.start_link(
      keys: :duplicate, 
      name: Automata.Infrastructure.State.BlackboardRegistry
    )
    
    # Create a mock blackboard
    blackboard = MockBlackboard.start()
    
    # Subscribe to changes
    Registry.register(
      Automata.Infrastructure.State.BlackboardRegistry, 
      :all, 
      self()
    )
    
    # Put values in the blackboard
    IO.puts("Storing values in blackboard...")
    MockBlackboard.put(blackboard, {:world, "world1"}, %{name: "World 1", status: :active})
    MockBlackboard.put(blackboard, {:agent, "agent1"}, %{name: "Agent 1", world: "world1"})
    
    # Wait for notifications
    receive_all_notifications()
    
    # Get values from blackboard
    world = MockBlackboard.get(blackboard, {:world, "world1"})
    IO.puts("Retrieved world: #{inspect(world)}")
    
    agent = MockBlackboard.get(blackboard, {:agent, "agent1"})
    IO.puts("Retrieved agent: #{inspect(agent)}")
    
    # Clean up
    Process.exit(blackboard, :normal)
  end
  
  defp demo_event_system do
    IO.puts("\n=== Event System Demo ===")
    
    # Start the event bus
    event_bus = MockEventBus.start()
    
    # Start event handlers
    handler1 = MockEventHandler.start("Handler1", [:world_event])
    handler2 = MockEventHandler.start("Handler2", [:agent_event])
    handler3 = MockEventHandler.start("Handler3", [:all])
    
    # Publish events
    IO.puts("Publishing events...")
    
    MockEventBus.publish(event_bus, %{
      type: :world_event,
      payload: %{world_id: "world1", action: :created},
      metadata: %{timestamp: System.system_time(:millisecond)}
    })
    
    MockEventBus.publish(event_bus, %{
      type: :agent_event,
      payload: %{agent_id: "agent1", action: :started},
      metadata: %{timestamp: System.system_time(:millisecond)}
    })
    
    # Wait for handlers to process events
    Process.sleep(100)
    
    # Check handler states
    handler1_state = MockEventHandler.get_state(handler1)
    IO.puts("Handler1 state: #{inspect(handler1_state)}")
    
    handler2_state = MockEventHandler.get_state(handler2)
    IO.puts("Handler2 state: #{inspect(handler2_state)}")
    
    handler3_state = MockEventHandler.get_state(handler3)
    IO.puts("Handler3 state: #{inspect(handler3_state)}")
    
    # Clean up
    Process.exit(event_bus, :normal)
    Process.exit(handler1, :normal)
    Process.exit(handler2, :normal)
    Process.exit(handler3, :normal)
  end
  
  defp receive_all_notifications do
    receive do
      {:blackboard_change, change} ->
        IO.puts("Received blackboard change: #{inspect(change)}")
        receive_all_notifications()
    after
      100 -> :ok
    end
  end
end

# Mock implementations for the demo

defmodule MockConfigProvider do
  use GenServer
  
  def start do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil)
    pid
  end
  
  @impl true
  def init(_) do
    {:ok, %{}}
  end
end

defmodule MockBlackboard do
  use GenServer
  
  def start do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil)
    pid
  end
  
  def get(pid, key) do
    GenServer.call(pid, {:get, key})
  end
  
  def put(pid, key, value) do
    GenServer.call(pid, {:put, key, value})
  end
  
  @impl true
  def init(_) do
    {:ok, %{values: %{}}}
  end
  
  @impl true
  def handle_call({:get, key}, _from, state) do
    value = Map.get(state.values, key)
    {:reply, value, state}
  end
  
  @impl true
  def handle_call({:put, key, value}, _from, state) do
    # Notify subscribers
    notify_subscribers(key, value)
    
    # Update state
    new_values = Map.put(state.values, key, value)
    {:reply, :ok, %{state | values: new_values}}
  end
  
  defp notify_subscribers(key, value) do
    change = %{
      key: key,
      operation: :put,
      old_value: nil,
      new_value: value,
      timestamp: System.system_time(:millisecond)
    }
    
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
end

defmodule MockEventBus do
  use GenServer
  
  def start do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil)
    pid
  end
  
  def publish(pid, event) do
    GenServer.cast(pid, {:publish, event})
  end
  
  @impl true
  def init(_) do
    {:ok, %{handlers: %{}}}
  end
  
  @impl true
  def handle_cast({:publish, event}, state) do
    # Find handlers for this event
    Registry.dispatch(Automata.Registry, event.type, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:event, event})
      end
    end)
    
    Registry.dispatch(Automata.Registry, :all, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:event, event})
      end
    end)
    
    {:noreply, state}
  end
end

defmodule MockEventHandler do
  use GenServer
  
  def start(name, event_types) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {name, event_types})
    
    # Start registry if not already started
    Registry.start_link(keys: :duplicate, name: Automata.Registry)
    
    # Register for event types
    Enum.each(event_types, fn type ->
      Registry.register(Automata.Registry, type, nil)
    end)
    
    pid
  end
  
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end
  
  @impl true
  def init({name, event_types}) do
    {:ok, %{
      name: name,
      event_types: event_types,
      events_processed: []
    }}
  end
  
  @impl true
  def handle_info({:event, event}, state) do
    IO.puts("#{state.name} received event: #{inspect(event.type)}")
    
    # Update state
    new_state = %{state | 
      events_processed: [event | state.events_processed]
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end