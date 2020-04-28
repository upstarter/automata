defmodule Automaton.Composite.Selector do
  @moduledoc """
    Selector Node (also known as Fallback)

    When the execution of a selector node starts, the node’s children are
    executed in succession from left to right, until a child returning success
    or running is found. Then this message is returned to the parent of the
    selector. It returns failure only when all the children return a status
    failure. The purpose of the selector node is to robustly carry out a task
    that can be performed using several different approaches.

    A Selector will return immediately with a success status code when one of
    its children runs successfully. As long as its children are failing, it will
    keep on trying. If it runs out of children completely, it will return a
    failure status code.
  """
  alias Automaton.{Composite, Behavior}

  defmacro __using__(opts) do
    a =
      quote do
        def on_init(state) do
          case state.status do
            :bh_success ->
              IO.inspect(["on_init status", state.status, state.workers],
                label: Process.info(self)[:registered_name]
              )

            _ ->
              nil
              # IO.inspect(["on_init status", state.status, state.workers],
              #   label: Process.info(self)[:registered_name]
              # )
          end

          state
        end

        def on_terminate(status) do
          case status do
            :bh_running ->
              IO.inspect("on_terminate SELECTOR RUNNING",
                label: Process.info(self)[:registered_name]
              )

            :bh_failure ->
              IO.inspect("on_terminate SELECTOR FAILED",
                label: Process.info(self)[:registered_name]
              )

            :bh_success ->
              IO.inspect(["on_terminate SELECTOR SUCCEEDED"],
                label: Process.info(self)[:registered_name]
              )

            :bh_aborted ->
              IO.inspect("on_terminate SELECTOR ABORTED",
                label: Process.info(self)[:registered_name]
              )

            :bh_fresh ->
              IO.inspect("on_terminate SELECTOR FRESH",
                label: Process.info(self)[:registered_name]
              )
          end

          status
        end

        def tick_workers(workers) do
          Enum.reduce_while(workers, :ok, fn w, _acc ->
            status = GenServer.call(w, :tick)

            # IO.inspect(
            #   [
            #     log: "ticked worker",
            #     status: status,
            #     worker: Process.info(w)[:registered_name]
            #   ],
            #   label: Process.info(self)[:registered_name]
            # )

            # TODO handle failures, aborts
            # If the child fails, or keeps running, do the same.
            cond do
              status == :bh_running ->
                {:cont, {w, :bh_running}}

              status != :bh_failure ->
                {:halt, {w, status}}
            end
          end)
        end

        def check_status(workers) do
          # TODO: delegate tick_workers to dangerous work error capturing wrapper
          case tick_workers(workers) do
            # TODO error handling, retries, etc..
            nil -> {:error, :worker_not_found}
            {w, status} -> {:found, status}
            {w, :bh_success} -> {:success, :bh_success}
            {w, :bh_running} -> {:halt, :bh_running}
          end
        end

        def update(%{workers: workers} = state) do
          checked_status = check_status(workers)
          IO.inspect(["checked", checked_status])

          status =
            case checked_status do
              {:found, status} -> status
              {:success, :bh_success} -> :bh_success
              {:error, :worker_not_found} -> :error
            end

          status
        end
      end
  end
end
