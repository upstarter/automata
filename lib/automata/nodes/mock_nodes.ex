# user-defined actions
defmodule MockSequence1 do
  use Automaton.Control,
    # required
    # one of :sequence, :selector, :parallel, :priority, etc...
    # or type :execution for execution nodes (no children)
    node_type: :sequence,

    # the frequency of updates for this node(tree), in milliseconds
    tick_freq: 10_000,

    # not included for execution nodes
    # list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes
    # and in parallel for type :parallel
    children: [ChildAction1, ChildAction2]
end

defmodule MockSelector1 do
  use Automaton.Control,
    node_type: :selector,
    tick_freq: 20_000,
    children: [ChildAction1, ChildAction2]
end

defmodule ChildAction1 do
  use Automaton.Action

  # @impl Behavior
  def update(state) do
    new_state = Map.put(state, :m_status, :bh_running)

    {:reply, state, new_state}
  end

  # def status do
  #   case :rand.uniform(3) do
  #     1 -> :bh_success
  #     2 -> :bh_failure
  #     3 -> :bh_running
  #   end
  # end
end

defmodule ChildAction2 do
  use Automaton.Action

  # @impl Behavior
  def update(state) do
    new_state = Map.put(state, :m_status, :bh_running)

    {:reply, state, new_state}
  end

  # def status do
  #   case :rand.uniform(3) do
  #     1 -> :bh_success
  #     2 -> :bh_failure
  #     3 -> :bh_running
  #   end
  # end
end
