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

  defmacro __using__(_opts) do
    quote do
      def update(%{workers: workers} = state) do
        {w, status} = tick_workers(workers)

        # TODO: what to do when num seq actions is large enough
        # that previous workers
        case status do
          :bh_failure ->
            Enum.each(state.workers, fn w ->
              IO.inspect([
                "#{Process.info(w)[:registered_name]} stop"
              ])

              # status = GenServer.stop(w, :normal, :infinity)
              # IO.inspect(status)
              # Process.exit(w, :normal)
            end)

          _ ->
            nil
        end

        IO.inspect([
          "#{Process.info(self())[:registered_name]} update finished ##{state.control}",
          String.slice(Integer.to_string(:os.system_time(:millisecond)), -5..-1)
        ])

        new_state = %{state | control: state.control + 1, status: status}

        {:ok, new_state}
      end

      def tick_workers(workers) do
        Enum.reduce_while(workers, :ok, fn w, _acc ->
          status = GenServer.call(w, :tick, 10_000)

          cond do
            # If the child fails, or keeps running, do the same.
            status == :bh_running ->
              {:cont, {w, :bh_running}}

            status != :bh_success ->
              {:halt, {w, status}}
          end
        end)
      end

      def on_init(state) do
        case state.status do
          :bh_success ->
            nil

          _ ->
            nil
        end

        state
      end

      def on_terminate(state) do
        case state.status do
          :bh_running ->
            IO.inspect("SEQUENCE TERMINATED - RUNNING",
              label: Process.info(self())[:registered_name]
            )

          :bh_failure ->
            IO.inspect("SEQUENCE TERMINATED - FAILED",
              label: Process.info(self())[:registered_name]
            )

          :bh_success ->
            IO.inspect(["SEQUENCE TERMINATED - SUCCEEDED"],
              label: Process.info(self())[:registered_name]
            )

          :bh_aborted ->
            IO.inspect("SEQUENCE TERMINATED - ABORTED",
              label: Process.info(self())[:registered_name]
            )

          :bh_fresh ->
            IO.inspect("SEQUENCE TERMINATED - FRESH",
              label: Process.info(self())[:registered_name]
            )
        end

        state.status
      end
    end
  end
end
