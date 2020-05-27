defmodule Automata.FailuresManifest do
  @moduledoc false

  @type automaton_id :: {module, name :: atom}
  @opaque t :: %{automaton_id => automaton_file :: Path.t()}

  @manifest_vsn 1

  @spec new() :: t
  def new, do: %{}

  @spec automata_with_failures(t) :: MapSet.t(Path.t())
  def automata_with_failures(%{} = manifest) do
    manifest
    |> Map.values()
    |> MapSet.new()
  end

  @spec failed_automaton_ids(t) :: MapSet.t(automaton_id)
  def failed_automaton_ids(%{} = manifest) do
    manifest
    |> Map.keys()
    |> MapSet.new()
  end

  def put_automaton(%{} = manifest, %Automata.AutomatonInfo{state: nil} = automaton) do
    Map.delete(manifest, {automaton.module, automaton.name})
  end

  def put_automaton(%{} = manifest, %Automata.AutomatonInfo{state: {failed_state, _}} = automaton)
      when failed_state in [:failed, :invalid] do
    Map.put(manifest, {automaton.module, automaton.name}, automaton.tags.file)
  end

  @spec write!(t, Path.t()) :: :ok
  def write!(manifest, file) when is_binary(file) do
    binary = :erlang.term_to_binary({@manifest_vsn, manifest})
    Path.dirname(file) |> File.mkdir_p!()
    File.write!(file, binary)
  end

  @spec read(Path.t()) :: t
  def read(file) when is_binary(file) do
    with {:ok, binary} <- File.read(file),
         {:ok, {@manifest_vsn, manifest}} when is_map(manifest) <- safe_binary_to_term(binary) do
      manifest
    else
      _ -> new()
    end
  end

  defp safe_binary_to_term(binary) do
    {:ok, :erlang.binary_to_term(binary)}
  rescue
    ArgumentError ->
      :error
  end
end
