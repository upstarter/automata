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

  # these need serious help, just placeholders for now
  @callback on_init(term) :: term | {:error, String.t()}
  @callback update(any()) :: {:ok, Module.t()}
  @callback on_terminate(term) ::
              :bh_aborted | :bh_failure | :bh_fresh | :bh_running | :bh_success
  @callback reset() :: atom
  @callback abort() :: atom
  @callback aborted?() :: bool | nil
  @callback terminated?() :: bool | nil
  @callback running?() :: bool | nil
  @callback status() :: atom

  defmacro __using__(_opts) do
    quote do
      import Automaton.Types.BT.Behavior
      @behaviour Automaton.Types.BT.Behavior

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

      def handle_call(:status, _from, state) do
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
