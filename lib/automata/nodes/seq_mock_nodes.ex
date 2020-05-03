# user-defined actions
require Integer

defmodule MockSeq1 do
  use Automaton,
    root: true,
    # for granular control of effectors
    mode: nil,
    # for filtering, utility decisioning, prioritization
    type: nil,
    # required
    # one of :sequence, :selector, :parallel, :priority, etc...
    # or type :action for action nodes (no children)
    node_type: :sequence,

    # the system heartbeat for this node(subtree), in milliseconds
    # the default is 0 ms (infinite loop)
    # heartbeat adaption as meta-level(automata) action
    # can be changed at runtime
    tick_freq: 2000,

    # not included for action nodes list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes and in parallel for
    # type :parallel
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

  def update(state) do
    # :timer.sleep(2000)

    new_state = %{state | control: state.control + 1, status: :bh_running}
    IO.inspect(["Seq1 update ##{new_state.control}", :os.system_time(:millisecond)])

    {:ok, new_state}
  end
end

defmodule Seq2 do
  use Automaton,
    node_type: :action

  def update(state) do
    # :timer.sleep(2000)

    new_state = %{state | control: state.control + 1, status: :bh_running}
    IO.inspect(["Seq2 update ##{new_state.control}", :os.system_time(:millisecond)])

    {:ok, new_state}
  end
end

defmodule Seq3 do
  use Automaton,
    node_type: :action

  def update(state) do
    # :timer.sleep(2000)

    new_state = %{state | control: state.control + 1, status: :bh_running}
    IO.inspect(["Seq3 update ##{new_state.control}", :os.system_time(:millisecond)])

    {:ok, new_state}
  end
end

defmodule Seq4 do
  use Automaton,
    node_type: :action

  def update(state) do
    # :timer.sleep(2000)

    new_state = %{state | control: state.control + 1, status: :bh_running}
    IO.inspect(["Seq4 update ##{new_state.control}", :os.system_time(:millisecond)])

    {:ok, new_state}
  end
end
