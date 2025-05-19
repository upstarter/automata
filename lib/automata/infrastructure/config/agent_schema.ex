defmodule Automata.Infrastructure.Config.AgentSchema do
  @moduledoc """
  Schema for agent configuration.
  """
  use Automata.Infrastructure.Config.Schema,
    required_fields: [:type],
    schema_block: quote do
      field :id, :string
      field :name, :string
      field :type, Ecto.Enum, values: [:behavior_tree, :reinforcement_learning, :neuroevolution]
      field :world_id, :string
      field :node_type, :atom
      field :tick_freq, :integer, default: 50
      field :restart_strategy, Ecto.Enum, values: [:permanent, :temporary, :transient], default: :permanent
      field :max_restarts, :integer, default: 5
      field :shutdown_timeout, :integer, default: 5_000
      field :children, {:array, :any}, default: []
      field :initial_state, :map, default: %{}
      field :priority, :integer, default: 0
      field :tags, {:array, :string}, default: []
      field :custom, :map, default: %{}
    end
  
  defp apply_custom_validations(changeset) do
    changeset
    |> ensure_id()
    |> validate_by_type()
    |> validate_tick_freq()
    |> validate_name()
    |> validate_max_restarts()
  end
  
  defp validate_by_type(changeset) do
    case get_field(changeset, :type) do
      :behavior_tree ->
        changeset
        |> validate_required([:node_type])
        |> validate_behavior_tree_node_type()
        
      :reinforcement_learning ->
        changeset
        |> validate_rl_config()
        
      :neuroevolution ->
        changeset
        |> validate_neuroevolution_config()
        
      nil ->
        changeset
    end
  end
  
  defp validate_behavior_tree_node_type(changeset) do
    node_type = get_field(changeset, :node_type)
    
    valid_node_types = [:sequence, :selector, :parallel, :action, :condition, :decorator]
    
    if node_type in valid_node_types do
      changeset
    else
      add_error(changeset, :node_type, "must be one of #{inspect(valid_node_types)}")
    end
  end
  
  defp validate_rl_config(changeset) do
    # RL agents will be implemented in the future
    changeset
  end
  
  defp validate_neuroevolution_config(changeset) do
    # Neuroevolution agents will be implemented in the future
    changeset
  end
  
  defp validate_tick_freq(changeset) do
    tick_freq = get_field(changeset, :tick_freq)
    
    if tick_freq && tick_freq > 0 do
      changeset
    else
      add_error(changeset, :tick_freq, "must be greater than 0")
    end
  end
  
  defp validate_name(changeset) do
    name = get_field(changeset, :name)
    id = get_field(changeset, :id)
    
    if is_nil(name) && !is_nil(id) do
      put_change(changeset, :name, "agent-#{id}")
    else
      changeset
    end
  end
  
  defp validate_max_restarts(changeset) do
    max_restarts = get_field(changeset, :max_restarts)
    
    if max_restarts && max_restarts >= 0 do
      changeset
    else
      add_error(changeset, :max_restarts, "must be greater than or equal to 0")
    end
  end
end