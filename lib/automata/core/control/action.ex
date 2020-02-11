defmodule Automaton.Action do
  @moduledoc """
    Execution Node Implementation

    These are the Actions that are the leafs of the Behavior Trees, which
    change the world
    Actions (Execution Nodes) are Behaviors that access information from the world and change the world.

  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @impl Automaton.Behavior
      def update do
        IO.inspect(["action node update/0"], label: __MODULE__)
        # return status, overidden by user
      end

      @impl Automaton.Behavior
      def on_init(str) do
        {:ok, "action node on_init " <> str}
      end
    end
  end
end
