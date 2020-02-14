defmodule Automaton.Behavior do
  @moduledoc """
    An Automaton.Behavior is an abstract interface for actions, conditions, and
    composites that can be activated, run, and deactivated. Actions(Execution
    Nodes) provide specific implementations of this interface. Branches in the
    tree can be thought of as high level behaviors, heirarchically combining
    smaller behaviors to provide more complex and interesting behaviors.
  """
  alias Automaton.Behavior
  @callback on_init(term) :: {:ok, term} | {:error, String.t()}
  @callback update(term) :: atom
  @callback on_terminate(term) :: {:ok, term}
  @callback reset() :: atom
  @callback abort() :: {:ok, term}
  @callback terminated?() :: bool
  @callback running?() :: bool
  @callback get_status() :: atom

  defmacro __using__(opts) do
    quote bind_quoted: [user_opts: opts[:user_opts]] do
      import Behavior
      use GenServer
      @behaviour Behavior

      # TODO: probably handle state somewhere else? GenServer linked to Node?
      defmodule State do
        # bh_fresh is for when status has not been initialized
        # yet or has been reset
        defstruct m_status: :bh_fresh,
                  # control is the parent, nil when fresh
                  control: nil,
                  m_children: user_opts[:children] || [],
                  m_current: nil
      end

      # Client API
      def start_link(args) do
        GenServer.start_link(__MODULE__, %State{})
      end

      # #######################
      # # GenServer Callbacks #
      # #######################
      def init(%State{} = state) do
        tick(state)
        {:ok, nil}
      end

      # TODO: best practice for DFS on supervision tree? One way to do it (sans tail-recursion):
      def update_tree do
        # tick forever (or at configured tick_freq)
        # For each tick
        #   For each node in tree
        #     node.tick # updates node(subtree)
      end

      # should tick each subtree at a frequency corresponding to subtrees tick_freq
      # each subtree of the user-defined root node will be ticked recursively
      # every update (at rate tick_freq) as we update the tree until we find
      # the leaf node that is currently running (will be an action).
      def tick(state) do
        IO.inspect(["tick state:", state])

        receive do
        after
          tick_freq ->
            IO.puts("#{tick_freq} milliseconds elapsed")
            if state.m_status != :running, do: on_init(state)
            new_state = %State{m_status: update(state)}
            if new_state.m_status != :running, do: on_terminate(new_state.m_status)
            tick(new_state)
        end
      end

      def tick_freq do
        # default of 0 is an infinite loop
        unquote(user_opts[:tick_freq]) || 0
      end

      # TODO: can/should we provide defaults for any of these or remove?
      @impl Behavior
      def on_terminate(status) do
        {:ok, status}
      end

      @impl Behavior
      def get_status() do
        {:ok, nil}
      end

      @impl Behavior
      def running?() do
        {:ok, nil}
      end

      @impl Behavior
      def terminated?() do
        {:ok, nil}
      end

      @impl Behavior
      def abort() do
        {:ok, nil}
      end
    end
  end
end
