defmodule Automaton.Behavior do
  @moduledoc """
    An Automaton.Behavior is an abstract interface that can be activated, run,
    and deactivated. Actions(Execution Nodes) provide specific implementations
    of this interface. Branches in the tree can be thought of as high level
    behaviors, heirarchically combining smaller behaviors to provide more
    complex and interesting behaviors.
  """
  alias Automaton.Behavior
  @callback on_init([]) :: {:ok, term} | {:error, String.t()}
  @callback update() :: atom
  @callback on_terminate(term) :: {:ok, term}
  @callback reset() :: atom
  @callback abort() :: {:ok, term}
  @callback terminated?() :: bool
  @callback running?() :: bool
  @callback get_status() :: atom

  defmacro __using__(opts) do
    quote do
      import Behavior
      @behaviour Behavior

      # TODO: can/should we provide defaults for any of these or remove?
      @impl Behavior
      def on_terminate(status) do
        {:ok, status}
      end

      @impl Behavior
      def get_status() do
        {:ok, nil}
      end

      @impl Behavior
      def running?() do
        {:ok, nil}
      end

      @impl Behavior
      def terminated?() do
        {:ok, nil}
      end

      @impl Behavior
      def abort() do
        {:ok, nil}
      end
    end
  end
end
