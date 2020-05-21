# test the Action state changes, data flows, and contract checking as applicable
defmodule ActionStateTest do
  use ExUnit.Case

  setup_all do
    automata_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    Automata.start_automata(automata_config: automata_config)
    :ok
  end

  describe "#update" do
    test "updates all children" do
      status = GenServer.call(MockSeq1Server, :status)
      assert status == :bh_running
    end
  end
end
