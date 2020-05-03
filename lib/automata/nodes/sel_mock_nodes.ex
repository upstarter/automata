# # user-defined actions
# require Integer
#
# defmodule MockSel1 do
#   use Automaton,
#     # required
#     # one of :sequence, :selector, :parallel, :priority, etc...
#     # or type :action for action nodes (no children)
#     node_type: :selector,
#
#     # the frequency of updates for this node(tree), in milliseconds
#     tick_freq: 2000,
#
#     # not included for action nodes list of child control/execution nodes
#     # these run in order for type :selector and :selector nodes and in parallel for
#     # type :parallel
#     children: [Sel1, SelComposite1, Sel4]
# end
# #
# defmodule SelComposite1 do
#   use Automaton,
#     node_type: :selector,
#     tick_freq: 2000,
#     children: [Sel2, Sel3]
# end
#
# defmodule Sel1 do
#   use Automaton,
#     node_type: :action
#
#   @impl Behavior
#   def update(state) do
#     IO.puts("Sel1#update")
#     :timer.sleep(2000)
#
#     :bh_running
#   end
# end
#
# defmodule Sel2 do
#   use Automaton,
#     node_type: :action
#
#   @impl Behavior
#   def update(state) do
#     IO.puts("Sel2#update")
#     :timer.sleep(2000)
#
#     :bh_running
#   end
# end
#
# defmodule Sel3 do
#   use Automaton,
#     node_type: :action
#
#   @impl Behavior
#   def update(state) do
#     IO.puts("Sel3#update")
#     :timer.sleep(2000)
#
#     :bh_running
#   end
# end
#
# defmodule Sel4 do
#   use Automaton,
#     node_type: :action
#
#   @impl Behavior
#   def update(state) do
#     IO.puts("Sel4#update")
#     :timer.sleep(2000)
#
#     :bh_running
#   end
# end
