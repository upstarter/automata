defmodule Automata.Infrastructure.Config.SystemSchema do
  @moduledoc """
  Schema for the overall system configuration.
  """
  use Automata.Infrastructure.Config.Schema,
    required_fields: [:node_name, :environment],
    schema_block: quote do
      field :node_name, :string
      field :environment, Ecto.Enum, values: [:development, :test, :production]
      field :distribution_mode, Ecto.Enum, values: [:none, :local, :cluster], default: :local
      field :cluster_strategy, Ecto.Enum, values: [:gossip, :kubernetes, :epmd], default: :gossip
      field :log_level, Ecto.Enum, values: [:debug, :info, :warning, :error], default: :info
      field :metrics_enabled, :boolean, default: true
      field :telemetry_enabled, :boolean, default: false
      field :max_connections, :integer, default: 1000
      field :timeouts, :map, default: %{
        operation: 30_000,
        shutdown: 10_000,
        connection: 5_000
      }
      field :custom, :map, default: %{}
    end
  
  defp apply_custom_validations(changeset) do
    changeset
    |> validate_cluster_strategy()
    |> validate_timeouts()
  end
  
  defp validate_cluster_strategy(changeset) do
    distribution_mode = get_field(changeset, :distribution_mode)
    
    if distribution_mode == :none do
      changeset
    else
      validate_required(changeset, [:cluster_strategy])
    end
  end
  
  defp validate_timeouts(changeset) do
    timeouts = get_field(changeset, :timeouts) || %{}
    
    if is_map(timeouts) do
      changeset
    else
      add_error(changeset, :timeouts, "must be a map")
    end
  end
end