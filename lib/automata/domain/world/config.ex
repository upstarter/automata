defmodule Automata.Domain.World.Config do
  @moduledoc """
  Configuration schema for worlds.
  """
  
  alias Ecto.Changeset
  use Ecto.Schema
  
  @primary_key false
  embedded_schema do
    field :id, :string
    field :name, :string
    field :automata, {:array, :map}, default: []
    field :settings, :map, default: %{}
  end
  
  @doc """
  Validates a world configuration.
  """
  def validate(config) when is_map(config) do
    %__MODULE__{}
    |> Changeset.cast(config, [:id, :name, :automata, :settings])
    |> Changeset.validate_required([:name])
    |> ensure_id()
    |> validate_automata()
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
  
  defp validate_automata(changeset) do
    automata = Changeset.get_field(changeset, :automata) || []
    
    if is_list(automata) do
      changeset
    else
      Changeset.add_error(changeset, :automata, "must be a list")
    end
  end
  
  defp generate_id, do: System.unique_integer([:positive, :monotonic]) |> to_string()
end