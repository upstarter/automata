defmodule Automaton.Behavior do
  # Define behaviours which user modules implement/override
  @callback on_init([]) :: {:ok, term} | {:error, String.t()}
  @callback update() :: atom
  @callback on_terminate(term) :: {:ok, term}
  @callback reset() :: atom
  @callback abort() :: {:ok, term}
  @callback terminated?() :: bool
  @callback running?() :: bool
  @callback get_status() :: atom

  defmacro __using__(opts) do
    quote do
      import unquote(__MODULE__)
      @impl Automaton.Behavior
      def on_terminate(status) do
        {:ok, status}
      end

      @impl Automaton.Behavior
      def get_status() do
      end

      @impl Automaton.Behavior
      def running?() do
      end

      @impl Automaton.Behavior
      def terminated?() do
      end
    end
  end
end
