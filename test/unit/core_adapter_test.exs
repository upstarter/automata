defmodule Automata.CoreAdapterTest do
  use ExUnit.Case
  
  alias Automata.CoreAdapter
  
  setup do
    # Start the adapter registry explicitly for testing
    {:ok, _} = Automata.Infrastructure.Adapters.RegistryAdapter.start_link([])
    
    world_config = %{
      name: :test_world,
      description: "Test world for compatibility layer testing",
      type: :mock
    }
    
    automaton_config = %{
      name: :test_automaton,
      type: :behavior_tree,
      initial_state: %{},
      root: :sequence,
      nodes: [
        %{
          id: :sequence,
          type: :sequence,
          children: [:test_action]
        },
        %{
          id: :test_action,
          type: :action,
          module: Automaton.Types.BT.Action,
          config: %{}
        }
      ]
    }
    
    agent_config = %{
      name: :test_agent,
      module: GenServer,
      config: %{}
    }
    
    %{
      world_config: world_config,
      automaton_config: automaton_config,
      agent_config: agent_config
    }
  end
  
  test "starts the Automata system with the core adapter", %{world_config: world_config} do
    result = CoreAdapter.start(world_config)
    assert match?({:ok, _}, result)
  end
  
  test "starts and stops an automaton", %{world_config: world_config, automaton_config: automaton_config} do
    {:ok, _} = CoreAdapter.start(world_config)
    
    # Start automaton
    {:ok, automaton_pid} = CoreAdapter.start_automaton(automaton_config)
    assert is_pid(automaton_pid)
    
    # Check automaton info
    {:ok, info} = CoreAdapter.automaton_info(automaton_config[:name])
    assert info.config[:name] == automaton_config[:name]
    
    # List automata
    {:ok, automata} = CoreAdapter.list_automata()
    assert Map.has_key?(automata, automaton_config[:name])
    
    # Stop automaton
    :ok = CoreAdapter.stop_automaton(automaton_config[:name])
    
    # Verify it's stopped
    {:ok, automata} = CoreAdapter.list_automata()
    refute Map.has_key?(automata, automaton_config[:name])
  end
  
  test "starts and stops an agent", %{
    world_config: world_config, 
    automaton_config: automaton_config,
    agent_config: agent_config
  } do
    {:ok, _} = CoreAdapter.start(world_config)
    {:ok, _} = CoreAdapter.start_automaton(automaton_config)
    
    # Start agent
    {:ok, agent_pid} = CoreAdapter.start_agent(automaton_config[:name], agent_config)
    assert is_pid(agent_pid)
    
    # Check agent info
    {:ok, info} = CoreAdapter.agent_info(automaton_config[:name], agent_config[:name])
    assert info.config[:name] == agent_config[:name]
    
    # List agents
    {:ok, agents} = CoreAdapter.list_agents(automaton_config[:name])
    assert Map.has_key?(agents, agent_config[:name])
    
    # Stop agent
    :ok = CoreAdapter.stop_agent(automaton_config[:name], agent_config[:name])
    
    # Verify it's stopped
    {:ok, agents} = CoreAdapter.list_agents(automaton_config[:name])
    refute Map.has_key?(agents, agent_config[:name])
  end
  
  test "legacy API in the main Automata module", %{
    world_config: world_config, 
    automaton_config: automaton_config
  } do
    # Start the system through the legacy API
    {:ok, _} = Automata.legacy_start(world_config)
    
    # Start automaton through the legacy API
    {:ok, automaton_pid} = Automata.legacy_start_automaton(automaton_config)
    assert is_pid(automaton_pid)
    
    # List automata through the legacy API
    automata = Automata.legacy_list_automata()
    assert Enum.any?(automata, fn {name, _} -> name == automaton_config[:name] end)
    
    # Stop automaton through the legacy API
    :ok = Automata.legacy_stop_automaton(automaton_config[:name])
    
    # Verify it's stopped
    automata = Automata.legacy_list_automata()
    refute Enum.any?(automata, fn {name, _} -> name == automaton_config[:name] end)
  end
end