defmodule Automaton.Composite.Sequence do
  @moduledoc """
    Behavior for user-defined sequence actions. When the execution of a sequence
    node starts, then the node’s children are executed in succession from left
    to right, returning to its parent a status failure (or running) as soon as a
    child that returns failure (or running) is found. It returns success only
    when all the children return success. The purpose of the sequence node is to
    carry out the tasks that are deﬁned by a strict sequence of sub-tasks, in
    which all have to succeed.

    A Sequence will return immediately with a failure status code when one of
    its children fails. As long as its children are succeeding, it will keep
    going. If it runs out of children, it will return in success.
  """
  alias Automaton.{Composite, Behavior}

  defmacro __using__(opts) do
    quote do
      def update(%{workers: workers} = state) do
        {w, status} = tick_workers(workers)

        new_state = %{state | status: status}
        {:ok, new_state}
      end

      def tick_workers(workers) do
        Enum.reduce_while(workers, :ok, fn w, _acc ->
          status = GenServer.call(w, :tick, 10_000)

          cond do
            # If the child fails, or keeps running, do the same.
            status == :bh_running ->
              # IO.puts("CONT")
              # IO.inspect([Process.info(w)[:registered_name], status])
              # IO.inspect([Process.info(self)[:registered_name], status])
              {:cont, {w, :bh_running}}

            status != :bh_success ->
              # IO.puts("HALT")
              # IO.inspect([Process.info(w)[:registered_name], status])
              # IO.inspect([Process.info(self)[:registered_name], status])
              {:halt, {w, status}}
          end
        end)
      end

      def on_init(state) do
        case state.status do
          :bh_success ->
            IO.inspect(["on_init status", state.status, state.workers],
              label: Process.info(self)[:registered_name]
            )

          _ ->
            IO.inspect(["on_init status", state.status, state.workers],
              label: Process.info(self)[:registered_name]
            )
        end

        state
      end

      def on_terminate(status) do
        case status do
          :bh_running ->
            IO.inspect("on_terminate SEQUENCE RUNNING",
              label: Process.info(self)[:registered_name]
            )

          :bh_failure ->
            IO.inspect("on_terminate SEQUENCE FAILED",
              label: Process.info(self)[:registered_name]
            )

          :bh_success ->
            IO.inspect(["on_terminate SEQUENCE SUCCEEDED"],
              label: Process.info(self)[:registered_name]
            )

          :bh_aborted ->
            IO.inspect("on_terminate SEQUENCE ABORTED",
              label: Process.info(self)[:registered_name]
            )

          :bh_fresh ->
            IO.inspect("on_terminate SEQUENCE FRESH",
              label: Process.info(self)[:registered_name]
            )
        end

        status
      end
    end
  end
end
