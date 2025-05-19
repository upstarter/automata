defmodule Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Schema do
  @moduledoc """
  Schema for behavior tree agent configuration validation.
  
  This module defines the schema for validating behavior tree agent configurations,
  including type-specific fields and validation rules.
  """
  
  use Automata.Infrastructure.AgentSystem.BaseSchema
  
  schema_fields do
    field :node_type, :atom
    field :children, {:array, :map}, default: []
    field :success_threshold, :integer
    field :fail_threshold, :integer
  end
  
  @doc """
  Validates the behavior tree agent configuration.
  """
  def validate(changeset, _opts) do
    changeset
    |> validate_required([:node_type])
    |> validate_inclusion(:node_type, valid_node_types())
    |> validate_node_specific_fields()
  end
  
  @doc """
  Returns the list of valid node types for behavior trees.
  """
  def valid_node_types do
    [
      :sequence,
      :selector,
      :parallel,
      :action,
      :condition,
      :decorator
    ]
  end
  
  # Private helpers
  
  defp validate_node_specific_fields(changeset) do
    node_type = get_field(changeset, :node_type)
    
    case node_type do
      :parallel ->
        changeset
        |> validate_required([:success_threshold, :fail_threshold])
        |> validate_number(:success_threshold, greater_than: 0)
        |> validate_number(:fail_threshold, greater_than: 0)
        |> validate_children(min_count: 1)
        
      node_type when node_type in [:sequence, :selector] ->
        changeset
        |> validate_children(min_count: 1)
        
      node_type when node_type in [:action, :condition] ->
        changeset
        |> validate_children(max_count: 0)
        
      :decorator ->
        changeset
        |> validate_children(min_count: 1, max_count: 1)
        
      _ ->
        changeset
    end
  end
  
  defp validate_children(changeset, opts) do
    min_count = Keyword.get(opts, :min_count)
    max_count = Keyword.get(opts, :max_count)
    
    children = get_field(changeset, :children) || []
    
    cond do
      min_count && length(children) < min_count ->
        add_error(changeset, :children, "must have at least #{min_count} child(ren)")
        
      max_count && length(children) > max_count ->
        add_error(changeset, :children, "must have at most #{max_count} child(ren)")
        
      true ->
        changeset
    end
  end
end