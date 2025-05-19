defmodule Automata.Test.Mocks do
  @moduledoc """
  Mock implementations for testing.
  
  This module provides mock implementations of various components
  in the Automata system for testing purposes.
  """
  
  @doc """
  Creates a mock config provider that returns predefined configurations.
  
  ## Examples
  
  ```elixir
  mock_config = Automata.Test.Mocks.config_provider(%{
    "agent_1" => %{type: :behavior_tree, node_type: :sequence}
  })
  
  start_supervised({Automata.Infrastructure.Config.Provider, [provider: mock_config]})
  ```
  """
  def config_provider(configs) do
    fn
      {:agent, id} -> Map.get(configs, id)
      {:world, id} -> Map.get(configs, id)
      {:system, key} -> Map.get(configs, key)
      _ -> nil
    end
  end
  
  @doc """
  Creates a mock world configuration.
  """
  def world_config(opts \\ []) do
    id = Keyword.get(opts, :id, "world-#{System.unique_integer([:positive])}")
    agents = Keyword.get(opts, :agents, [])
    
    %{
      id: id,
      type: :default,
      agents: agents,
      tick_freq: Keyword.get(opts, :tick_freq, 100),
      settings: Keyword.get(opts, :settings, %{})
    }
  end
  
  @doc """
  Creates a mock agent configuration.
  """
  def agent_config(opts \\ []) do
    id = Keyword.get(opts, :id, "agent-#{System.unique_integer([:positive])}")
    type = Keyword.get(opts, :type, :behavior_tree)
    
    config = %{
      id: id,
      type: type,
      tick_freq: Keyword.get(opts, :tick_freq, 50),
      world_id: Keyword.get(opts, :world_id, "world-1"),
      settings: Keyword.get(opts, :settings, %{})
    }
    
    case type do
      :behavior_tree ->
        Map.put(config, :node_type, Keyword.get(opts, :node_type, :sequence))
        
      :bandit ->
        config
        
      :tweann ->
        config
        
      _ ->
        config
    end
  end
  
  defmodule MockEventHandler do
    @moduledoc """
    A mock event handler that records events for inspection in tests.
    """
    
    use GenServer
    
    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
    end
    
    def init(_opts) do
      {:ok, %{events: []}}
    end
    
    def handle_event(event, server \\ __MODULE__) do
      GenServer.cast(server, {:event, event})
    end
    
    def get_events(server \\ __MODULE__) do
      GenServer.call(server, :get_events)
    end
    
    def clear_events(server \\ __MODULE__) do
      GenServer.call(server, :clear_events)
    end
    
    def handle_cast({:event, event}, state) do
      {:noreply, %{state | events: [event | state.events]}}
    end
    
    def handle_call(:get_events, _from, state) do
      {:reply, Enum.reverse(state.events), state}
    end
    
    def handle_call(:clear_events, _from, state) do
      {:reply, :ok, %{state | events: []}}
    end
  end
  
  defmodule MockAgent do
    @moduledoc """
    A mock agent implementation for testing.
    """
    
    @behaviour Automata.Infrastructure.AgentSystem.AgentType
    
    alias Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Schema
    
    @impl true
    def type, do: :mock_agent
    
    @impl true
    def description do
      "Mock agent for testing"
    end
    
    @impl true
    def schema, do: Schema
    
    @impl true
    def validate_config(config) do
      Schema.validate(config)
    end
    
    @impl true
    def init(agent_id, world_id, config) do
      state = %{
        agent_id: agent_id,
        world_id: world_id,
        config: config,
        status: :ready,
        tick_count: 0,
        history: []
      }
      
      {:ok, state}
    end
    
    @impl true
    def handle_tick(implementation) do
      updated = %{
        implementation |
        tick_count: implementation.tick_count + 1,
        history: [
          {:tick, implementation.tick_count, DateTime.utc_now()} 
          | implementation.history
        ]
      }
      
      {:ok, updated}
    end
    
    @impl true
    def terminate(implementation, reason) do
      # Just log the termination
      updated = %{
        implementation |
        status: :terminated,
        history: [
          {:terminate, reason, DateTime.utc_now()} 
          | implementation.history
        ]
      }
      
      # In a real implementation, we would clean up resources here
      
      :ok
    end
    
    @impl true
    def status(implementation) do
      implementation.status
    end
    
    @impl true
    def metadata(implementation) do
      %{
        agent_id: implementation.agent_id,
        world_id: implementation.world_id,
        tick_count: implementation.tick_count
      }
    end
    
    @impl true
    def features do
      [:testing]
    end
  end
  
  defmodule MockActionHandler do
    @moduledoc """
    Mock action handler for behavior tree testing.
    """
    
    def start(context) do
      action_id = "action-#{System.unique_integer([:positive])}"
      
      case context.parameters do
        %{fail: true} ->
          {:error, "Simulated failure"}
          
        %{immediate: true} ->
          {:complete, :success, %{result: "Completed immediately"}}
          
        _ ->
          {:ok, action_id}
      end
    end
    
    def check_status(context) do
      # Get the total iterations from parameters or default to 3
      total = get_in(context.parameters, [:iterations]) || 3
      
      # Get the current iteration from process dictionary or start at 1
      current = Process.get({:mock_action, context.action_id}, 1)
      
      cond do
        current >= total ->
          # Action completed
          {:complete, :success, %{
            result: "Completed after #{current} iterations"
          }}
          
        true ->
          # Action still running, increment for next time
          Process.put({:mock_action, context.action_id}, current + 1)
          
          {:running, %{
            progress: current / total
          }}
      end
    end
  end
end