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

        def tick_workers(workers) do
          Enum.reduce_while(workers, :ok, fn w, acc ->
            new_status = GenServer.call(w, :tick)

            # IO.inspect(
            #   [
            #     log: "ticked worker",
            #     new_status: new_status,
            #     worker: Process.info(w)[:registered_name]
            #   ],
            #   label: Process.info(self)[:registered_name]
            # )

            # TODO handle failures, aborts
            # If the child fails, or keeps running, do the same.
            cond do
              new_status == :bh_running ->
                {:cont, {w, :bh_running}}

              new_status != :bh_success ->
                {:halt, {w, new_status}}
            end
          end)
        end

        def check_status(workers) do
          case tick_workers(workers) do
            # TODO error handling, retries, etc..
            nil -> {:error, :worker_not_found}
            {w, status} -> {:found, status}
            {w, :bh_success} -> {:success, :bh_success}
            {w, :bh_running} -> {:halt, :bh_running}
          end
        end

        @impl Behavior
        def update(%{workers: workers} = state) do
          IO.inspect([
            "checking workers",
            Enum.map(workers, fn w -> Process.info(w)[:registered_name] end)
          ])

          checked_status = check_status(workers)
          IO.inspect(["checked", checked_status])

          status =
            case checked_status do
              {:found, status} -> status
              {:success, :bh_success} -> :bh_success
              {:error, :worker_not_found} -> :error
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
      end
  end
end
