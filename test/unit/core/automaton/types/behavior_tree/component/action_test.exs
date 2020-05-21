# Unit test the core functions and behavior of an Action
defmodule ActionTest do
  use ExUnit.Case

  setup_all do
    automata_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    Automata.start_automata(automata_config: automata_config)
    :ok
  end

  describe "#update" do
    test "updates only the action" do
      status = GenServer.call(MockSeq1Server, :status)
      assert status == :bh_running
    end
  end
end
