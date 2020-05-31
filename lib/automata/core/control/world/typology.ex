defmodule Automata.World.Typology do
  @moduledoc """
  ## World Types are builtin world configurations.
  """

  @types [:default]
  def types, do: @types

  # @spec call(nonempty_list()) :: nonempty_list()
  def call(world_config) do
    type =
      world_config[:type]
      |> case do
        :default ->
          world_config

        nil ->
          world_config
      end

    [type]
  end
end
