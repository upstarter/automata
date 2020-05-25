defmodule Automaton.Types.BT.Behavior do
  @moduledoc """
  An Automaton.Types.BT.Behavior is an abstract interface for composites and
  components that can be activated, run, and deactivated. Actions(Execution
  Nodes) provide specific implementations of this interface. Branches in the
  tree can be thought of as high level behaviors, heirarchically combining
  smaller behaviors to provide more complex and interesting behaviors.

  Note: there is a bunch of placeholder stuff in here right now and needs
  thought and cleanup. The specs for the callbacks are not accurate, just
  needed something that compiled and ran. Needs more thought and attention as
  the design process continues.
  """

  @typedoc """
  All nodes start with a statuses of `:bh_fresh`.
  A BT node can be in one of five statuses:
    1. :bh_fresh (when never run, or when reset)
    2. :bh_running (when running an async user action)
    3. :bh_failure
    4. :bh_success
    5. :bh_aborted (when aborted due to exits & exceptions)
  """
  @type status ::
          :bh_aborted | :bh_failure | :bh_fresh | :bh_running | :bh_success

  # these need serious help, just placeholders for now
  @callback on_init(term) :: term | {:error, String.t()}
  @callback update(any()) :: {:ok, Module.t()}
  @callback on_terminate(term) :: status
  @callback reset() :: atom
  @callback abort() :: atom
  @callback aborted?() :: bool | nil
  @callback terminated?() :: bool | nil
  @callback running?() :: bool | nil
  @callback status() :: status

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      def on_init(state)

      def update(state)

      def on_terminate(new_state)

      def reset do
        :ok
      end

      def abort do
        :ok
      end

      def aborted? do
        false
      end

      def terminated? do
        false
      end

      def running? do
        true
      end

      def status do
      end
    end
  end
end
