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
          new_state = Map.put(state, :m_status, :bh_running)

          IO.inspect(["SEQ CALL ON_INIT(SEQ)", state.m_status, new_state.m_status],
            label: __MODULE__
          )

          {:reply, new_state}
        end

        @impl Behavior
        def on_terminate(status) do
          IO.puts("SEQ ON_TERMINATE")
          {:ok, status}
        end

        @impl Behavior
        def update(state) do
          IO.puts("SEQ UPDATE SEQUENCE")

          new_state =
            case state.m_children do
              nil ->
                state

              [] ->
                %{state | m_state: :bh_success}

              _children ->
                status = process_children(state)
                %{state | m_status: status}
            end

          IO.inspect(["Updated Status in SEQ", new_state])

          # return status, overidden by user
          {:reply, state, new_state}
        end

        def process_children(%{m_children: [current | remaining]} = state) do
          # Keep going until a child behavior says it's running
          child_state = GenServer.call(current, :tick)

          status = child_state.m_status
          IO.inspect(["Process children in SEQ", status, child_state, state])

          # // If the child fails, or keeps running, do the same.
          # if (s != BH_SUCCESS)
          # {
          #     return s;
          # }
          if status != :bh_success do
            IO.inspect(['SEQ ACTION(CHILD) IS #{status}'])
            status
          else
            IO.inspect(['SEQ ACTION(CHILD) IS #{status}'])
            process_children(%{state | m_children: remaining})
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
          if state.m_status == :bh_success do
            state.m_status
          end
        end
      end

    a
  end
end
