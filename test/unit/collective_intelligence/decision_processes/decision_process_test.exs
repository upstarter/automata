defmodule Automata.CollectiveIntelligence.DecisionProcesses.DecisionProcessTest do
  use ExUnit.Case, async: true
  
  alias Automata.CollectiveIntelligence.DecisionProcesses.DecisionProcess
  alias Automata.CollectiveIntelligence.DecisionProcesses.ProcessManager
  alias Automata.CollectiveIntelligence.DecisionProcesses.Consensus
  alias Automata.CollectiveIntelligence.DecisionProcesses.Voting
  alias Automata.CollectiveIntelligence.DecisionProcesses.Argumentation
  alias Automata.CollectiveIntelligence.DecisionProcesses.Preference
  
  # Setup Registry for tests
  setup do
    # Start Registry
    {:ok, _pid} = Registry.start_link(keys: :unique, name: Automata.Registry)
    
    # Start ProcessManager
    {:ok, manager_pid} = ProcessManager.start_link()
    
    %{manager_pid: manager_pid}
  end
  
  describe "consensus processes" do
    test "simple majority consensus process", %{manager_pid: _manager_pid} do
      # Create a consensus process with simple majority
      config = %{
        id: "test_consensus_1",
        topic: "Test Decision",
        description: "A test consensus decision",
        min_participants: 3,
        max_participants: 10,
        quorum: 0.6,
        custom_parameters: %{
          algorithm: :simple_majority
        }
      }
      
      # Start the process
      {:ok, process_id} = ProcessManager.create_process(:consensus, config)
      
      # Register participants
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "participant1", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "participant2", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "participant3", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "participant4", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "participant5", %{})
      
      # Submit inputs
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "participant1", %{position: :agree})
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "participant2", %{position: :agree})
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "participant3", %{position: :disagree})
      
      # Check status
      {:ok, state, _status_info} = DecisionProcess.get_status(process_id)
      assert state == :collecting
      
      # Submit more inputs to reach deliberation
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "participant4", %{position: :disagree})
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "participant5", %{position: :agree})
      
      # Process should now be in deliberating state (based on quorum)
      {:ok, state, _status_info} = DecisionProcess.get_status(process_id)
      assert state == :deliberating
      
      # Close the process to get the result
      {:ok, :closed} = DecisionProcess.close_process(process_id)
      
      # Check the result
      {:ok, result} = DecisionProcess.get_result(process_id)
      assert result.outcome == :agreed
      assert result.agree_count == 3
      assert result.disagree_count == 2
    end
  end
  
  describe "voting processes" do
    test "plurality voting process", %{manager_pid: _manager_pid} do
      # Create a voting process with plurality voting
      config = %{
        id: "test_voting_1",
        topic: "Best Option",
        description: "Vote for the best option",
        min_participants: 3,
        max_participants: 10,
        quorum: 0.6,
        custom_parameters: %{
          voting_system: :plurality,
          options: ["option_a", "option_b", "option_c"]
        }
      }
      
      # Start the process
      {:ok, process_id} = ProcessManager.create_process(:voting, config)
      
      # Register participants
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "voter1", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "voter2", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "voter3", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "voter4", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "voter5", %{})
      
      # Submit votes
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "voter1", %{selection: "option_a"})
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "voter2", %{selection: "option_b"})
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "voter3", %{selection: "option_a"})
      
      # Check status
      {:ok, state, _status_info} = DecisionProcess.get_status(process_id)
      assert state == :collecting
      
      # Submit more votes to reach deliberation
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "voter4", %{selection: "option_c"})
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "voter5", %{selection: "option_a"})
      
      # Process should now be in deliberating state (based on quorum)
      {:ok, state, _status_info} = DecisionProcess.get_status(process_id)
      assert state == :deliberating
      
      # Close the process to get the result
      {:ok, :closed} = DecisionProcess.close_process(process_id)
      
      # Check the result
      {:ok, result} = DecisionProcess.get_result(process_id)
      assert result.voting_system == :plurality
      assert result.winner == "option_a"
      assert result.tallies["option_a"] == 3
      assert result.tallies["option_b"] == 1
      assert result.tallies["option_c"] == 1
    end
  end
  
  describe "argumentation processes" do
    test "grounded semantics argumentation process", %{manager_pid: _manager_pid} do
      # Create an argumentation process with grounded semantics
      config = %{
        id: "test_argumentation_1",
        topic: "Policy Decision",
        description: "Arguments regarding policy choice",
        min_participants: 2,
        max_participants: 5,
        custom_parameters: %{
          semantics: :grounded
        }
      }
      
      # Start the process
      {:ok, process_id} = ProcessManager.create_process(:argumentation, config)
      
      # Register participants
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "debater1", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "debater2", %{})
      
      # Submit arguments
      {:ok, _} = DecisionProcess.submit_input(process_id, "debater1", %{
        argument: %{
          claim: "Policy A should be adopted",
          premises: ["Economic benefits", "Social equity"]
        }
      })
      
      {:ok, _} = DecisionProcess.submit_input(process_id, "debater2", %{
        argument: %{
          claim: "Policy A has drawbacks",
          premises: ["Implementation cost", "Regulatory burden"]
        }
      })
      
      # Get the argument IDs from the process state
      {:ok, status_state, _status_info} = DecisionProcess.get_status(process_id)
      assert status_state == :collecting
      
      # Get process info to extract argument IDs
      {:ok, process_info} = ProcessManager.get_process_info(process_id)
      argument_ids = Map.keys(process_info.status.metadata.arguments)
      arg1_id = Enum.at(argument_ids, 0)
      arg2_id = Enum.at(argument_ids, 1)
      
      # Add an attack relationship
      {:ok, _} = DecisionProcess.submit_input(process_id, "debater2", %{
        attack: %{
          source: arg2_id,
          target: arg1_id,
          type: :rebut,
          explanation: "Policy A costs outweigh benefits"
        }
      })
      
      # Process should now be in deliberating state
      {:ok, state, _status_info} = DecisionProcess.get_status(process_id)
      assert state == :deliberating
      
      # Close the process to get the result
      {:ok, :closed} = DecisionProcess.close_process(process_id)
      
      # Check the result
      {:ok, result} = DecisionProcess.get_result(process_id)
      assert result.semantics == :grounded
      
      # In grounded semantics, arguments that are not attacked or are defended
      # will be in the grounded extension
      assert is_list(result.grounded_extension)
    end
  end
  
  describe "preference aggregation processes" do
    test "social welfare preference process", %{manager_pid: _manager_pid} do
      # Create a preference process with social welfare function
      config = %{
        id: "test_preference_1",
        topic: "Option Ranking",
        description: "Preference ranking of options",
        min_participants: 3,
        max_participants: 10,
        quorum: 0.6,
        custom_parameters: %{
          aggregation_method: :social_welfare,
          welfare_function: :utilitarian,
          alternatives: ["alt_a", "alt_b", "alt_c"],
          preference_model: :utility_function
        }
      }
      
      # Start the process
      {:ok, process_id} = ProcessManager.create_process(:preference, config)
      
      # Register participants
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "agent1", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "agent2", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "agent3", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "agent4", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "agent5", %{})
      
      # Submit preferences
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "agent1", %{
        utilities: %{
          "alt_a" => 80,
          "alt_b" => 60,
          "alt_c" => 30
        }
      })
      
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "agent2", %{
        utilities: %{
          "alt_a" => 70,
          "alt_b" => 90,
          "alt_c" => 40
        }
      })
      
      {:ok, :submitted} = DecisionProcess.submit_input(process_id, "agent3", %{
        utilities: %{
          "alt_a" => 50,
          "alt_b" => 65,
          "alt_c" => 75
        }
      })
      
      # Process should now be in deliberating state (based on quorum)
      {:ok, state, _status_info} = DecisionProcess.get_status(process_id)
      assert state == :deliberating
      
      # Close the process to get the result
      {:ok, :closed} = DecisionProcess.close_process(process_id)
      
      # Check the result
      {:ok, result} = DecisionProcess.get_result(process_id)
      assert result.aggregation_method == :social_welfare
      assert result.welfare_function == :utilitarian
      
      # Sum of utilities:
      # alt_a: 80 + 70 + 50 = 200
      # alt_b: 60 + 90 + 65 = 215
      # alt_c: 30 + 40 + 75 = 145
      # So alt_b should have highest welfare
      assert result.best_alternative == "alt_b"
    end
  end
  
  describe "process manager operations" do
    test "list processes returns correct summaries", %{manager_pid: _manager_pid} do
      # Create multiple processes
      {:ok, id1} = ProcessManager.create_process(:consensus, %{
        id: "test_list_1",
        topic: "Test 1",
        description: "First test process",
        min_participants: 2,
        custom_parameters: %{algorithm: :simple_majority}
      })
      
      {:ok, id2} = ProcessManager.create_process(:voting, %{
        id: "test_list_2",
        topic: "Test 2",
        description: "Second test process",
        min_participants: 2,
        custom_parameters: %{
          voting_system: :plurality,
          options: ["a", "b", "c"]
        }
      })
      
      # List processes
      {:ok, processes} = ProcessManager.list_processes()
      
      # Verify both processes are listed
      assert length(processes) == 2
      assert Enum.any?(processes, fn p -> p.id == id1 end)
      assert Enum.any?(processes, fn p -> p.id == id2 end)
      
      # Verify process summaries have correct types
      proc1 = Enum.find(processes, fn p -> p.id == id1 end)
      proc2 = Enum.find(processes, fn p -> p.id == id2 end)
      
      assert proc1.type == :consensus
      assert proc2.type == :voting
    end
    
    test "get process info returns detailed information", %{manager_pid: _manager_pid} do
      # Create a process
      config = %{
        id: "test_info_1",
        topic: "Process Info Test",
        description: "Testing process info retrieval",
        min_participants: 2,
        custom_parameters: %{algorithm: :simple_majority}
      }
      
      {:ok, process_id} = ProcessManager.create_process(:consensus, config)
      
      # Register participants
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "info_user1", %{})
      {:ok, :registered} = DecisionProcess.register_participant(process_id, "info_user2", %{})
      
      # Get process info
      {:ok, info} = ProcessManager.get_process_info(process_id)
      
      # Verify info contains expected details
      assert info.id == process_id
      assert info.type == :consensus
      assert info.state == :collecting
      assert info.config.topic == "Process Info Test"
      assert info.status.participants_count == 2
    end
  end
end