defmodule Automata.Domain.Agent.Config do
  @moduledoc """
  Configuration schema for agents.
  """
  
  alias Ecto.Changeset
  use Ecto.Schema
  
  @primary_key false
  embedded_schema do
    field :id, :string
    field :type, :atom
    field :node_type, :atom
    field :tick_freq, :integer, default: 50
    field :children, {:array, :any}, default: []
    field :settings, :map, default: %{}
  end
  
  @doc """
  Validates an agent configuration.
  """
  def validate(config) when is_map(config) do
    %__MODULE__{}
    |> Changeset.cast(config, [:id, :type, :node_type, :tick_freq, :children, :settings])
    |> Changeset.validate_required([:type])
    |> Changeset.validate_inclusion(:type, [:behavior_tree, :tweann, :bandit])
    |> ensure_id()
    |> validate_by_type()
    |> case do
      %{valid?: true} = changeset ->
        {:ok, Changeset.apply_changes(changeset)}
        
      changeset ->
        {:error, changeset}
    end
  end
  
  def validate(config) when is_list(config) do
    config
    |> Map.new()
    |> validate()
  end
  
  defp ensure_id(changeset) do
    case Changeset.get_field(changeset, :id) do
      nil -> Changeset.put_change(changeset, :id, generate_id())
      _ -> changeset
    end
  end
  
  defp validate_by_type(changeset) do
    case Changeset.get_field(changeset, :type) do
      :behavior_tree ->
        changeset
        |> Changeset.validate_required([:node_type])
        |> validate_behavior_tree_node_type()
        
      :tweann ->
        changeset
        
      :bandit ->
        changeset
        |> validate_bandit_config()
        
      _ ->
        changeset
    end
  end
  
  defp validate_behavior_tree_node_type(changeset) do
    valid_node_types = [:sequence, :selector, :parallel, :action, :condition, :decorator]
    
    changeset
    |> Changeset.validate_inclusion(:node_type, valid_node_types)
  end
  
  defp validate_bandit_config(changeset) do
    settings = Changeset.get_field(changeset, :settings) || %{}
    
    if is_map(settings) do
      # Validate bandit-specific settings
      changeset
    else
      Changeset.add_error(changeset, :settings, "must be a map")
    end
  end
  
  defp generate_id, do: System.unique_integer([:positive, :monotonic]) |> to_string()
end