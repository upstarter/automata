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
    a =
      quote do
        @impl Behavior
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

        @impl Behavior
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

        def check_status(workers) do
          Enum.find_value(workers, fn w ->
            # new_status = GenServer.call(w, :tick)

            new_status = :bh_success

            # new_status = tick(state)

            IO.inspect(
              [
                log: "update sequence",
                new_status: new_status,
                worker: Process.info(w)[:registered_name]
              ],
              label: Process.info(self)[:registered_name]
            )

            if new_status != continue_status() do
              # TODO handle failures, aborts
              {:ok, {w, new_status}}
            else
              {:final, {w, new_status}}
            end
          end)
        end

        def status_check(workers) do
          case check_status(workers) do
            # TODO error handling, retries, etc..
            nil -> {:error, :bh_running}
            {:ok, {w, status}} -> {:ok, status}
            {:final, {w, status}} -> {:final, status}
          end
        end

        @impl Behavior
        def update(%{workers: workers} = state) do
          IO.inspect(workers)

          status =
            case status_check(workers) do
              {:error, :bh_running} -> :bh_running
              {:ok, status} -> status
              {:final, :bh_success} -> :bh_success
              {:final, :bh_failure} -> :bh_failure
            end

          IO.inspect(
            [
              log: "updated workers",
              status: status
            ],
            label: Process.info(self)[:registered_name]
          )

          status
        end

        @impl Behavior
        def update(%{workers: []} = state) do
          state
        end

        def continue_status do
          :bh_success
        end
      end
  end
end
