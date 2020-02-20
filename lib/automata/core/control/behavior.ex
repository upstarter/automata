defmodule Automaton.Behavior do
  @moduledoc """
    An Automaton.Behavior is an abstract interface for actions, conditions, and
    composites that can be activated, run, and deactivated. Actions(Execution
    Nodes) provide specific implementations of this interface. Branches in the
    tree can be thought of as high level behaviors, heirarchically combining
    smaller behaviors to provide more complex and interesting behaviors.
  """
  alias Automata.Blackboard, as: GlobalBlackboard
  alias Automaton.Blackboard, as: NodeBlackboard
  alias Automata.Utility, as: GlobalUtility
  alias Automaton.Utility, as: NodeUtility

  @callback on_init(term) :: {:ok, term, term} | {:error, String.t()}
  @callback update(term) :: {:reply, term, term}
  @callback on_terminate(term) :: {:ok, term}
  @callback reset() :: atom
  @callback abort() :: {:ok, term}
  @callback terminated?() :: bool
  @callback running?() :: bool
  @callback get_status() :: atom

  defmacro __using__(_opts) do
    quote do
      import Automaton.Behavior
      alias Automaton.Behavior
      @behaviour Behavior

      # TODO: allow user to choose from behavior tree, utility AI, or both
      # for the knowledge and decisioning system. Allow third-party strategies?
      use GlobalBlackboard
      use NodeBlackboard
      use GlobalUtility
      use NodeUtility

      @impl Behavior
      # overriden by users
      def on_init(state)

      # overriden by users
      @impl Behavior
      def update(state)

      # overriden by users
      @impl Behavior
      def on_terminate(new_state)

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
      def reset() do
        {:ok, nil}
      end

      @impl Behavior
      def abort() do
        {:ok, nil}
      end
    end
  end
end
