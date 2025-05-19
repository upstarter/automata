defmodule Automata.Infrastructure.AgentSystem.AgentType do
  @moduledoc """
  Behavior that defines the interface for agent type implementations.
  
  This behavior must be implemented by all agent types in the system.
  It defines the core functionality required for agent type management,
  including initialization, configuration validation, state management,
  and lifecycle events.
  """
  
  @typedoc """
  The configuration for an agent type.
  """
  @type config :: map()
  
  @typedoc """
  The state of an agent implementation.
  """
  @type state :: map()
  
  @typedoc """
  The unique identifier for an agent.
  """
  @type agent_id :: String.t()
  
  @typedoc """
  The unique identifier for a world.
  """
  @type world_id :: String.t()
  
  @typedoc """
  The status of an agent.
  """
  @type status :: :initializing | :ready | :running | :paused | :error | :terminated
  
  @typedoc """
  The implementation of an agent.
  """
  @type implementation :: map()
  
  @doc """
  Returns the type identifier for this agent type.
  """
  @callback type() :: atom()
  
  @doc """
  Returns a description of this agent type.
  """
  @callback description() :: String.t()
  
  @doc """
  Returns the schema module used to validate the configuration for this agent type.
  """
  @callback schema() :: module()
  
  @doc """
  Validates a configuration for this agent type.
  
  Returns `{:ok, validated_config}` if the configuration is valid,
  or `{:error, reason}` if it is invalid.
  """
  @callback validate_config(config()) :: {:ok, config()} | {:error, term()}
  
  @doc """
  Initializes a new agent implementation with the given configuration.
  
  Returns `{:ok, implementation}` if initialization is successful,
  or `{:error, reason}` if it fails.
  """
  @callback init(agent_id(), world_id(), config()) :: {:ok, implementation()} | {:error, term()}
  
  @doc """
  Handles a tick event for the agent implementation.
  
  Returns `{:ok, updated_implementation}` if the tick is processed successfully,
  or `{:error, reason}` if it fails.
  """
  @callback handle_tick(implementation()) :: {:ok, implementation()} | {:error, term()}
  
  @doc """
  Terminates an agent implementation.
  
  Returns `:ok` if termination is successful,
  or `{:error, reason}` if it fails.
  """
  @callback terminate(implementation(), reason :: term()) :: :ok | {:error, term()}
  
  @doc """
  Returns the current status of an agent implementation.
  """
  @callback status(implementation()) :: status()
  
  @doc """
  Returns metadata about an agent implementation.
  """
  @callback metadata(implementation()) :: map()
  
  @doc """
  Returns a list of supported features for this agent type.
  
  Features are atoms that represent capabilities of the agent type,
  such as `:learning`, `:planning`, `:perception`, etc.
  """
  @callback features() :: [atom()]
  
  @optional_callbacks [
    description: 0,
    metadata: 1,
    features: 0
  ]
  
  @doc """
  Helper function to verify an agent type implementation.
  
  This function is used internally by the agent system to validate
  that an agent type implementation provides all required functionality.
  """
  def verify_implementation(module) do
    required_callbacks = [
      {:type, 0},
      {:schema, 0},
      {:validate_config, 1},
      {:init, 3},
      {:handle_tick, 1},
      {:terminate, 2},
      {:status, 1}
    ]
    
    missing = Enum.filter(required_callbacks, fn {fun, arity} ->
      not function_exported?(module, fun, arity)
    end)
    
    if missing == [] do
      :ok
    else
      missing_funs = Enum.map(missing, fn {fun, arity} -> "#{fun}/#{arity}" end)
      {:error, "Missing required callbacks: #{Enum.join(missing_funs, ", ")}"}
    end
  end
end