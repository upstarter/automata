defmodule Automaton do
  @moduledoc """
  Documentation for Automaton.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Automaton.new(:sequence, children)

  """
  def new(:sequence, children) do
    Automaton.Sequence.new(children)
  end

  def new(:selector, children) do
    Automaton.Selector.new(children)
  end
end
