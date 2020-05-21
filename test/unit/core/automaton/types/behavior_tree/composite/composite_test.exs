# Unit Tests for the core functions and behavior of the Composite behaviour
defmodule CompositeTest do
  use ExUnit.Case

  setup_all do
    automata_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    Automata.start_automata(automata_config: automata_config)
    :ok
  end

  test "updates all children" do
    status = GenServer.call(MockSeq1Server, :status)
    assert status == :bh_running
  end

  describe "#add_child" do
  end

  describe "#remove_child" do
    test "" do
    end
  end

  describe "#clear_children" do
    test "" do
    end
  end

  describe "#continue_status" do
    test "" do
    end
  end
end
