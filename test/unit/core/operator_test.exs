defmodule AutomataTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  @tag :pending
  test "doesn't hang on exits" do
    defmodule EventServerTest do
      use Automaton,
        type: :behavior_tree,
        timeout: 10,
        node_type: :action

      def update("spawn and crash") do
        spawn_link(fn ->
          exit(:foo)
        end)

        receive after: (1000 -> :ok)
      end
    end

    assert capture_io(fn ->
             Automata.begin()
           end) =~ "update #\d+"
  end

  @tag :pending
  test "supports timeouts" do
    defmodule TimeoutTest do
      use Automaton,
        type: :behavior_tree,
        timeout: 10,
        node_type: :action

      def update("ok") do
        Process.sleep(:infinity)
      end
    end

    output = capture_io(fn -> Automata.begin() end)
    assert output =~ "** (Automata.TimeoutError) automaton timed out after 10ms"
    assert output =~ ~r"\(elixir #{System.version()}\) lib/process\.ex:\d+: Process\.sleep/1"
  end

  @tag :pending
  test "supports configured timeout" do
    defmodule ConfiguredTimeoutTest do
      use Automaton,
        type: :behavior_tree,
        timeout: 10,
        node_type: :action

      def update("ok") do
        Process.sleep(:infinity)
      end
    end

    Automata.configure(timeout: 5)
    output = capture_io(fn -> Automata.begin() end)
    assert output =~ "** (Automata.TimeoutError) automaton timed out after 5ms"
  after
    Automata.configure(timeout: 60000)
  end
end
