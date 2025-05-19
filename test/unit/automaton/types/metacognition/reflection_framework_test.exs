defmodule Automaton.Types.Metacognition.ReflectionFrameworkTest do
  use ExUnit.Case, async: true
  
  alias Automata.Reasoning.Cognitive.Metacognition.ReflectionFramework
  alias Automata.Reasoning.Cognitive.Metacognition.ReflectionFramework.{
    Introspection,
    StrategySelection,
    TraceAnalysis
  }

  describe "analyze_performance/2" do
    test "analyzes performance data to identify improvement opportunities" do
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
        },
        %{
          task_id: "task-3",
          execution_time: 180,
          resource_usage: %{memory: 220, cpu: 45},
          outcomes: %{type: :failure, reason: :timeout},
          metadata: %{complexity: 6}
        }
      ]
      
      result = ReflectionFramework.analyze_performance(performance_data)
      
      assert is_map(result)
      assert Map.has_key?(result, :performance_summary)
      assert Map.has_key?(result, :causal_factors)
      assert Map.has_key?(result, :bottlenecks)
      assert Map.has_key?(result, :improvement_opportunities)
      assert Map.has_key?(result, :confidence)
      
      assert is_list(result.causal_factors)
      assert is_list(result.bottlenecks)
      assert is_list(result.improvement_opportunities)
      assert is_float(result.confidence)
      assert result.confidence >= 0.0 and result.confidence <= 1.0
    end
    
    test "respects options for analysis parameters" do
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
      
      options = [
        time_threshold: 0.9,
        resource_threshold: 0.8
      ]
      
      result = ReflectionFramework.analyze_performance(performance_data, options)
      
      assert is_map(result)
      assert Map.has_key?(result, :performance_summary)
      assert Map.has_key?(result, :bottlenecks)
    end
  end
  
  describe "select_strategy/3" do
    test "selects optimal reasoning strategy for a problem" do
      problem = %{
        type: :classification,
        characteristics: %{data_size: 1000, noise_level: 0.2, time_constraint: 500},
        constraints: %{resources: %{memory: 1000}, max_time: 1000},
        metadata: %{}
      }
      
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
        },
        %{
          id: :bayesian,
          name: "Bayesian Classifier",
          characteristics: %{
            ideal_problem_types: [:classification, :anomaly_detection],
            typical_duration: 200
          },
          resource_profile: %{memory: 300, cpu: 30},
          success_patterns: %{large_datasets: 0.5, noisy_data: 0.7}
        }
      ]
      
      result = ReflectionFramework.select_strategy(problem, available_strategies)
      
      assert is_map(result)
      assert Map.has_key?(result, :selected_strategy)
      assert Map.has_key?(result, :alternatives)
      assert Map.has_key?(result, :rationale)
      assert Map.has_key?(result, :confidence)
      
      assert is_map(result.selected_strategy)
      assert is_list(result.alternatives)
      assert is_map(result.rationale)
      assert is_float(result.confidence)
      assert result.confidence >= 0.0 and result.confidence <= 1.0
    end
    
    test "respects constraints when selecting strategies" do
      problem = %{
        type: :classification,
        characteristics: %{data_size: 1000, noise_level: 0.2},
        constraints: %{
          resources: %{memory: 500},  # Strict memory constraint
          max_time: 400  # Strict time constraint
        },
        metadata: %{}
      }
      
      available_strategies = [
        %{
          id: :neural_network,
          name: "Neural Network Classifier",
          characteristics: %{
            ideal_problem_types: [:classification],
            typical_duration: 800  # Exceeds time constraint
          },
          resource_profile: %{memory: 800, cpu: 70},  # Exceeds memory constraint
          success_patterns: %{}
        },
        %{
          id: :decision_tree,
          name: "Decision Tree Classifier",
          characteristics: %{
            ideal_problem_types: [:classification],
            typical_duration: 300  # Within time constraint
          },
          resource_profile: %{memory: 400, cpu: 50},  # Within memory constraint
          success_patterns: %{}
        }
      ]
      
      result = ReflectionFramework.select_strategy(problem, available_strategies)
      
      assert is_map(result)
      assert result.selected_strategy.id == :decision_tree
    end
  end
  
  describe "analyze_trace/2" do
    test "analyzes execution trace to identify bottlenecks" do
      trace = [
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
          input_info: %{size: 1000},
          output_info: %{vector_size: 64},
          metadata: %{}
        },
        %{
          timestamp: 1250,
          component: :reasoning_engine,
          action: :infer,
          duration: 100,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        },
        %{
          timestamp: 1350,
          component: :neural_decoder,
          action: :decode,
          duration: 150,
          input_info: %{vector_size: 64},
          output_info: %{},
          metadata: %{}
        }
      ]
      
      result = ReflectionFramework.analyze_trace(trace)
      
      assert is_map(result)
      assert Map.has_key?(result, :execution_flow)
      assert Map.has_key?(result, :critical_path)
      assert Map.has_key?(result, :bottlenecks)
      assert Map.has_key?(result, :anomalies)
      assert Map.has_key?(result, :optimization_opportunities)
      assert Map.has_key?(result, :confidence)
      
      assert is_map(result.execution_flow)
      assert is_list(result.critical_path)
      assert is_list(result.bottlenecks)
      assert is_list(result.anomalies)
      assert is_list(result.optimization_opportunities)
      assert is_float(result.confidence)
      assert result.confidence >= 0.0 and result.confidence <= 1.0
    end
    
    test "respects options for analysis parameters" do
      trace = [
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
      
      options = [time_ratio_threshold: 0.1]
      
      result = ReflectionFramework.analyze_trace(trace, options)
      
      assert is_map(result)
      assert Map.has_key?(result, :execution_flow)
      assert Map.has_key?(result, :bottlenecks)
    end
  end
  
  describe "reflect/2" do
    test "automatically selects the appropriate reflection based on data content" do
      # Performance data
      performance_data = %{
        performance_data: [
          %{
            task_id: "task-1",
            execution_time: 150,
            resource_usage: %{memory: 200},
            outcomes: %{type: :success},
            metadata: %{}
          }
        ]
      }
      
      result = ReflectionFramework.reflect(performance_data)
      
      assert is_map(result)
      assert Map.has_key?(result, :performance_summary)
      
      # Trace data
      trace_data = %{
        execution_trace: [
          %{
            timestamp: 1000,
            component: :context_manager,
            action: :initialize,
            duration: 50,
            input_info: %{},
            output_info: %{},
            metadata: %{}
          }
        ]
      }
      
      result = ReflectionFramework.reflect(trace_data)
      
      assert is_map(result)
      assert Map.has_key?(result, :execution_flow)
      
      # Strategy selection data
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
      
      result = ReflectionFramework.reflect(strategy_data)
      
      assert is_map(result)
      assert Map.has_key?(result, :selected_strategy)
    end
    
    test "respects explicit reflection type" do
      # Data contains multiple types
      mixed_data = %{
        performance_data: [
          %{
            task_id: "task-1",
            execution_time: 150,
            resource_usage: %{memory: 200},
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
      
      # Explicitly request performance analysis
      result = ReflectionFramework.reflect(mixed_data, [type: :performance])
      
      assert is_map(result)
      assert Map.has_key?(result, :performance_summary)
      
      # Explicitly request trace analysis
      result = ReflectionFramework.reflect(mixed_data, [type: :trace])
      
      assert is_map(result)
      assert Map.has_key?(result, :execution_flow)
    end
  end
  
  describe "Introspection.analyze_performance/2" do
    test "extracts performance metrics correctly" do
      performance_data = [
        %{
          task_id: "task-1",
          execution_time: 100,
          resource_usage: %{memory: 200, cpu: 40},
          outcomes: %{type: :success},
          metadata: %{}
        },
        %{
          task_id: "task-2",
          execution_time: 200,
          resource_usage: %{memory: 300, cpu: 50},
          outcomes: %{type: :success},
          metadata: %{}
        }
      ]
      
      result = Introspection.analyze_performance(performance_data)
      
      assert is_map(result)
      
      # Check execution time metrics
      assert result.performance_summary.overall_efficiency > 0
      
      # Check if causal factors are identified
      assert is_list(result.causal_factors)
      assert length(result.causal_factors) > 0
      
      # Check if improvement opportunities are generated
      assert is_list(result.improvement_opportunities)
      assert length(result.improvement_opportunities) > 0
    end
  end
  
  describe "StrategySelection.select_strategy/3" do
    test "selects strategy based on problem characteristics" do
      problem = %{
        type: :classification,
        characteristics: %{},
        constraints: %{},
        metadata: %{}
      }
      
      strategies = [
        %{
          id: :s1,
          name: "Strategy 1",
          characteristics: %{ideal_problem_types: [:regression]},
          resource_profile: %{},
          success_patterns: %{}
        },
        %{
          id: :s2,
          name: "Strategy 2",
          characteristics: %{ideal_problem_types: [:classification]},
          resource_profile: %{},
          success_patterns: %{}
        }
      ]
      
      result = StrategySelection.select_strategy(problem, strategies)
      
      assert is_map(result)
      assert result.selected_strategy.id == :s2
    end
    
    test "generates proper rationale for selection" do
      problem = %{
        type: :classification,
        characteristics: %{},
        constraints: %{},
        metadata: %{}
      }
      
      strategies = [
        %{
          id: :s1,
          name: "Strategy 1",
          characteristics: %{},
          resource_profile: %{},
          success_patterns: %{}
        }
      ]
      
      result = StrategySelection.select_strategy(problem, strategies)
      
      assert is_map(result.rationale)
      assert Map.has_key?(result.rationale, :primary_factors)
      assert is_list(result.rationale.primary_factors)
    end
  end
  
  describe "TraceAnalysis.analyze_trace/2" do
    test "reconstructs execution flow from trace" do
      trace = [
        %{
          timestamp: 1000,
          component: :c1,
          action: :a1,
          duration: 100,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        },
        %{
          timestamp: 1100,
          component: :c2,
          action: :a2,
          duration: 100,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        }
      ]
      
      result = TraceAnalysis.analyze_trace(trace)
      
      assert is_map(result.execution_flow)
      assert Map.has_key?(result.execution_flow, :component_graph)
      assert Map.has_key?(result.execution_flow, :component_stats)
      assert Map.has_key?(result.execution_flow, :total_duration)
      
      # Verify total duration calculation
      assert result.execution_flow.total_duration == 200
    end
    
    test "identifies critical path in execution" do
      trace = [
        %{
          timestamp: 1000,
          component: :c1,
          action: :a1,
          duration: 50,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        },
        %{
          timestamp: 1050,
          component: :c2,
          action: :a2,
          duration: 200,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        },
        %{
          timestamp: 1250,
          component: :c3,
          action: :a3,
          duration: 50,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        }
      ]
      
      result = TraceAnalysis.analyze_trace(trace)
      
      assert is_list(result.critical_path)
      
      # The critical path should include the component with the longest duration
      has_c2 = Enum.any?(result.critical_path, fn comp -> comp.component == :c2 end)
      assert has_c2
    end
    
    test "generates optimization opportunities from bottlenecks" do
      trace = [
        %{
          timestamp: 1000,
          component: :slow_component,
          action: :process,
          duration: 500,  # Very slow operation
          input_info: %{},
          output_info: %{},
          metadata: %{}
        },
        %{
          timestamp: 1500,
          component: :fast_component,
          action: :process,
          duration: 50,
          input_info: %{},
          output_info: %{},
          metadata: %{}
        }
      ]
      
      result = TraceAnalysis.analyze_trace(trace)
      
      assert is_list(result.optimization_opportunities)
      
      # Should identify the slow component as an optimization target
      has_slow_comp = Enum.any?(result.optimization_opportunities, fn opp -> 
        opp.target == :slow_component ||
        (opp.target == :execution_model && opp.description =~ "parallelism")
      end)
      
      assert has_slow_comp
    end
  end
end