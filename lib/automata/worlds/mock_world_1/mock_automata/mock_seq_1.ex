# Users create worlds containing their automata. These are created in the
# worlds/ directory.  Users define their own custom modules which `use
# Automaton` as a macro. By overriding the `update()` function and returning a
# status as one of `:running`, `:failure`, `:success`, or `:aborted` the core
# system will run the Behavior Tree's as defined and handle normal errors with
# restarts. Users define error handling outside generic BT capabilities.
require Integer

defmodule MockSeq1 do
  use Automaton,
    # required
    type: :behavior_tree,
    # required
    # one of :sequence, :selector, :parallel, :priority, etc...
    # or type :action for action nodes (no children)
    node_type: :sequence,

    # for granular control of effectors
    # mode: nil,--

    # the system heartbeat for this node(subtree), in milliseconds
    # the default is 50 ms (mimicing human brain perception cycle time)
    # heartbeat adaptation as meta-level(automata) action
    # can be changed at runtime
    tick_freq: 999_999_999,

    # not included for action nodes list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes and in parallel for
    # type :parallel
    children: [Seq1, SeqComposite1, Seq4]
end

defmodule SeqComposite1 do
  use Automaton,
    node_type: :sequence,
    tick_freq: 999_999_999,
    children: [Seq2, Seq3]
end

defmodule Seq1 do
  use Automaton,
    node_type: :action

  def update(state) do
    # :timer.sleep(2000)

    new_state = %{state | control: state.control + 1, status: :bh_running}

    IO.inspect([
      "Seq1 update ##{new_state.control}",
      String.slice(Integer.to_string(:os.system_time(:millisecond)), -5..-1)
    ])

    {:ok, new_state}
  end
end

defmodule Seq2 do
  use Automaton,
    node_type: :action

  def update(state) do
    # :timer.sleep(2000)

    new_state = %{state | control: state.control + 1, status: :bh_running}

    IO.inspect([
      "Seq2 update ##{new_state.control}",
      String.slice(Integer.to_string(:os.system_time(:millisecond)), -5..-1)
    ])

    {:ok, new_state}
  end
end

defmodule Seq3 do
  use Automaton,
    node_type: :action

  def update(state) do
    # :timer.sleep(2000)

    new_state = %{state | control: state.control + 1, status: :bh_running}

    IO.inspect([
      "Seq3 update ##{new_state.control}",
      String.slice(Integer.to_string(:os.system_time(:millisecond)), -5..-1)
    ])

    {:ok, new_state}
  end
end

defmodule Seq4 do
  use Automaton,
    node_type: :action

  def update(state) do
    # :timer.sleep(2000)

    new_state = %{state | control: state.control + 1, status: :bh_running}

    IO.inspect([
      "Seq4 update ##{new_state.control}",
      String.slice(Integer.to_string(:os.system_time(:millisecond)), -5..-1)
    ])

    {:ok, new_state}
  end
end
