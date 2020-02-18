defmodule Automaton.Behavior do
  @moduledoc """
    An Automaton.Behavior is an abstract interface for actions, conditions, and
    composites that can be activated, run, and deactivated. Actions(Execution
    Nodes) provide specific implementations of this interface. Branches in the
    tree can be thought of as high level behaviors, heirarchically combining
    smaller behaviors to provide more complex and interesting behaviors.
  """
  alias Automaton.Behavior
  # @callback on_init() :: {:ok, term} | {:error, String.t()}
  @callback update() :: atom
  @callback on_terminate(term) :: {:ok, term}
  @callback reset() :: atom
  @callback abort() :: {:ok, term}
  @callback terminated?() :: bool
  @callback running?() :: bool
  @callback get_status() :: atom

  defmacro __using__(opts) do
    quote bind_quoted: [user_opts: opts[:user_opts]] do
      import Behavior
      # @behaviour Behavior

      # TODO: probably handle state somewhere else? GenServer linked to Node?
      defmodule State do
        # bh_fresh is for when status has not been initialized
        # yet or has been reset
        defstruct m_status: :bh_fresh,
                  # control is the parent, nil when fresh
                  control: nil,
                  m_children: user_opts[:children] || nil,
                  m_current: nil
      end

      # Client API
      @impl GenServer
      def start_link(args) do
        GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
      end

      @impl DynamicSupervisor
      def start_link(args) do
        DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
      end

      # #######################
      # # GenServer Callbacks #
      # #######################
      @impl GenServer
      def init(%State{} = state) do
        send(self(), :tick)
        {:ok, state}
      end

      @impl DynamicSupervisor
      def init(state) do
        {:ok, state}
      end

      def handle_info(:tick, state) do
        IO.puts("#{tick_freq} milliseconds elapsed")
        if state.m_status != :running, do: on_init(state)
        {:reply, state, new_state} = update(state)
        if new_state.m_status != :running, do: on_terminate(new_state)
        schedule_next()
        {:noreply, new_state}
      end

      def schedule_next, do: Process.send_after(self(), :tick, tick_freq())

      def tick, do: GenServer.call(__MODULE__, :tick)

      # TODO: best practice for DFS on supervision tree? See Composite for one way (sans tail recursion)
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
      def tick_freq do
        # default of 0 is an infinite loop
        unquote(user_opts[:tick_freq]) || 0
      end

      @impl Behavior
      # overriden by users
      def on_init(state), do: nil

      # overriden by users
      @impl Behavior
      def update(state), do: nil

      # overriden by users
      @impl Behavior
      def on_terminate(status), do: nil

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
