defmodule AtomType do
  @behaviour Ecto.Type
  def type, do: :atom

  def cast(value), do: {:ok, value}

  def load(value), do: {:ok, Atom.to_string(value)}

  def dump(value) when is_atom(value), do: {:ok, Atom.to_string(value)}

  def dump(_), do: :error
  def embed_as(_), do: :self
  def equal?(_, _), do: true
end
