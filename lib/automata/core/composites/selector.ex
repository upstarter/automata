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
    quote do
      @impl Behavior
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
          :bh_running -> IO.inspect("TERMINATED SELECTOR RUNNING")
          :bh_failure -> IO.inspect("TERMINATED SELECTOR FAILED")
          :bh_success -> IO.inspect("TERMINATED SELECTOR SUCCEEDED")
          :bh_abort -> IO.inspect("TERMINATED SELECTOR ABORTED")
        end

        {:ok, status}
      end

      @impl Behavior
      def update(%{workers: workers} = state) do
        {worker, status} =
          Enum.reduce_while(workers, {nil, nil}, fn w, acc ->
            # IO.inspect(log: "[#{Process.info(self)[:registered_name]}] ticking..", curr: state, w: Process.info(w))

            status = GenServer.call(w, :tick)

            IO.inspect(
              log: "[#{Process.info(self)[:registered_name]}] Ticked",
              w: w,
              status: status
            )

            if status != continue_status(), do: {:halt, {w, status}}, else: {:cont, {w, status}}
          end)

        IO.inspect(log: "Child Status!!!", status: status, worker: worker)
        status
      end

      def continue_status do
        :bh_failure
      end
    end
  end
end
