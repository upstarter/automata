defmodule Automaton.Action do
  @moduledoc """
    Execution Node Implementation
    Actions (Execution Nodes) are Behaviors that access information from the world and change the world.
  """
  alias Automaton.{Behavior}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @impl Behavior
      def update(state) do
        IO.inspect(["action node update/0"], label: __MODULE__)
        # return status, overidden by user
        {:ok, state}
        :running
      end

      @impl Behavior
      def on_init(str) do
        {:ok, "action node on_init " <> str}
      end
    end
  end
end
