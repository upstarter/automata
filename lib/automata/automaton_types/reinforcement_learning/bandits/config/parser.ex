defmodule Automaton.Types.MAB.Config.Parser do
  @moduledoc """
  High level automaton_config parsing policy for MAB specific user configs.
  """

  # alias Automaton.Types.MAB.Config

  @doc """
  Determines the node_type given the `automaton_config`.

  Returns `node_type`.

  ## Examples
      iex> automaton_config = [x: :y]
      iex> Automaton.Types.MAB.Config.Parser.type(automaton_config)
      :MAB
  """

  @spec call(type: atom, node_type: atom) :: tuple
  def call(automaton_config) do
    # config = %Config{
    #   type: automaton_config[:type]
    # }

    automaton_config
  end
end
