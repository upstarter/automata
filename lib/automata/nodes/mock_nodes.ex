# user-defined actions
defmodule MockUserNode1 do
  use Automaton.Node,
    # required
    # one of :sequence, :selector, :parallel, etc...
    # or type :execution for execution nodes (no children)
    node_type: :selector,

    # the frequency of updates for this node(tree), in milliseconds
    tick_freq: 1500,

    # not included for execution nodes
    # list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes
    # and in parallel for type :parallel
    children: [ChildNode1, ChildNode2]

  # def on_init(state) do
  #   IO.puts("not_running_if_called")
  # end
  #
  # def update(state) do
  #   {:ok, "overrides default Automaton.Composite.Selector.update/0"}
  #   :running
  # end
end

defmodule MockUserNode2 do
  use Automaton.Node,
    node_type: :sequence,
    tick_freq: 3500

  #
  # def update(state) do
  #   {:ok, "mockusernode2 update overrides Sequence update"}
  # end
  #
  # def on_init(str) do
  #   {:ok, "overrides default Automaton.Composite.Selector.on_init/0"}
  # end
end

defmodule ChildNode1 do
  use Automaton.Node,
    node_type: :execution

  # def update(state) do
  #   {:ok, "child1 overrides default Automaton.Action.update/0"}
  # end
end

defmodule ChildNode2 do
  use Automaton.Node,
    node_type: :execution

  # def update(state) do
  #   {:ok, "child2 overrides default Automaton.Action.update/0"}
  # end
end
