defmodule Automaton.Behavior do
  @moduledoc """
    An Automaton.Behavior is an abstract interface for actions, conditions, and
    composites that can be activated, run, and deactivated. Actions(Execution
    Nodes) provide specific implementations of this interface. Branches in the
    tree can be thought of as high level behaviors, heirarchically combining
    smaller behaviors to provide more complex and interesting behaviors.
  """
  alias Automaton.Behavior
  # @callback on_init(term) :: {:ok, term} | {:error, String.t()}
  # @callback update(term) :: atom
  @callback on_terminate(term) :: {:ok, term}
  @callback reset() :: atom
  @callback abort() :: {:ok, term}
  @callback terminated?() :: bool
  @callback running?() :: bool
  @callback get_status() :: atom
  @callback tick_freq() :: integer()

  defmacro __using__(opts) do
    user_opts = opts[:user_opts]

    quote bind_quoted: [user_opts: user_opts] do
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
                  m_current: nil,
                  tick_freq: user_opts[:tick_freq] || 0
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
        {:ok, state}
      end

      @impl DynamicSupervisor
      def init(state) do
        {:ok, state}
      end

      def handle_call(:tick, _from, state) do
        {:reply, state, new_state} = tick(state)
      end

      @impl GenServer
      def handle_info(:scheduled_tick, state) do
        {:reply, state, new_state} = tick(state)
        {:noreply, new_state}
      end

      def schedule_next(freq), do: Process.send_after(self(), :scheduled_tick, freq)

      # should tick each subtree at a frequency corresponding to subtrees tick_freq
      # each subtree of the user-defined root node will be ticked recursively
      # every update (at rate tick_freq) as we update the tree until we find
      # the leaf node that is currently running (will be an action).
      def tick(state) do
        IO.inspect(["TICK: #{state.tick_freq}", state.m_children])
        if state.m_status != :bh_running, do: on_init(state)

        {:reply, state, new_state} = update(state)

        if new_state.m_status != :bh_running do
          on_terminate(new_state)
        else
          # TODO: needs to be per control node
          schedule_next(new_state.tick_freq)
        end

        {:reply, state, new_state}
      end

      @impl Behavior
      # overriden by users
      def on_init(state)

      # overriden by users

      @impl Behavior
      def update(state)

      # overriden by users
      @impl Behavior
      def on_terminate(new_state)

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
