defmodule Automata.Infrastructure.AgentSystem.BaseSchema do
  @moduledoc """
  Base schema for agent configuration validation.
  
  This module provides a base schema that all agent types can extend
  with their type-specific fields and validation rules. It ensures
  that all agent configurations have a consistent structure and
  validation approach.
  """
  
  @doc """
  Creates a changeset for validating agent configuration.
  
  Takes a schema module, a configuration map, and optional validation options.
  Returns an Ecto.Changeset that can be used for validation.
  """
  def changeset(schema_module, config, opts \\ []) do
    # Convert list config to map if necessary
    config = if is_list(config), do: Map.new(config), else: config
    
    # Get schema struct
    schema_struct = struct(schema_module)
    
    # Get list of allowed fields from schema module
    allowed_fields = schema_module.__schema__(:fields)
    
    # Create changeset
    Ecto.Changeset.cast(schema_struct, config, allowed_fields)
    |> validate_base_fields(opts)
    |> schema_module.validate(opts)
  end
  
  @doc """
  Validates a configuration against a schema module.
  
  Takes a schema module and a configuration map.
  Returns `{:ok, validated_config}` if the configuration is valid,
  or `{:error, changeset}` if it is invalid.
  """
  def validate(schema_module, config, opts \\ []) do
    changeset = changeset(schema_module, config, opts)
    
    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, format_changeset_errors(changeset)}
    end
  end
  
  @doc """
  Creates a schema module for an agent type.
  
  This macro defines a new Ecto schema module for an agent type,
  including the base fields required for all agent types.
  
  ## Example
  
  ```elixir
  defmodule MyAgentType.Schema do
    use Automata.Infrastructure.AgentSystem.BaseSchema
    
    schema_fields do
      field :strategy, :atom, default: :default
      field :learning_rate, :float, default: 0.1
    end
    
    def validate(changeset, _opts) do
      changeset
      |> Ecto.Changeset.validate_inclusion(:strategy, [:default, :aggressive, :cautious])
      |> Ecto.Changeset.validate_number(:learning_rate, greater_than: 0, less_than_or_equal_to: 1)
    end
  end
  ```
  """
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import unquote(__MODULE__), only: [schema_fields: 1]
      
      @primary_key false
      embedded_schema do
        field :id, :string
        field :type, :atom
        field :world_id, :string
        field :tick_freq, :integer, default: 50
        field :settings, :map, default: %{}
      end
      
      @doc """
      Validates the agent configuration.
      
      This function should be implemented by all agent type schemas
      to perform type-specific validation of the configuration.
      """
      def validate(changeset, _opts), do: changeset
      
      defoverridable validate: 2
    end
  end
  
  @doc """
  Defines additional schema fields for an agent type.
  
  This macro allows agent type schemas to define type-specific
  fields in addition to the base fields required for all agent types.
  """
  defmacro schema_fields(do: block) do
    quote do
      def __additional_fields__, do: unquote(block)
      
      defmodule Fields do
        use Ecto.Schema
        
        @primary_key false
        embedded_schema do
          unquote(block)
        end
      end
      
      # Add additional fields to the schema
      for {name, type} <- Fields.__schema__(:fields) |> Enum.map(fn field ->
        {field, Fields.__schema__(:type, field)}
      end) do
        Module.put_attribute(__MODULE__, :field_info, {name, type})
      end
    end
  end
  
  # Private helpers
  
  defp validate_base_fields(changeset, opts) do
    changeset
    |> Ecto.Changeset.validate_required([:type])
    |> ensure_id()
    |> validate_tick_freq(opts)
  end
  
  defp ensure_id(changeset) do
    case Ecto.Changeset.get_field(changeset, :id) do
      nil -> 
        Ecto.Changeset.put_change(changeset, :id, generate_id())
      _ -> 
        changeset
    end
  end
  
  defp validate_tick_freq(changeset, opts) do
    min_tick = Keyword.get(opts, :min_tick_freq, 10)
    max_tick = Keyword.get(opts, :max_tick_freq, 1000)
    
    Ecto.Changeset.validate_number(changeset, :tick_freq, 
      greater_than_or_equal_to: min_tick,
      less_than_or_equal_to: max_tick
    )
  end
  
  defp generate_id do
    "agent-" <> (System.system_time(:millisecond) |> to_string()) <> "-" <> (System.unique_integer([:positive, :monotonic]) |> to_string())
  end
  
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end