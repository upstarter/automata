defmodule Automaton.Control.Selector do
  @moduledoc """
    Selector Node (also known as Fallback)
    When the execution of a selector node starts, the node’s children are
    executed in succession from left to right, until a child returning success
    or runningis found. Then this message is returned to the parent of the
    selector. It returns failure only when all the children return a status
    failure. The purpose of the selector node is to robustly carry out a task
    that can be performed using several different approaches.

    A Selector will return immediately with a success status code when one of its children runs successfully. As long as its children are failing, it will keep on trying. If it runs out of children completely, it will return a failure status code.

    class Selector (Task):
      def run():
        for c in children:
          if c.run():
            return True
        return False

  """
  use Supervisor

  @name :selector
  ## Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: @name])
  end

  def stop do
    GenServer.cast(@name, :stop)
  end

  ## Callbacks
  def init(:ok) do
    IO.inspect(@name, label: __MODULE__)

    {:ok, %{}}
  end

  ## Helper Functions
end
