defmodule Automaton.System do
  @moduledoc """
    When a child behavior is complete and returns its status code the Composite
    decides whether to continue through its children or whether to stop there and
    then and return a value.

    The behavior tree represents all possible Actions that your character can take. The route from the top level to each leaf represents one course of action, 2 and the behavior tree algorithm searches among those courses of action in a left-to-right manner. In other words, it performs a depth-first search.
  """
  @name ASYS

  ## Client API

  def start_link(opts \\ []) do
    # one_for_one because BT execution nodes are independent
    Supervisor.start_link(
      [Automaton.Control.Sequence],
      strategy: :one_for_one
    )

    Supervisor.start_link(
      [Automaton.Control.Selector],
      strategy: :one_for_one
    )
  end

  ## Callbacks
  # def init(:ok) do
  #   IO.inspect(@name, label: __MODULE__)
  #   {:ok, %{}}
  # end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  ## Helper Functions
end
