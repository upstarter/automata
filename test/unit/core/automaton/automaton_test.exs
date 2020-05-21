# Unit Tests for the core functions and behavior of the Automaton module
defmodule AutomatonTest do
  use ExUnit.Case

  setup_all do
    automata_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    Automata.start_automata(automata_config: automata_config)
    :ok
  end

  test "check started statuses" do
    status = GenServer.call(MockSeq1Server, :status)
    assert status == :bh_running
    status = GenServer.call(Seq2Action, :status)
    assert status == :bh_running
  end

  describe "checking status on update" do
    status = GenServer.call(MockSeq1Server, :status)
    assert status == :bh_fresh
    is_running = GenServer.call(MockSeq1Server, :running?)
    assert is_running == false

    update_status = GenServer.call(MockSeq1Server, :update)
    IO.inspect([update_status])
    status1 = GenServer.call(MockSeq1Server, :running?)
    assert status1 == true
    status2 = GenServer.call(Seq4Action, :running?)
    assert status2 == true
  end
end
