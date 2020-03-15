defmodule Automaton.Behavior do
  @moduledoc """
    An Automaton.Behavior is an abstract interface for actions, conditions, and
    composites that can be activated, run, and deactivated. Actions(Execution
    Nodes) provide specific implementations of this interface. Branches in the
    tree can be thought of as high level behaviors, heirarchically combining
    smaller behaviors to provide more complex and interesting behaviors.

    Note: this is all placeholder stuff right now and needs cleanup. The
    specs for the callbacks are not accurate, just needed something that compiled and ran.
    Needs more thought and attention as the design process continues.
  """
  alias Automata.Blackboard, as: GlobalBlackboard
  alias Automaton.Blackboard, as: NodeBlackboard
  alias Automata.Utility, as: GlobalUtility
  alias Automaton.Utility, as: NodeUtility

  @callback on_init(term) :: {:ok, term} | {:error, String.t()}
  @callback update(term) :: atom
  @callback on_terminate(term) :: {:ok, term}
  @callback reset() :: atom
  @callback abort() :: {:ok, term}
  @callback aborted?() :: bool
  @callback terminated?() :: bool
  @callback running?() :: bool
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
      def on_init(arg) do
        {:ok, nil}
      end

      @impl Behavior
      def update(arg) do
        nil
      end

      @impl Behavior
      def on_terminate(new_state) do
        {:ok, nil}
      end

      @impl Behavior
      def reset do
        :ok
      end

      @impl Behavior
      def abort do
        {:ok, nil}
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

      def handle_call(:get_status, _from, state) do
        {:reply, state.status, state}
      end

      def handle_call(:set_running, _from, state) do
        {:reply, :ok, %{state | status: :bh_running}}
      end

      def handle_call(:succeed, _from, state) do
        {:reply, :ok, %{state | status: :bh_success}}
      end

      def handle_call(:fail, _from, state) do
        {:reply, :ok, %{state | status: :bh_failure}}
      end

      def handle_call(:running?, _from, state) do
        {:reply, state.status == :bh_running, state}
      end

      def handle_call(:aborted?, _from, state) do
        {:reply, state.status == :bh_aborted, state}
      end

      def handle_call(:terminated?, _from, state) do
        status = state.status
        {:reply, status == :bh_success || status == :bh_failure, state}
      end

      def handle_call(:abort, _from, state) do
        on_terminate(state)
        {:reply, true, %{state | status: :bh_aborted}}
      end

      def handle_call(:reset, _from, state) do
        {:reply, true, %{state | status: :bh_invalid}}
      end
    end
  end
end
