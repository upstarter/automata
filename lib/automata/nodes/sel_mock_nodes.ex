# user-defined actions
require Integer

defmodule MockSel1 do
  use Automaton,
    # required
    # one of :sequence, :selector, :parallel, :priority, etc...
    # or type :execution for execution nodes (no children)
    node_type: :sequence,

    # the frequency of updates for this node(tree), in milliseconds
    tick_freq: 7_000,

    # not included for execution nodes
    # list of child control/execution nodes
    # these run in order for type :selector and :sequence nodes
    # and in parallel for type :parallel
    # children: [SelComposite1, Sel1]
    children: [Sel1, Sel2, SelComposite1]
end

defmodule SelComposite1 do
  use Automaton,
    node_type: :sequence,
    tick_freq: 3_500,
    children: [Sel3, Sel4]
end

defmodule Sel1 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    IO.puts("WithinTimeWindow?")
    now = DateTime.now!("Etc/UTC") |> DateTime.to_time()
    min = now.minute

    if Integer.is_odd(min) do
      :bh_success
    else
      :bh_running
    end
  end
end

defmodule Sel2 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    IO.puts("MA Crossover?")
    now = DateTime.now!("Etc/UTC") |> DateTime.to_time()
    min = now.minute
    sec = now.second

    if Integer.is_odd(min) && sec <= 30 do
      :bh_success
    else
      :bh_running
    end
  end
end

defmodule Sel3 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    IO.puts("Exit Position 1")
    now = DateTime.now!("Etc/UTC") |> DateTime.to_time()
    min = now.minute
    sec = now.second

    if Integer.is_odd(min) && sec <= 15 do
      :bh_success
    else
      :bh_running
    end
  end
end

defmodule Sel4 do
  use Automaton,
    node_type: :action

  @impl Behavior
  def update(state) do
    IO.puts("Enter Position 2")

    :bh_success
  end
end
