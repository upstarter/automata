# Configure ExUnit
ExUnit.configure(
  exclude: [
    # Exclude tests marked as pending
    pending: true,
    
    # Exclude slow tests by default
    # Run with: mix test --include slow
    slow: true,
    
    # Exclude distributed tests by default
    # Run with: mix test --include distributed
    distributed: true
  ],
  
  # More descriptive test output
  trace: false,
  
  # Add colors to terminal output
  colors: [
    enabled: true,
    failed: :red,
    success: :green,
    skipped: :yellow
  ],
  
  # Increase timeouts for distributed tests
  timeout: 60_000,
  
  # Determine if tests should run in a randomized or deterministic order
  seed: :os.timestamp |> elem(2)  # Use this for random order
  # seed: 0  # Use this for deterministic order
)

# Start ExUnit
ExUnit.start()

# Load support files if they exist
support_dir = Path.join(__DIR__, "support")

if File.dir?(support_dir) do
  support_dir
  |> File.ls!()
  |> Enum.filter(&String.ends_with?(&1, ".ex"))
  |> Enum.each(fn file ->
    Code.require_file("support/#{file}", __DIR__)
  end)
end

# Helper to check if we're running on CI
defmodule TestEnv do
  def ci? do
    System.get_env("CI") == "true"
  end
  
  def distributed_tests_enabled? do
    System.get_env("ENABLE_DISTRIBUTED_TESTS") == "true" || !ci?()
  end
end
