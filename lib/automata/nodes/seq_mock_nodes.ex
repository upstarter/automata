# user-defined actions
require Integer

defmodule MockSeq1 do
  use Automaton,
    root: true,
    # required
    # one of :sequence, :selector, :parallel, :priority, etc...
    # or type :action for action nodes (no children)
    node_type: :sequence,

    # the frequency of updates for this node(tree), in milliseconds
    tick_freq: 2000,

    # not included for action nodes
    # list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes
    # and in parallel for type :parallel
    # children: [SeqComposite1, Seq1]
    children: [Seq1, SeqComposite1, Seq4]
end

defmodule SeqComposite1 do
  use Automaton,
    node_type: :sequence,
    tick_freq: 2000,
    children: [Seq2, Seq3]
end

defmodule Seq1 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    IO.puts("Seq1#update")
    :timer.sleep(2000)

    :bh_running
  end
end

defmodule Seq2 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    IO.puts("Seq2#update")
    :timer.sleep(2000)

    :bh_running
  end
end

defmodule Seq3 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    IO.puts("Seq3#update")
    :timer.sleep(2000)

    :bh_running
  end
end

defmodule Seq4 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    IO.puts("Seq4#update")
    :timer.sleep(2000)

    :bh_running
  end
end
