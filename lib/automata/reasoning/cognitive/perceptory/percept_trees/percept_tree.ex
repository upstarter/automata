defmodule PerceptTree do
  @moduledoc """
    A Tree of Percepts
    The Perception System takes the form of a Percept Tree. A Percept is an
    atomic classification and data extraction unit that models some aspect of
    the sensory inputs passed in by the Sensory System. Given a DataRecord it
    returns both a match probability (the BirdPercept will return the
    probability that a DataRecord represents the experience of seeing a bird)
    and, if the match is above a threshold, a piece of extracted data (such as
    body-space coordinates of the bird). The details of how the confidence is
    computed and what exact data is extracted are left to the individual
    percept. The percept structure might encapsulate a neural net or it might
    encapsulate a simple “if … then …else” clause. This freedom of form is one
    of the keys to making the Perception System extensible, since the system
    makes no assumptions about what a percept will detect, what type of data it
    will extract or how it will be implemented.
  """

  # a percept_tree is just tree of percepts
  @callback add_child(term) :: {:ok, list} | {:error, String.t()}
  @callback remove_child(term) :: {:ok, list} | {:error, String.t()}
  @callback clear_children :: {:ok, list} | {:error, String.t()}
  @callback continue_status() :: atom

  defmacro __using__(_opts) do
    quote do
      import __MODULE__
      @behaviour __MODULE__

      def add_child(child) do
        {:ok, []}
      end

      def remove_child(child) do
        {:ok, []}
      end

      def clear_children() do
        {:ok, []}
      end

      def continue_status() do
        {:ok, nil}
      end
    end
  end
end
