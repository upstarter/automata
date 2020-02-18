# user-defined actions
defmodule MockUserNode1 do
  use Automaton.Node,
    # required
    # one of :sequence, :selector, :parallel, :priority, etc...
    # or type :execution for execution nodes (no children)
    node_type: :sequence,

    # the frequency of updates for this node(tree), in milliseconds
    tick_freq: 3000,

    # not included for execution nodes
    # list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes
    # and in parallel for type :parallel
    children: [ChildNode1, ChildNode2]
end

defmodule MockUserNode2 do
  use Automaton.Node,
    node_type: :selector,
    tick_freq: 6000

  @impl Behavior
  def on_init(state) do
    new_state = Map.put(state, :m_status, :running)
    IO.inspect(["CALL ON_INIT()", state.m_status, new_state.m_status], label: __MODULE__)

    {:reply, state, new_state}
  end

  @impl Behavior
  def update(state) do
    new_state = Map.put(state, :m_status, :running)
    IO.inspect(["CALL UPDATE()", state.m_status, new_state.m_status], label: __MODULE__)

    {:reply, state, new_state}
  end

  @impl Behavior
  def on_terminate(status) do
    IO.puts("ON_TERMINATE")
    {:ok, status}
  end
end

defmodule ChildNode1 do
  use Automaton.Node,
    node_type: :execution

  @impl Behavior
  def update(state) do
    new_state = Map.put(state, :m_status, :running)
    IO.inspect(["CALL UPDATE()", state.m_status, new_state.m_status], label: __MODULE__)

    {:reply, state, new_state}
  end
end

defmodule ChildNode2 do
  use Automaton.Node,
    node_type: :execution

  @impl Behavior
  def update(state) do
    new_state = Map.put(state, :m_status, :running)
    IO.inspect(["CALL UPDATE()", state.m_status, new_state.m_status], label: __MODULE__)

    {:reply, state, new_state}
  end
end
