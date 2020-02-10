# user-defined actions
defmodule MockUserNode1 do
  use Automaton.Node,
    # required
    # one of :sequence, :selector, :parallel, etc...
    # or type :execution for execution nodes (no children)
    node_type: :selector,

    # the frequency of updates for this node(tree), in seconds
    # 200ms
    tick_freq: 0.2,

    # custom OTP config options (defaults shown)
    # shows running until max_restarts exhausted?
    max_restart: 5,
    max_time: 3600,

    # not included for execution nodes
    # list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes
    # and in parallel for type :parallel
    children: [ChildNode1, ChildNode2, ChildNode3]

  def update do
    {:ok, "overrides update/0"}
  end
end

defmodule MockUserNode2 do
  use Automaton.Node,
    node_type: :execution
end
