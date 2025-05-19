# This script runs the Autonomous Governance demo
# Usage: mix run run_governance_demo.exs

# Set the environment variable to trigger the demo
System.put_env("RUN_DEMO", "true")

# Load the demo module
Code.require_file("lib/automata/examples/demos/autonomous_governance_demo.ex", __DIR__)

# Run the demo
Automata.AutonomousGovernanceDemo.run()