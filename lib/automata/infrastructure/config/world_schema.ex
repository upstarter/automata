defmodule Automata.Infrastructure.Config.WorldSchema do
  @moduledoc """
  Schema for world configuration.
  """
  use Automata.Infrastructure.Config.Schema,
    required_fields: [:name],
    schema_block: quote do
      field :id, :string
      field :name, :string
      field :description, :string
      field :version, :string, default: "1.0.0"
      field :tick_rate, :integer, default: 50
      field :max_agents, :integer, default: 1000
      field :persistence_enabled, :boolean, default: false
      field :persistence_backend, Ecto.Enum, values: [:memory, :disk, :database], default: :memory
      field :logging_level, Ecto.Enum, values: [:debug, :info, :warning, :error], default: :info
      field :distribution_strategy, Ecto.Enum, values: [:local, :distributed], default: :distributed
      field :load_balancing, Ecto.Enum, values: [:none, :uniform, :weighted], default: :uniform
      field :timeouts, :map, default: %{
        agent_tick: 5_000,
        agent_init: 10_000,
        agent_shutdown: 5_000
      }
      field :shared_state, :map, default: %{}
      field :agents, {:array, :map}, default: []
      field :tags, {:array, :string}, default: []
      field :custom, :map, default: %{}
    end
  
  defp apply_custom_validations(changeset) do
    changeset
    |> ensure_id()
    |> validate_agents()
    |> validate_tick_rate()
    |> validate_version_format()
  end
  
  defp validate_agents(changeset) do
    agents = get_field(changeset, :agents) || []
    
    if is_list(agents) do
      changeset
    else
      add_error(changeset, :agents, "must be a list")
    end
  end
  
  defp validate_tick_rate(changeset) do
    tick_rate = get_field(changeset, :tick_rate)
    
    if tick_rate > 0 do
      changeset
    else
      add_error(changeset, :tick_rate, "must be greater than 0")
    end
  end
  
  defp validate_version_format(changeset) do
    version = get_field(changeset, :version)
    
    if version && !Regex.match?(~r/^\d+\.\d+\.\d+$/, version) do
      add_error(changeset, :version, "must be in the format x.y.z")
    else
      changeset
    end
  end
end