defmodule Automaton.Types.Metacognition.SelfModificationTest do
  use ExUnit.Case, async: true
  
  alias Automata.Reasoning.Cognitive.Metacognition.SelfModification
  alias Automata.Reasoning.Cognitive.Metacognition.SelfModification.{
    ModificationProposal,
    ApprovalSystem,
    ImpactPrediction,
    SafeExecution
  }

  describe "create_proposal/4" do
    test "creates a valid modification proposal" do
      modifications = [
        %{
          component: :reasoning_engine,
          scope: :parameter,
          type: :threshold,
          target: %{name: "confidence_threshold"},
          change: %{new_value: 0.8},
          rationale: "Improve precision by increasing confidence threshold",
          metadata: %{}
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
      
      proposal = SelfModification.create_proposal(
        modifications, 
        expected_benefits, 
        source
      )
      
      assert is_map(proposal)
      assert is_binary(proposal.id)
      assert proposal.modifications == modifications
      assert proposal.expected_benefits == expected_benefits
      assert proposal.source == source
      assert proposal.state == :proposed
      assert Map.has_key?(proposal, :creation_time)
      assert Map.has_key?(proposal, :safety_assessment)
    end
    
    test "respects custom priority and metadata" do
      modifications = [
        %{
          component: :test_component,
          scope: :parameter,
          type: :test,
          target: %{},
          change: %{},
          rationale: "Test",
          metadata: %{}
        }
      ]
      
      options = [
        priority: 0.9,
        metadata: %{test_key: "test_value"}
      ]
      
      proposal = SelfModification.create_proposal(
        modifications, 
        [], 
        :test,
        options
      )
      
      assert proposal.priority == 0.9
      assert proposal.metadata.test_key == "test_value"
    end
  end
  
  describe "validate_proposal/1" do
    test "validates a well-formed proposal" do
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :reasoning_engine,
            scope: :parameter,
            type: :threshold,
            target: %{name: "confidence_threshold"},
            change: %{new_value: 0.8},
            rationale: "Improve precision"
          }
        ],
        expected_benefits: [
          %{
            description: "Higher precision",
            impact: 0.3
          }
        ],
        source: :test,
        priority: 0.5,
        state: :proposed,
        creation_time: DateTime.utc_now(),
        metadata: %{},
        safety_assessment: %{}
      }
      
      result = SelfModification.validate_proposal(proposal)
      
      assert {:ok, validated} = result
      assert Map.get(validated.metadata, :validated, false) == true
    end
    
    test "returns errors for missing required fields" do
      # Missing modifications
      invalid_proposal = %{
        id: "test-id",
        expected_benefits: [%{description: "Test", impact: 0.1}],
        source: :test,
        state: :proposed,
        creation_time: DateTime.utc_now(),
        metadata: %{}
      }
      
      result = SelfModification.validate_proposal(invalid_proposal)
      
      assert {:error, errors} = result
      assert is_list(errors)
      assert length(errors) > 0
    end
    
    test "validates modification fields" do
      # Missing required field in modification
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            # Missing component
            scope: :parameter,
            type: :threshold,
            target: %{name: "test"},
            change: %{new_value: 0.8}
          }
        ],
        expected_benefits: [%{description: "Test", impact: 0.1}],
        source: :test,
        state: :proposed,
        creation_time: DateTime.utc_now(),
        metadata: %{}
      }
      
      result = SelfModification.validate_proposal(proposal)
      
      assert {:error, errors} = result
      assert Enum.any?(errors, &(&1 =~ "missing required field"))
    end
    
    test "validates modification scope" do
      # Invalid scope
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :test,
            scope: :invalid_scope,  # Not a valid scope
            type: :test,
            target: %{},
            change: %{}
          }
        ],
        expected_benefits: [%{description: "Test", impact: 0.1}],
        source: :test,
        state: :proposed,
        creation_time: DateTime.utc_now(),
        metadata: %{}
      }
      
      result = SelfModification.validate_proposal(proposal)
      
      assert {:error, errors} = result
      assert Enum.any?(errors, &(&1 =~ "Invalid modification scope"))
    end
    
    test "validates change is appropriate for scope" do
      # Parameter change without new_value
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :test,
            scope: :parameter,
            type: :test,
            target: %{},
            change: %{wrong_field: "value"}  # Missing new_value for parameter
          }
        ],
        expected_benefits: [%{description: "Test", impact: 0.1}],
        source: :test,
        state: :proposed,
        creation_time: DateTime.utc_now(),
        metadata: %{}
      }
      
      result = SelfModification.validate_proposal(proposal)
      
      assert {:error, errors} = result
      assert Enum.any?(errors, &(&1 =~ "Parameter change missing new_value"))
    end
  end
  
  describe "create_approval_chain/1" do
    test "creates an appropriate approval chain based on risk level" do
      # High risk proposal
      high_risk_proposal = %{
        safety_assessment: %{
          risk_level: :high
        }
      }
      
      high_risk_chain = ApprovalSystem.create_approval_chain(high_risk_proposal)
      
      assert length(high_risk_chain.levels) >= 3  # Should require multiple levels
      
      # Low risk proposal
      low_risk_proposal = %{
        safety_assessment: %{
          risk_level: :low
        }
      }
      
      low_risk_chain = ApprovalSystem.create_approval_chain(low_risk_proposal)
      
      assert length(low_risk_chain.levels) < length(high_risk_chain.levels)
    end
    
    test "initializes approval chain with correct structure" do
      proposal = %{
        safety_assessment: %{
          risk_level: :medium
        }
      }
      
      chain = ApprovalSystem.create_approval_chain(proposal)
      
      assert is_list(chain.levels)
      assert chain.current_level == 0
      assert is_list(chain.approvals)
      assert Enum.empty?(chain.approvals)
      assert chain.final_status == :pending
      assert chain.completion_time == nil
    end
  end
  
  describe "record_approval/4" do
    test "records an approval and advances to next level when approved" do
      # Create a chain with two levels
      chain = %{
        levels: [:self, :peer],
        current_level: 0,
        approvals: [],
        final_status: :pending,
        completion_time: nil
      }
      
      # Record approval for first level
      updated_chain = ApprovalSystem.record_approval(chain, :approved, :test_approver)
      
      assert length(updated_chain.approvals) == 1
      assert hd(updated_chain.approvals).status == :approved
      assert updated_chain.current_level == 1  # Advanced to next level
      assert updated_chain.final_status == :pending  # Not complete yet
      
      # Record approval for final level
      final_chain = ApprovalSystem.record_approval(updated_chain, :approved, :test_approver2)
      
      assert length(final_chain.approvals) == 2
      assert final_chain.final_status == :approved  # Now complete
      assert final_chain.completion_time != nil
    end
    
    test "finalizes chain immediately when proposal is rejected" do
      chain = %{
        levels: [:self, :peer, :supervisor],
        current_level: 0,
        approvals: [],
        final_status: :pending,
        completion_time: nil
      }
      
      # Reject at first level
      rejected_chain = ApprovalSystem.record_approval(chain, :rejected, :test_approver)
      
      assert length(rejected_chain.approvals) == 1
      assert hd(rejected_chain.approvals).status == :rejected
      assert rejected_chain.final_status == :rejected  # Finalized immediately
      assert rejected_chain.completion_time != nil
    end
    
    test "conditionally approved proposals advance to next level" do
      chain = %{
        levels: [:self, :peer],
        current_level: 0,
        approvals: [],
        final_status: :pending,
        completion_time: nil
      }
      
      # Conditionally approve
      updated_chain = ApprovalSystem.record_approval(
        chain, 
        :conditionally_approved, 
        :test_approver,
        [conditions: ["Increase test coverage"]]
      )
      
      assert length(updated_chain.approvals) == 1
      assert hd(updated_chain.approvals).status == :conditionally_approved
      assert hd(updated_chain.approvals).conditions == ["Increase test coverage"]
      assert updated_chain.current_level == 1  # Advanced to next level
    end
  end
  
  describe "summarize_approval_status/1" do
    test "summarizes approval chain status correctly" do
      # Create chain with some approvals
      chain = %{
        levels: [:self, :peer, :supervisor],
        current_level: 1,
        approvals: [
          %{
            level: :self,
            approver: :test_approver,
            status: :conditionally_approved,
            conditions: ["Condition 1"],
            timestamp: DateTime.add(DateTime.utc_now(), -3600, :second),
            comments: "Test comment"
          }
        ],
        final_status: :pending,
        completion_time: nil
      }
      
      summary = ApprovalSystem.summarize_approval_status(chain)
      
      assert summary.complete == false
      assert summary.final_status == :pending
      assert summary.levels_approved == 1
      assert summary.total_levels == 3
      assert summary.conditions == ["Condition 1"]
      assert is_integer(summary.time_in_approval)
    end
    
    test "correctly reports complete chains" do
      # Create completed chain
      chain = %{
        levels: [:self, :peer],
        current_level: 2,
        approvals: [
          %{
            level: :self,
            approver: :test_approver1,
            status: :approved,
            conditions: [],
            timestamp: DateTime.add(DateTime.utc_now(), -3600, :second),
            comments: ""
          },
          %{
            level: :peer,
            approver: :test_approver2,
            status: :approved,
            conditions: [],
            timestamp: DateTime.utc_now(),
            comments: ""
          }
        ],
        final_status: :approved,
        completion_time: DateTime.utc_now()
      }
      
      summary = ApprovalSystem.summarize_approval_status(chain)
      
      assert summary.complete == true
      assert summary.final_status == :approved
    end
  end
  
  describe "predict_impact/3" do
    test "predicts impact of modifications on system" do
      # Create a proposal with modifications
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :reasoning_engine,
            scope: :parameter,
            type: :threshold,
            target: %{name: "confidence_threshold"},
            change: %{new_value: 0.8},
            rationale: "Improve precision"
          }
        ],
        expected_benefits: [
          %{
            description: "Higher precision",
            impact: 0.3
          }
        ],
        source: :test
      }
      
      # Simple system state for testing
      system_state = %{
        components: %{
          reasoning_engine: %{
            parameters: %{
              confidence_threshold: 0.5
            }
          }
        }
      }
      
      prediction = ImpactPrediction.predict_impact(proposal, system_state)
      
      assert is_map(prediction)
      assert is_list(prediction.positive_impacts)
      assert is_list(prediction.negative_impacts)
      assert is_list(prediction.uncertain_impacts)
      assert is_float(prediction.system_risk)
      assert is_float(prediction.confidence)
      assert is_list(prediction.side_effects)
      
      # Should be in range 0-1
      assert prediction.system_risk >= 0.0 and prediction.system_risk <= 1.0
      assert prediction.confidence >= 0.0 and prediction.confidence <= 1.0
    end
    
    test "analyzes different types of modifications" do
      # Create a proposal with different types of modifications
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :reasoning_engine,
            scope: :parameter,
            type: :threshold,
            target: %{name: "threshold"},
            change: %{new_value: 0.8},
            rationale: "Test"
          },
          %{
            component: :neural_system,
            scope: :structure,
            type: :add_component,
            target: %{name: "new_layer"},
            change: %{operation: :add},
            rationale: "Test"
          },
          %{
            component: :decision_system,
            scope: :behavior,
            type: :update_behavior,
            target: %{name: "decision_policy"},
            change: %{specification: "new policy"},
            rationale: "Test"
          }
        ],
        expected_benefits: [
          %{
            description: "Test benefit",
            impact: 0.3
          }
        ],
        source: :test
      }
      
      system_state = %{}
      
      prediction = ImpactPrediction.predict_impact(proposal, system_state)
      
      # Should analyze all modifications
      assert length(prediction.positive_impacts) + 
             length(prediction.negative_impacts) + 
             length(prediction.uncertain_impacts) > 0
    end
  end
  
  describe "evaluate_safety/3" do
    test "evaluates safety based on impact prediction" do
      # Safe prediction
      safe_prediction = %{
        positive_impacts: [
          %{area: :performance, magnitude: 0.6, description: "Improved performance"}
        ],
        negative_impacts: [
          %{area: :resource_usage, magnitude: 0.3, description: "Slightly increased memory usage"}
        ],
        uncertain_impacts: [],
        system_risk: 0.3,  # Low risk
        confidence: 0.8,  # High confidence
        side_effects: [
          %{
            description: "Minor side effect",
            probability: 0.3,
            severity: 0.2,
            affected_components: [:component1],
            mitigation: "No action needed"
          }
        ]
      }
      
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :test,
            scope: :parameter,
            type: :test,
            target: %{},
            change: %{}
          }
        ]
      }
      
      result = ImpactPrediction.evaluate_safety(proposal, safe_prediction)
      
      assert {:ok, evaluation} = result
      assert evaluation.safe == true
      
      # Unsafe prediction - high risk
      unsafe_prediction = %{
        positive_impacts: [],
        negative_impacts: [
          %{area: :safety, magnitude: 0.8, description: "High safety impact"}  # High negative impact
        ],
        uncertain_impacts: [],
        system_risk: 0.8,  # High risk
        confidence: 0.7,
        side_effects: []
      }
      
      result = ImpactPrediction.evaluate_safety(proposal, unsafe_prediction)
      
      assert {:error, issues} = result
      assert is_list(issues)
      assert length(issues) > 0
    end
    
    test "respects safety thresholds in options" do
      prediction = %{
        positive_impacts: [],
        negative_impacts: [],
        uncertain_impacts: [],
        system_risk: 0.6,  # Medium risk
        confidence: 0.65,  # Medium confidence
        side_effects: []
      }
      
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :test,
            scope: :parameter,
            type: :test,
            target: %{},
            change: %{}
          }
        ]
      }
      
      # With default thresholds - should be safe
      result1 = ImpactPrediction.evaluate_safety(proposal, prediction)
      assert {:ok, _} = result1
      
      # With stricter thresholds - should be unsafe
      options = [
        risk_threshold: 0.5,  # Lower risk threshold
        confidence_threshold: 0.7  # Higher confidence threshold
      ]
      
      result2 = ImpactPrediction.evaluate_safety(proposal, prediction, options)
      assert {:error, _} = result2
    end
  end
  
  describe "apply_modifications/3" do
    test "applies modifications to system state" do
      # Create a proposal with modifications
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :reasoning_engine,
            scope: :parameter,
            type: :threshold,
            target: %{name: "confidence_threshold"},
            change: %{new_value: 0.8},
            rationale: "Improve precision"
          }
        ]
      }
      
      # System state for testing
      system_state = %{
        components: %{
          reasoning_engine: %{
            parameters: %{
              confidence_threshold: 0.5
            }
          }
        }
      }
      
      result = SafeExecution.apply_modifications(proposal, system_state)
      
      assert is_map(result)
      assert result.success == true
      assert is_list(result.applied_modifications)
      assert length(result.applied_modifications) == 1
      assert Enum.empty?(result.failed_modifications)
      assert Enum.empty?(result.errors)
      assert is_integer(result.execution_time)
      assert result.rollback_status == :not_needed
    end
    
    test "handles errors and performs rollback" do
      # For this test, we'll mock some behavior by having a modification
      # that will surely fail due to missing required fields
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :valid_component,
            scope: :parameter,
            type: :threshold,
            target: %{name: "valid_param"},
            change: %{new_value: 0.8},
            rationale: "This should succeed"
          },
          %{
            # This will fail because it's missing required fields
            component: :invalid_component,
            scope: :invalid_scope,
            target: %{},
            change: %{}
          }
        ]
      }
      
      system_state = %{}
      
      # The execution should fail and rollback
      result = SafeExecution.apply_modifications(proposal, system_state)
      
      # The overall execution should fail
      assert result.success == false
      
      # The first modification should be applied
      assert length(result.applied_modifications) == 1
      
      # The second modification should fail
      assert length(result.failed_modifications) == 1
      
      # There should be at least one error
      assert length(result.errors) > 0
      
      # Rollback should have been performed
      assert result.rollback_status == :successful
    end
  end
  
  describe "verify_system_state/2" do
    test "verifies system state after modifications" do
      system_state = %{
        components: %{},
        resources: %{},
        capabilities: %{}
      }
      
      result = SafeExecution.verify_system_state(system_state)
      
      assert {:ok, verification} = result
      assert verification.verified == true
      assert is_list(verification.checks_passed)
      assert length(verification.checks_passed) > 0
    end
  end
  
  describe "propose_modification/5" do
    test "creates a complete proposal package" do
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
          description: "Higher precision",
          impact: 0.3,
          areas: [:reasoning]
        }
      ]
      
      source = :test
      
      system_state = %{
        components: %{
          reasoning_engine: %{
            parameters: %{
              confidence_threshold: 0.5
            }
          }
        }
      }
      
      result = SelfModification.propose_modification(
        modifications,
        expected_benefits,
        source,
        system_state
      )
      
      assert is_map(result)
      assert Map.has_key?(result, :proposal)
      assert Map.has_key?(result, :impact_prediction)
      assert Map.has_key?(result, :safety_result)
      assert Map.has_key?(result, :approval_chain)
      assert Map.has_key?(result, :status)
      
      assert result.status == :pending_approval
    end
    
    test "returns validation errors for invalid proposals" do
      # Invalid modification (missing required fields)
      modifications = [
        %{
          # Missing component and other required fields
          scope: :parameter,
          type: :threshold
        }
      ]
      
      expected_benefits = [
        %{
          description: "Test benefit",
          impact: 0.3
        }
      ]
      
      result = SelfModification.propose_modification(
        modifications,
        expected_benefits,
        :test,
        %{}
      )
      
      assert is_map(result)
      assert Map.has_key?(result, :proposal)
      assert Map.has_key?(result, :errors)
      assert Map.has_key?(result, :status)
      
      assert result.status == :validation_failed
      assert is_list(result.errors)
      assert length(result.errors) > 0
    end
  end
  
  describe "process_approved_modification/3" do
    test "processes and applies approved modifications" do
      # Create a proposal package with an approved proposal
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :reasoning_engine,
            scope: :parameter,
            type: :threshold,
            target: %{name: "confidence_threshold"},
            change: %{new_value: 0.8},
            rationale: "Improve precision"
          }
        ],
        expected_benefits: [
          %{
            description: "Higher precision",
            impact: 0.3
          }
        ],
        source: :test
      }
      
      # Create an approved approval chain
      approval_chain = %{
        levels: [:self, :peer],
        current_level: 2,  # Beyond the last level
        approvals: [
          %{
            level: :self,
            approver: :test_approver1,
            status: :approved,
            conditions: [],
            timestamp: DateTime.utc_now(),
            comments: ""
          },
          %{
            level: :peer,
            approver: :test_approver2,
            status: :approved,
            conditions: [],
            timestamp: DateTime.utc_now(),
            comments: ""
          }
        ],
        final_status: :approved,
        completion_time: DateTime.utc_now()
      }
      
      proposal_package = %{
        proposal: proposal,
        approval_chain: approval_chain
      }
      
      system_state = %{
        components: %{
          reasoning_engine: %{
            parameters: %{
              confidence_threshold: 0.5
            }
          }
        }
      }
      
      result = SelfModification.process_approved_modification(
        proposal_package,
        system_state
      )
      
      assert is_map(result)
      assert Map.has_key?(result, :proposal)
      assert Map.has_key?(result, :execution_result)
      assert Map.has_key?(result, :verification_result)
      assert Map.has_key?(result, :status)
      
      assert result.status == :applied
      assert result.execution_result.success == true
    end
    
    test "rejects non-approved proposals" do
      # Create a proposal package with a non-approved proposal
      proposal = %{
        id: "test-id",
        modifications: [
          %{
            component: :test,
            scope: :parameter,
            type: :test,
            target: %{},
            change: %{}
          }
        ],
        expected_benefits: [],
        source: :test
      }
      
      # Create a rejected approval chain
      approval_chain = %{
        levels: [:self, :peer],
        current_level: 0,
        approvals: [
          %{
            level: :self,
            approver: :test_approver,
            status: :rejected,
            conditions: [],
            timestamp: DateTime.utc_now(),
            comments: "Rejected for testing"
          }
        ],
        final_status: :rejected,
        completion_time: DateTime.utc_now()
      }
      
      proposal_package = %{
        proposal: proposal,
        approval_chain: approval_chain
      }
      
      result = SelfModification.process_approved_modification(
        proposal_package,
        %{}
      )
      
      assert is_map(result)
      assert Map.has_key?(result, :proposal)
      assert Map.has_key?(result, :error)
      assert Map.has_key?(result, :status)
      
      assert result.status == :not_approved
    end
  end
end