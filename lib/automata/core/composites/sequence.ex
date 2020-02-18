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
          new_state = Map.put(state, :m_status, :failed)
          IO.inspect(["CALL ON_INIT(SEQ)", state.m_status, new_state.m_status], label: __MODULE__)

          {:reply, state, new_state}
        end

        @impl Behavior
        def on_terminate(status) do
          IO.puts("ON_TERMINATE")
          {:ok, status}
        end

        @impl Behavior
        def update(state) do
          IO.puts("UPDATE SEQUENCE")

          new_state =
            if length(state.m_children) != 0 do
              status = process_children(state)
              %{state | m_status: status}
            else
              %{state | m_state: :bh_success}
            end

          # return status, overidden by user
          {:reply, state, new_state}
        end

        def process_children(%{m_children: [current | remaining]} = state) do
          # Keep going until a child behavior says it's running

          # {:reply, old_state, new_state} = GenServer.call(current, :tick)
          new_state = GenServer.call(current, :tick)
          status = new_state.m_status
          IO.inspect(["Updated Status in SEQ", status])

          # IO.inspect(["Status", old_state, new_state])
          # IO.inspect(status)
          # // If the child fails, or keeps running, do the same.
          # if (s != BH_SUCCESS)
          # {
          #     return s;
          # }
          if status != :bh_success do
            IO.inspect(['NODE SUCCESS', current, remaining, state])
            status
          else
            IO.inspect(['NODE NOT SUCCESS', current, remaining, state])
            process_children(remaining)
          end
        end

        def process_children(%{m_children: []} = state) do
          # // Hit the end of the array, job done!
          # if (++m_CurrentChild == m_Children.end())
          # {
          #     return BH_SUCCESS;
          # }
          if state.m_status == :bh_success do
            state.m_status
          end
        end

        def process_children(%{m_children: nil} = state) do
          # // Hit the end of the array, job done!
          # if (++m_CurrentChild == m_Children.end())
          # {
          #     return BH_SUCCESS;
          # }
          if state.m_status == :bh_success do
            state.m_status
          end
        end
      end

    a
  end
end
