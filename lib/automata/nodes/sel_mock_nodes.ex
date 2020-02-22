# user-defined actions

defmodule MockSelector1 do
  use Automaton,
    # required
    # one of :sequence, :selector, :parallel, :priority, etc...
    # or type :execution for execution nodes (no children)
    node_type: :selector,

    # the frequency of updates for this node(tree), in milliseconds
    tick_freq: 10_000,

    # not included for execution nodes
    # list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes
    # and in parallel for type :parallel
    children: [SelComposite1, SelAction1]
end

defmodule SelComposite1 do
  use Automaton,
    node_type: :selector,
    tick_freq: 5_000,
    children: [SelAction3, SelAction4]

  @impl Behavior
  def update(state) do
    new_state = Map.put(state, :a_status, :bh_running)

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

defmodule SelAction1 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    new_state = Map.put(state, :a_status, :bh_running)

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

defmodule SelAction2 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    new_state = Map.put(state, :a_status, :bh_running)

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

defmodule SelAction3 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    new_state = Map.put(state, :a_status, :bh_running)

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

defmodule SelAction4 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    new_state = Map.put(state, :a_status, :bh_running)

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
