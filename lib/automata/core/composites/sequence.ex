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
          # if state.m_status == :bh_success do
          #   IO.inspect(["SEQUENCE SUCCESS!", state.m_status],
          #     label: __MODULE__
          #   )
          # else
          #   IO.inspect(["SEQUENCE STATUS", state.m_status],
          #     label: __MODULE__
          #   )
          # end

          {:reply, state}
        end

        @impl Behavior
        def on_terminate(state) do
          status = state.m_status

          case status do
            :bh_running -> IO.inspect("TERMINATED SEQUENCE RUNNING")
            :bh_failure -> IO.inspect("TERMINATED SEQUENCE FAILED")
            :bh_success -> IO.inspect("TERMINATED SEQUENCE SUCCEEDED")
            :bh_aborted -> IO.inspect("TERMINATED SEQUENCE ABORTED")
          end

          {:ok, state}
        end

        @impl Behavior
        def update(state) do
          new_state = process_children(state)

          IO.inspect(["FINAL SEQUENCE STATE", new_state.m_status])

          # return status, overidden by user
          {:reply, state, new_state}
        end

        def terminal_status do
          :bh_success
        end
      end
  end
end
