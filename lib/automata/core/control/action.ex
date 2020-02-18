defmodule Automaton.Action do
  @moduledoc """
    Execution Node Implementation
    Actions (Execution Nodes) are Behaviors that access information from the world and change the world.
  """
  alias Automaton.{Behavior}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @impl Behavior
      def on_init(state) do
        new_state = Map.put(state, :m_status, :running)

        IO.inspect(["CALL ON_INIT(ACTION)", state.m_status, new_state.m_status], label: __MODULE__)

        {:reply, state, new_state}
      end

      @impl Behavior
      def update(state) do
        new_state = Map.put(state, :m_status, :running)
        IO.inspect(["CALL UPDATE(ACTION)", state.m_status, new_state.m_status], label: __MODULE__)
        IO.inspect(state, label: __MODULE__)

        {:reply, state, new_state}
      end

      @impl Behavior
      def on_terminate(status) do
        IO.inspect("ON_TERMINATE(ACTION)", label: __MODULE__)
        {:ok, status}
      end
    end
  end
end
