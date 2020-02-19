defmodule Automaton.Action do
  @moduledoc """
    Execution Node Implementation
    Actions (Execution Nodes) are Behaviors that access information from the world and change the world.
  """
  alias Automaton.{Behavior}

  defmacro __using__(opts) do
    user_opts = opts[:user_opts]

    quote bind_quoted: [user_opts: opts[:user_opts]] do
      @impl Behavior
      def on_init(state) do
        {:reply, state}
      end

      # @impl Behavior
      # def update(state) do
      #   new_state = Map.put(state, :m_status, :bh_running)
      #
      #   IO.inspect(["ACTION CALLED UPDATE(ACTION)", state.m_status, new_state.m_status],
      #     label: __MODULE__
      #   )
      #
      #   {:reply, state, new_state}
      # end

      @impl Behavior
      def on_terminate(status) do
        {:ok, status}
      end
    end
  end
end
