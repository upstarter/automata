# user-defined actions

defmodule MockSequence1 do
  use Automaton,
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
    # children: [SeqComposite1, SeqAction1]
    children: [SeqComposite1, SeqAction1]
end

defmodule SeqComposite1 do
  use Automaton,
    node_type: :sequence,
    tick_freq: 5_000,
    children: [SeqAction2, SeqAction3]

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

defmodule SeqAction1 do
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

defmodule SeqAction2 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    new_state = Map.put(state, :a_status, :bh_failed)

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

defmodule SeqAction3 do
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

defmodule SeqAction4 do
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
