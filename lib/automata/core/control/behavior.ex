defmodule Automaton.Behavior do
  @moduledoc """
    An Automaton.Behavior is an abstract interface for actions, conditions, and
    composites that can be activated, run, and deactivated. Actions(Execution
    Nodes) provide specific implementations of this interface. Branches in the
    tree can be thought of as high level behaviors, heirarchically combining
    smaller behaviors to provide more complex and interesting behaviors.

    Note: there is a bunch of placeholder stuff in here right now and needs
    thought and cleanup. The specs for the callbacks are not accurate, just
    needed something that compiled and ran. Needs more thought and attention as
    the design process continues.
  """
  alias Automata.Blackboard, as: GlobalBlackboard
  alias Automaton.Blackboard, as: NodeBlackboard
  alias Automata.Utility, as: GlobalUtility
  alias Automaton.Utility, as: NodeUtility

  # these need serious help, just placeholders for now
  @callback on_init(term) :: term | {:error, String.t()}
  @callback update(any()) :: any()
  @callback on_terminate(term) ::
              :bh_aborted | :bh_failure | :bh_fresh | :bh_running | :bh_success
  @callback reset() :: atom
  @callback abort() :: atom
  @callback aborted?() :: bool | nil
  @callback terminated?() :: bool | nil
  @callback running?() :: bool | nil
  @callback get_status() :: atom

  defmacro __using__(_opts) do
    quote do
      import Automaton.Behavior
      @behaviour Automaton.Behavior

      use GlobalBlackboard
      use NodeBlackboard
      use GlobalUtility
      use NodeUtility

      @impl Behavior
      def on_init(state)

      # currently control nodes run this function if `update` is not defined
      # TODO: figure out the right thing to do here
      @impl Behavior
      def update(args)

      @impl Behavior
      def on_terminate(new_state)

      @impl Behavior
      def reset do
        :ok
      end

      @impl Behavior
      def abort do
        :ok
      end

      @impl Behavior
      def aborted? do
        false
      end

      @impl Behavior
      def terminated? do
        false
      end

      @impl Behavior
      def running? do
        true
      end

      @impl Behavior
      def get_status do
        :bh_running
      end

      def set_status(pid, status) do
        GenServer.call(pid, :do_status, status)
      end

      defp set_status(from, state, status) do
        pid = self()

        spawn_link(fn ->
          result = GenServer.call(pid, :do_status, [state, status])
          GenServer.reply(from, result)
        end)
      end

      def handle_call(:do_status, _from, [state, status]) do
        {:reply, :ok, %{state | status: status}}
      end

      def handle_call(:set_status, from, [state, status]) do
        # Handles set_status and the reply to from.
        set_status(from, state, status)
        # Returns nothing to the client, but unblocks the
        # server to get more requests.
        {:noreply, state}
      end
    end
  end
end
