# This script runs the Integration & Deployment demo
# Usage: mix run run_integration_deployment_demo.exs

# Set the environment variable to trigger the demo
System.put_env("RUN_DEMO", "true")

# Load the demo module
Code.require_file("lib/automata/examples/demos/integration_deployment_demo.ex", __DIR__)

# Run the demo
Automata.IntegrationDeploymentDemo.run()