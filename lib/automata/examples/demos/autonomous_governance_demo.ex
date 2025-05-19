defmodule Automata.AutonomousGovernanceDemo do
  @moduledoc """
  Demonstration of the Autonomous Governance capabilities.
  
  This module provides a simple demonstration of:
  - Self-Regulation with norms, compliance monitoring, and reputation
  - Distributed Governance with zones and decision making
  - Adaptive Institutions with evaluation and adaptation
  """
  
  alias Automata.AutonomousGovernance
  alias Automata.AutonomousGovernance.SelfRegulation
  alias Automata.AutonomousGovernance.DistributedGovernance
  alias Automata.AutonomousGovernance.AdaptiveInstitutions
  
  @doc """
  Run the demo.
  """
  def run do
    IO.puts("\n=== Autonomous Governance Demo ===\n")
    
    # Step 1: Create a governance system
    IO.puts("Step 1: Creating a governance system...")
    {:ok, system} = create_governance_system()
    IO.puts("  Created governance system with components:")
    IO.puts("  - Zone ID: #{system.zone_id}")
    IO.puts("  - Institution ID: #{system.institution_id}")
    IO.puts("  - Norms: #{length(system.norms)} norms defined")
    
    # Step 2: Register agents
    IO.puts("\nStep 2: Registering agents...")
    agents = register_agents(system.zone_id, system.institution_id)
    IO.puts("  Registered #{length(agents)} agents")
    
    # Step 3: Record norm observations
    IO.puts("\nStep 3: Recording norm observations...")
    record_observations(system.norms, agents)
    
    # Step 4: Make a governance decision
    IO.puts("\nStep 4: Making a governance decision...")
    {:ok, decision_id} = make_decision(system.zone_id, agents)
    IO.puts("  Created decision #{decision_id}")
    
    # Step 5: Vote on the decision
    IO.puts("\nStep 5: Voting on the decision...")
    record_votes(system.zone_id, decision_id, agents)
    
    # Step 6: Evaluate the institution
    IO.puts("\nStep 6: Evaluating the institution...")
    {:ok, evaluation} = AdaptiveInstitutions.evaluate_institution(system.institution_id)
    IO.puts("  Institution evaluation score: #{Float.round(evaluation.overall_score, 2)}")
    
    # Step 7: Propose an adaptation
    IO.puts("\nStep 7: Proposing an adaptation...")
    {:ok, adaptation_id} = propose_adaptation(system.institution_id, agents)
    IO.puts("  Created adaptation proposal #{adaptation_id}")
    
    # Step 8: Implement the adaptation
    IO.puts("\nStep 8: Implementing the adaptation...")
    AdaptiveInstitutions.implement_adaptation(system.institution_id, adaptation_id, %{})
    IO.puts("  Implemented adaptation #{adaptation_id}")
    
    # Step 9: Get governance metrics
    IO.puts("\nStep 9: Getting governance metrics...")
    {:ok, metrics} = DistributedGovernance.get_zone_metrics(system.zone_id)
    IO.puts("  Participation rate: #{Float.round(metrics.participation_rate * 100, 1)}%")
    IO.puts("  Consensus score: #{Float.round(metrics.consensus_metrics.avg_consensus_score, 2)}")
    
    # Step 10: Get reputation scores
    IO.puts("\nStep 10: Getting reputation scores...")
    get_reputations(agents)
    
    IO.puts("\n=== Demo Complete ===")
    
    :ok
  end
  
  # Helper functions
  
  defp create_governance_system do
    # Define governance system
    governance_config = %{
      description: "Demo Governance System",
      decision_mechanism: :majority,
      norms: [
        %{name: "resource_sharing", 
          specification: %{
            description: "Share resources fairly with other agents",
            condition: %{action: "resource_use"},
            compliance: %{action: "share_resources"},
            violation: %{action: "hoard_resources"},
            sanctions: [:reputation_penalty]
          },
          contexts: ["resource_management"]
        },
        %{name: "truthful_reporting", 
          specification: %{
            description: "Report information truthfully",
            condition: %{action: "report_information"},
            compliance: %{action: "report_truthfully"},
            violation: %{action: "report_falsely"},
            sanctions: [:reputation_penalty, :capability_restriction]
          },
          contexts: ["information_sharing"]
        }
      ],
      adaptation_mechanisms: %{
        auto_adapt: true,
        triggers: [
          %{
            metric: :participation_rate,
            condition: :below,
            threshold: 0.4,
            adaptation_type: :mechanism_change,
            adaptation_template: %{
              threshold: 0.4,
              changes: %{
                adaptation_mechanisms: %{
                  incentives: %{
                    participation_bonus: true
                  }
                }
              }
            }
          }
        ]
      }
    }
    
    AutonomousGovernance.setup_governance_system("Demo Governance", governance_config)
  end
  
  defp register_agents(zone_id, institution_id) do
    # Register some agents in the governance system
    agent_configs = [
      {"agent_1", %{roles: %{moderator: true}}},
      {"agent_2", %{roles: %{contributor: true}}},
      {"agent_3", %{roles: %{contributor: true}}},
      {"agent_4", %{roles: %{observer: true}}},
      {"agent_5", %{roles: %{contributor: true}}}
    ]
    
    # Register agents
    Enum.map(agent_configs, fn {agent_id, config} ->
      {:ok, _} = DistributedGovernance.register_in_zone(zone_id, agent_id, config.roles)
      {:ok, _} = AdaptiveInstitutions.join_institution(institution_id, agent_id, config)
      agent_id
    end)
  end
  
  defp record_observations(norms, agents) do
    # Record some random observations
    norm = List.first(norms)
    
    # Some compliance observations
    Enum.each(1..8, fn _ ->
      agent = Enum.random(agents)
      SelfRegulation.record_observation(
        norm.id, 
        agent,
        :comply,
        %{action: "share_resources", amount: :rand.uniform(100)}
      )
    end)
    
    # Some violation observations
    Enum.each(1..3, fn _ ->
      agent = Enum.random(agents)
      SelfRegulation.record_observation(
        norm.id, 
        agent,
        :violate,
        %{action: "hoard_resources", amount: :rand.uniform(100)}
      )
    end)
    
    # Print some stats
    {:ok, stats} = SelfRegulation.ComplianceMonitor.get_norm_compliance_stats(norm.id)
    IO.puts("  Recorded observations for norm #{norm.id}:")
    IO.puts("    Compliant: #{stats.comply_count}")
    IO.puts("    Violations: #{stats.violate_count}")
    IO.puts("    Compliance rate: #{Float.round(stats.compliance_rate * 100, 1)}%")
  end
  
  defp make_decision(zone_id, agents) do
    # Make a resource allocation decision
    proposer = List.first(agents)
    
    DistributedGovernance.propose_decision(
      zone_id,
      proposer,
      %{
        type: :resource_allocation,
        description: "Allocate additional computational resources",
        details: %{
          resource_type: "computation",
          amount: 100,
          distribution: "proportional",
          justification: "Needed for upcoming processing requirements"
        },
        justification: "Performance optimization for complex operations"
      }
    )
  end
  
  defp record_votes(zone_id, decision_id, agents) do
    # Record votes from agents
    votes = [
      {Enum.at(agents, 0), :for},
      {Enum.at(agents, 1), :for},
      {Enum.at(agents, 2), :against},
      {Enum.at(agents, 3), :abstain},
      {Enum.at(agents, 4), :for}
    ]
    
    # Record votes
    Enum.each(votes, fn {agent_id, vote} ->
      {:ok, :recorded} = DistributedGovernance.vote_on_decision(
        zone_id,
        decision_id,
        agent_id,
        vote,
        %{reason: "Agent #{agent_id} #{vote} vote"}
      )
    end)
    
    # Get decision details
    {:ok, decision} = DistributedGovernance.get_decision(zone_id, decision_id)
    IO.puts("  Decision status: #{decision.status}")
    IO.puts("  Votes: #{length((decision.votes[:for] || []) ++ (decision.votes[:against] || []) ++ (decision.votes[:abstain] || []))}")
  end
  
  defp propose_adaptation(institution_id, agents) do
    # Propose an adaptation to the institution
    proposer = Enum.at(agents, 0)
    
    AdaptiveInstitutions.propose_adaptation(
      institution_id,
      proposer,
      %{
        type: :mechanism_change,
        description: "Improve decision making with weighted voting",
        changes: %{
          adaptation_mechanisms: %{
            decision_mechanism: :weighted
          }
        },
        justification: "Weighted voting will better represent agent expertise and reputation"
      }
    )
  end
  
  defp get_reputations(agents) do
    # Get reputation for each agent
    Enum.each(agents, fn agent_id ->
      {:ok, reputation} = SelfRegulation.get_reputation(agent_id)
      IO.puts("  Agent #{agent_id} reputation: #{Float.round(reputation, 2)}")
    end)
  end
end

# Run the demo when executed directly
if System.get_env("RUN_DEMO") == "true" do
  Automata.AutonomousGovernanceDemo.run()
end