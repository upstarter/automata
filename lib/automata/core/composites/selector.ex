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
      def on_init(state) do
        # if state.a_status == :bh_success do
        #   IO.inspect(["SELECTOR SUCCESS!", state.a_status],
        #     label: __MODULE__
        #   )
        # else
        #   IO.inspect(["SELECTOR STATUS", state.a_status],
        #     label: __MODULE__
        #   )
        # end

        {:reply, state}
      end

      @impl Behavior
      def on_terminate(state) do
        status = state.a_status

        case status do
          :bh_running -> IO.inspect("TERMINATED SELECTOR RUNNING")
          :bh_failure -> IO.inspect("TERMINATED SELECTOR FAILED")
          :bh_success -> IO.inspect("TERMINATED SELECTOR SUCCEEDED")
          :bh_abort -> IO.inspect("TERMINATED SELECTOR ABORTED")
        end

        {:ok, state}
      end

      @impl Behavior
      def update(state) do
        new_state = process_children(state)

        IO.inspect(["Children Processed in SEL update", new_state])

        # return status, overidden by user
        {:reply, state, new_state}
      end

      def terminal_status do
        :bh_failure
      end
    end
  end
end
