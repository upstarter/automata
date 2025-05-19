defmodule Automata.Infrastructure.Config.Schema do
  @moduledoc """
  A schema definition system for validating configurations throughout Automata.
  
  This module provides a standard way to define and validate configuration schemas
  using Ecto's changesets.
  """
  
  defmacro __using__(opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Automata.Infrastructure.Config.Schema
      
      @primary_key false
      embedded_schema do
        unquote(Keyword.get(opts, :schema_block, nil))
      end
      
      def changeset(schema \\ %__MODULE__{}, params) do
        schema
        |> cast(params, __schema__(:fields))
        |> validate_required(Keyword.get(unquote(opts), :required_fields, []))
        |> apply_custom_validations()
      end
      
      def validate(params) when is_map(params) do
        %__MODULE__{}
        |> changeset(params)
        |> apply_changes_or_error()
      end
      
      def validate(params) when is_list(params) do
        params
        |> Map.new()
        |> validate()
      end
      
      defp apply_changes_or_error(changeset) do
        if changeset.valid? do
          {:ok, Ecto.Changeset.apply_changes(changeset)}
        else
          {:error, changeset}
        end
      end
      
      defp apply_custom_validations(changeset) do
        changeset
      end
      
      defoverridable apply_custom_validations: 1
    end
  end
  
  @doc """
  Ensures a field or generated field contains a unique ID.
  """
  def ensure_id(changeset, field \\ :id) do
    case Ecto.Changeset.get_field(changeset, field) do
      nil -> Ecto.Changeset.put_change(changeset, field, generate_id())
      _ -> changeset
    end
  end
  
  @doc """
  Generates a unique ID suitable for distributed systems.
  """
  def generate_id do
    prefix = node_prefix()
    unique = System.unique_integer([:positive, :monotonic])
    time = System.system_time(:millisecond)
    "#{prefix}-#{time}-#{unique}"
  end
  
  @doc """
  Returns a prefix based on the current node name for distributed IDs.
  """
  def node_prefix do
    node_name = Atom.to_string(Node.self())
    
    if String.contains?(node_name, "@") do
      node_name
      |> String.split("@")
      |> List.first()
      |> String.replace(~r/[^a-zA-Z0-9]/, "")
    else
      "automata"
    end
  end
end