defmodule Automaton.Types.Metacognition.MetacognitiveSystemTest do
  use ExUnit.Case, async: true
  
  alias Automata.Reasoning.Cognitive.Metacognition.MetacognitiveSystem

  describe "init/1" do
    test "initializes system with default configuration" do
      result = MetacognitiveSystem.init()
      
      assert {:ok, state} = result
      assert is_map(state.config)
      assert is_map(state.state)
      assert state.state.initialized == true
      
      # Check that default config has expected fields
      assert is_map(state.config.reflection)
      assert is_map(state.config.self_modification)
      assert is_map(state.config.monitoring)
    end
    
    test "initializes with custom configuration" do
      custom_config = %{
        reflection: %{
          performance_analysis_enabled: false,
          trace_analysis_enabled: true,
          strategy_selection_enabled: true,
          min_performance_samples: 10,
          analysis_interval: 2000
        },
        self_modification: %{
          enabled: false,
          safety_threshold: 0.8,
          max_modification_depth: 1,
          approval_required: true,
          self_approval_allowed: false
        },
        monitoring: %{
          enabled: true,
          metrics_collection_interval: 1000,
          trace_collection_enabled: false,
          performance_metrics_retention: 500
        }
      }
      
      result = MetacognitiveSystem.init(custom_config)
      
      assert {:ok, state} = result
      assert state.config.reflection.performance_analysis_enabled == false
      assert state.config.reflection.min_performance_samples == 10
      assert state.config.self_modification.enabled == false
      assert state.config.self_modification.safety_threshold == 0.8
      assert state.config.monitoring.metrics_collection_interval == 1000
    end
    
    test "returns error for invalid configuration" do
      invalid_config = %{
        reflection: %{
          min_performance_samples: -5  # Invalid: must be positive
        }
      }
      
      result = MetacognitiveSystem.init(invalid_config)
      
      assert {:error, _reason} = result
    end
  end
  
  describe "analyze_performance/3" do
    test "analyzes performance data when enabled" do
      # Create system state with performance analysis enabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        reflection: %{
          performance_analysis_enabled: true,
          min_performance_samples: 2
        }
      })
      
      # Create sample performance data
      performance_data = [
        %{
          task_id: "task-1",
          execution_time: 150,
          resource_usage: %{memory: 200, cpu: 40},
          outcomes: %{type: :success, accuracy: 0.85},
          metadata: %{complexity: 5}
        },
        %{
          task_id: "task-2",
          execution_time: 250,
          resource_usage: %{memory: 350, cpu: 60},
          outcomes: %{type: :success, accuracy: 0.75},
          metadata: %{complexity: 7}
        }
      ]
      
      result = MetacognitiveSystem.analyze_performance(
        performance_data,
        system_state
      )
      
      assert {:ok, analysis_result} = result
      assert is_map(analysis_result.analysis)
      assert is_map(analysis_result.system_state)
      
      # Check that analysis has expected structures
      assert Map.has_key?(analysis_result.analysis, :performance_summary)
      assert Map.has_key?(analysis_result.analysis, :causal_factors)
      assert Map.has_key?(analysis_result.analysis, :bottlenecks)
      assert Map.has_key?(analysis_result.analysis, :improvement_opportunities)
      
      # Check that system state has been updated
      assert length(analysis_result.system_state.state.performance_history) > 0
    end
    
    test "returns error when performance analysis is disabled" do
      # Create system state with performance analysis disabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        reflection: %{
          performance_analysis_enabled: false
        }
      })
      
      performance_data = [
        %{
          task_id: "task-1",
          execution_time: 150,
          resource_usage: %{},
          outcomes: %{},
          metadata: %{}
        }
      ]
      
      result = MetacognitiveSystem.analyze_performance(
        performance_data,
        system_state
      )
      
      assert {:error, :performance_analysis_disabled} = result
    end
    
    test "returns error when insufficient performance data" do
      # Create system state requiring at least 5 samples
      {:ok, system_state} = MetacognitiveSystem.init(%{
        reflection: %{
          performance_analysis_enabled: true,
          min_performance_samples: 5
        }
      })
      
      # Only 2 samples, less than the 5 required
      performance_data = [
        %{
          task_id: "task-1",
          execution_time: 150,
          resource_usage: %{},
          outcomes: %{},
          metadata: %{}
        },
        %{
          task_id: "task-2",
          execution_time: 200,
          resource_usage: %{},
          outcomes: %{},
          metadata: %{}
        }
      ]
      
      result = MetacognitiveSystem.analyze_performance(
        performance_data,
        system_state
      )
      
      assert {:error, :insufficient_performance_data} = result
    end
  end
  
  describe "analyze_trace/3" do
    test "analyzes execution trace when enabled" do
      # Create system state with trace analysis enabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        reflection: %{
          trace_analysis_enabled: true
        }
      })
      
      # Create sample trace data
      trace_data = [
        %{
          timestamp: 1000,
          component: :context_manager,
          action: :initialize,
          duration: 50,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        },
        %{
          timestamp: 1050,
          component: :neural_encoder,
          action: :encode,
          duration: 200,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        }
      ]
      
      result = MetacognitiveSystem.analyze_trace(
        trace_data,
        system_state
      )
      
      assert {:ok, analysis_result} = result
      assert is_map(analysis_result)
      
      # Check that analysis has expected structures
      assert Map.has_key?(analysis_result, :execution_flow)
      assert Map.has_key?(analysis_result, :critical_path)
      assert Map.has_key?(analysis_result, :bottlenecks)
      assert Map.has_key?(analysis_result, :optimization_opportunities)
    end
    
    test "returns error when trace analysis is disabled" do
      # Create system state with trace analysis disabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        reflection: %{
          trace_analysis_enabled: false
        }
      })
      
      trace_data = [
        %{
          timestamp: 1000,
          component: :component,
          action: :action,
          duration: 50,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        }
      ]
      
      result = MetacognitiveSystem.analyze_trace(
        trace_data,
        system_state
      )
      
      assert {:error, :trace_analysis_disabled} = result
    end
  end
  
  describe "select_strategy/4" do
    test "selects optimal strategy when enabled" do
      # Create system state with strategy selection enabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        reflection: %{
          strategy_selection_enabled: true
        }
      })
      
      # Create problem description
      problem = %{
        type: :classification,
        characteristics: %{data_size: 1000, noise_level: 0.2},
        constraints: %{resources: %{memory: 1000}, max_time: 1000},
        metadata: %{}
      }
      
      # Available strategies
      available_strategies = [
        %{
          id: :neural_network,
          name: "Neural Network Classifier",
          characteristics: %{
            ideal_problem_types: [:classification, :regression],
            typical_duration: 800
          },
          resource_profile: %{memory: 800, cpu: 70},
          success_patterns: %{large_datasets: 0.9, noisy_data: 0.8}
        },
        %{
          id: :decision_tree,
          name: "Decision Tree Classifier",
          characteristics: %{
            ideal_problem_types: [:classification],
            typical_duration: 300
          },
          resource_profile: %{memory: 400, cpu: 50},
          success_patterns: %{large_datasets: 0.7, noisy_data: 0.6}
        }
      ]
      
      result = MetacognitiveSystem.select_strategy(
        problem,
        available_strategies,
        system_state
      )
      
      assert {:ok, selection_result} = result
      assert is_map(selection_result.selection)
      assert is_map(selection_result.system_state)
      
      # Check that selection has expected structures
      assert Map.has_key?(selection_result.selection, :selected_strategy)
      assert Map.has_key?(selection_result.selection, :alternatives)
      assert Map.has_key?(selection_result.selection, :rationale)
      
      # Check that system state has been updated
      assert length(selection_result.system_state.state.strategy_history) > 0
    end
    
    test "returns error when strategy selection is disabled" do
      # Create system state with strategy selection disabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        reflection: %{
          strategy_selection_enabled: false
        }
      })
      
      problem = %{type: :test, characteristics: %{}, constraints: %{}, metadata: %{}}
      available_strategies = [%{id: :test, name: "Test", characteristics: %{}, resource_profile: %{}, success_patterns: %{}}]
      
      result = MetacognitiveSystem.select_strategy(
        problem,
        available_strategies,
        system_state
      )
      
      assert {:error, :strategy_selection_disabled} = result
    end
  end
  
  describe "propose_modification/5" do
    test "proposes modification when self-modification is enabled" do
      # Create system state with self-modification enabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        self_modification: %{
          enabled: true,
          max_modification_depth: 5
        }
      })
      
      # Create sample modifications
      modifications = [
        %{
          component: :reasoning_engine,
          scope: :parameter,
          type: :threshold,
          target: %{name: "confidence_threshold"},
          change: %{new_value: 0.8},
          rationale: "Improve precision"
        }
      ]
      
      expected_benefits = [
        %{
          description: "Higher precision in reasoning outcomes",
          impact: 0.3,
          areas: [:reasoning, :decision_quality]
        }
      ]
      
      source = :performance_analyzer
      
      result = MetacognitiveSystem.propose_modification(
        modifications,
        expected_benefits,
        source,
        system_state
      )
      
      assert {:ok, proposal_result} = result
      assert is_map(proposal_result.proposal_package)
      assert is_map(proposal_result.system_state)
      
      # Check that proposal package has expected structures
      assert Map.has_key?(proposal_result.proposal_package, :proposal)
      assert Map.has_key?(proposal_result.proposal_package, :impact_prediction)
      assert Map.has_key?(proposal_result.proposal_package, :safety_result)
      assert Map.has_key?(proposal_result.proposal_package, :approval_chain)
      
      # Check that system state has been updated
      assert length(proposal_result.system_state.state.modification_history) > 0
    end
    
    test "returns error when self-modification is disabled" do
      # Create system state with self-modification disabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        self_modification: %{
          enabled: false
        }
      })
      
      modifications = [
        %{
          component: :test,
          scope: :parameter,
          type: :test,
          target: %{},
          change: %{new_value: 0.5},
          rationale: "Test"
        }
      ]
      
      result = MetacognitiveSystem.propose_modification(
        modifications,
        [],
        :test,
        system_state
      )
      
      assert {:error, :self_modification_disabled} = result
    end
    
    test "returns error when modification depth is exceeded" do
      # Create system state with max depth of 0 (no modifications allowed)
      {:ok, system_state} = MetacognitiveSystem.init(%{
        self_modification: %{
          enabled: true,
          max_modification_depth: 0
        }
      })
      
      # Add a modification history to simulate having reached max depth
      system_state = put_in(
        system_state, 
        [:state, :modification_history], 
        [
          %{
            timestamp: DateTime.utc_now(),
            proposal_id: "existing-id",
            source: :test,
            status: :applied
          }
        ]
      )
      
      modifications = [
        %{
          component: :test,
          scope: :parameter,
          type: :test,
          target: %{},
          change: %{new_value: 0.5},
          rationale: "Test"
        }
      ]
      
      result = MetacognitiveSystem.propose_modification(
        modifications,
        [],
        :test,
        system_state
      )
      
      assert {:error, :modification_depth_exceeded} = result
    end
  end
  
  describe "process_approval/5" do
    test "processes valid approval" do
      # Create system state
      {:ok, system_state} = MetacognitiveSystem.init(%{
        self_modification: %{
          enabled: true,
          self_approval_allowed: true
        }
      })
      
      # Create a proposal package with pending approval
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :test,
            scope: :parameter,
            type: :test,
            target: %{name: "param"},
            change: %{new_value: 0.8},
            rationale: "Test"
          }
        ],
        expected_benefits: [],
        source: :test,
        safety_assessment: %{risk_level: :low}
      }
      
      approval_chain = %{
        levels: [:self, :peer],
        current_level: 0,
        approvals: [],
        final_status: :pending,
        completion_time: nil
      }
      
      proposal_package = %{
        proposal: proposal,
        approval_chain: approval_chain,
        impact_prediction: %{
          positive_impacts: [],
          negative_impacts: [],
          uncertain_impacts: [],
          system_risk: 0.2,
          confidence: 0.8,
          side_effects: []
        },
        safety_result: {:ok, %{safe: true, risk: 0.2, confidence: 0.8}},
        status: :pending_approval
      }
      
      # Process an approval
      result = MetacognitiveSystem.process_approval(
        proposal_package,
        :approved,
        :self,  # Self is the approver
        system_state
      )
      
      assert {:ok, approval_result} = result
      assert is_map(approval_result.proposal_package)
      assert approval_result.status == :pending_further_approval
      
      # Check that approval has been recorded
      approval_chain = approval_result.proposal_package.approval_chain
      assert length(approval_chain.approvals) == 1
      assert hd(approval_chain.approvals).status == :approved
      assert approval_chain.current_level == 1  # Advanced to next level
    end
    
    test "rejects invalid approver" do
      # Create system state where self-approval is not allowed
      {:ok, system_state} = MetacognitiveSystem.init(%{
        self_modification: %{
          enabled: true,
          self_approval_allowed: false  # Self approval not allowed
        }
      })
      
      # Create a simple proposal package
      proposal_package = %{
        proposal: %{id: "test-id"},
        approval_chain: %{
          levels: [:peer, :supervisor],
          current_level: 0,
          approvals: [],
          final_status: :pending,
          completion_time: nil
        }
      }
      
      # Attempt self-approval
      result = MetacognitiveSystem.process_approval(
        proposal_package,
        :approved,
        :self,  # Self is the approver (not allowed)
        system_state
      )
      
      assert {:error, :invalid_approver} = result
    end
    
    test "completes approval chain and processes approved modification" do
      # Create system state
      {:ok, system_state} = MetacognitiveSystem.init(%{
        self_modification: %{
          enabled: true,
          self_approval_allowed: true
        }
      })
      
      # Create a proposal package with one level remaining
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :reasoning_engine,
            scope: :parameter,
            type: :threshold,
            target: %{name: "confidence_threshold"},
            change: %{new_value: 0.8},
            rationale: "Test"
          }
        ],
        expected_benefits: [],
        source: :test,
        safety_assessment: %{risk_level: :low}
      }
      
      approval_chain = %{
        levels: [:self, :peer],
        current_level: 1,  # At the final level
        approvals: [
          %{
            level: :self,
            approver: :test_approver,
            status: :approved,
            conditions: [],
            timestamp: DateTime.utc_now(),
            comments: ""
          }
        ],
        final_status: :pending,
        completion_time: nil
      }
      
      proposal_package = %{
        proposal: proposal,
        approval_chain: approval_chain,
        impact_prediction: %{
          positive_impacts: [],
          negative_impacts: [],
          uncertain_impacts: [],
          system_risk: 0.2,
          confidence: 0.8,
          side_effects: []
        },
        safety_result: {:ok, %{safe: true, risk: 0.2, confidence: 0.8}},
        status: :pending_approval
      }
      
      # Process the final approval
      result = MetacognitiveSystem.process_approval(
        proposal_package,
        :approved,
        :peer_approver,
        system_state
      )
      
      assert {:ok, approval_result} = result
      
      # Once fully approved, the system should have processed the modification
      assert Map.has_key?(approval_result, :proposal)
      assert Map.has_key?(approval_result, :execution_result)
      assert Map.has_key?(approval_result, :verification_result)
      assert Map.has_key?(approval_result, :status)
      
      assert approval_result.status == :applied
    end
  end
  
  describe "generate_improvement_proposals/3" do
    test "generates proposals from performance analysis" do
      # Create system state with self-modification enabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        self_modification: %{
          enabled: true
        }
      })
      
      # Create a performance analysis with improvement opportunities
      performance_analysis = %{
        performance_summary: %{},
        causal_factors: [],
        bottlenecks: [],
        improvement_opportunities: [
          %{
            target: :reasoning_engine,
            action: :optimize_algorithm,
            expected_benefit: 0.35,
            confidence: 0.8,
            description: "Optimize reasoning engine algorithm",
            rationale: "Based on performance analysis"
          },
          %{
            target: :memory_manager,
            action: :tune_parameters,
            expected_benefit: 0.25,
            confidence: 0.7,
            description: "Tune memory manager parameters",
            rationale: "Based on resource usage patterns"
          }
        ],
        confidence: 0.85
      }
      
      result = MetacognitiveSystem.generate_improvement_proposals(
        performance_analysis,
        system_state
      )
      
      assert {:ok, proposals} = result
      assert is_list(proposals)
      assert length(proposals) == 2  # One for each opportunity
      
      # Check that proposals have expected structure
      Enum.each(proposals, fn proposal ->
        assert is_list(proposal.modifications)
        assert is_list(proposal.expected_benefits)
        assert proposal.source == :metacognitive_system
        assert is_number(proposal.priority)
      end)
    end
    
    test "returns error when self-modification is disabled" do
      # Create system state with self-modification disabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        self_modification: %{
          enabled: false
        }
      })
      
      performance_analysis = %{
        improvement_opportunities: [
          %{
            target: :test,
            action: :test,
            expected_benefit: 0.5,
            description: "Test"
          }
        ]
      }
      
      result = MetacognitiveSystem.generate_improvement_proposals(
        performance_analysis,
        system_state
      )
      
      assert {:error, :self_modification_disabled} = result
    end
  end
  
  describe "reflect/3" do
    test "automatically selects reflection type based on data content" do
      # Create system state
      {:ok, system_state} = MetacognitiveSystem.init()
      
      # Data for performance analysis
      performance_data = %{
        performance_data: [
          %{
            task_id: "task-1",
            execution_time: 150,
            resource_usage: %{memory: 200},
            outcomes: %{type: :success},
            metadata: %{}
          },
          %{
            task_id: "task-2",
            execution_time: 200,
            resource_usage: %{memory: 300},
            outcomes: %{type: :success},
            metadata: %{}
          }
        ]
      }
      
      result = MetacognitiveSystem.reflect(performance_data, system_state)
      
      assert {:ok, reflection_result} = result
      assert Map.has_key?(reflection_result, :analysis)
      assert Map.has_key?(reflection_result.analysis, :performance_summary)
      
      # Data for strategy selection
      strategy_data = %{
        problem: %{
          type: :classification,
          characteristics: %{},
          constraints: %{},
          metadata: %{}
        },
        available_strategies: [
          %{
            id: :strategy1,
            name: "Strategy 1",
            characteristics: %{ideal_problem_types: [:classification]},
            resource_profile: %{},
            success_patterns: %{}
          }
        ]
      }
      
      result = MetacognitiveSystem.reflect(strategy_data, system_state)
      
      assert {:ok, reflection_result} = result
      assert Map.has_key?(reflection_result, :selection)
      assert Map.has_key?(reflection_result.selection, :selected_strategy)
    end
    
    test "respects explicit reflection type" do
      # Create system state
      {:ok, system_state} = MetacognitiveSystem.init()
      
      # Data contains multiple types
      mixed_data = %{
        performance_data: [
          %{
            task_id: "task-1",
            execution_time: 150,
            resource_usage: %{memory: 200},
            outcomes: %{type: :success},
            metadata: %{}
          },
          %{
            task_id: "task-2",
            execution_time: 200,
            resource_usage: %{memory: 300},
            outcomes: %{type: :success},
            metadata: %{}
          }
        ],
        execution_trace: [
          %{
            timestamp: 1000,
            component: :component,
            action: :action,
            duration: 50,
            input_info: %{},
            output_info: %{},
            metadata: %{}
          }
        ]
      }
      
      # Explicitly request trace analysis
      result = MetacognitiveSystem.reflect(mixed_data, system_state, [type: :trace])
      
      assert {:ok, reflection_result} = result
      assert is_map(reflection_result)
      assert Map.has_key?(reflection_result, :execution_flow)
    end
    
    test "returns error for invalid reflection type" do
      # Create system state
      {:ok, system_state} = MetacognitiveSystem.init()
      
      # Request invalid reflection type
      result = MetacognitiveSystem.reflect(%{}, system_state, [type: :invalid_type])
      
      assert {:error, {:invalid_reflection_type, :invalid_type}} = result
    end
    
    test "performs improvement proposal generation" do
      # Create system state with self-modification enabled
      {:ok, system_state} = MetacognitiveSystem.init(%{
        self_modification: %{
          enabled: true
        }
      })
      
      # Performance analysis data
      improvement_data = %{
        performance_analysis: %{
          improvement_opportunities: [
            %{
              target: :reasoning_engine,
              action: :optimize,
              expected_benefit: 0.5,
              confidence: 0.8,
              description: "Optimize reasoning engine"
            }
          ]
        }
      }
      
      # Request improvement proposals
      result = MetacognitiveSystem.reflect(improvement_data, system_state, [type: :improvement])
      
      assert {:ok, proposals} = result
      assert is_list(proposals)
      assert length(proposals) > 0
      
      # Check that proposals have the right structure
      proposal = hd(proposals)
      assert is_list(proposal.modifications)
      assert is_list(proposal.expected_benefits)
    end
  end
end