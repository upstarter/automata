defmodule Automata.World.Server do
  @moduledoc """

  """
  use GenServer

  #######
  # API #
  #######

  def start_link(world_config) do
    GenServer.start_link(__MODULE__, [world_config], name: __MODULE__)
  end

  #############
  # Callbacks #
  #############

  @doc """

  """
  def init([world_config]) do
    {:ok, world_config |> configure_world()}
  end

  @doc """
  """
  def configure_world(world_config) do
    Automata.World.Typology.call(world_config)
  end

  def child_spec([world_config]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [world_config]},
      restart: :temporary,
      shutdown: 10_000,
      type: :worker
    }
  end
end
