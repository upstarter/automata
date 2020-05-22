# Unit Tests for the core functions and behavior of the Automaton module
defmodule AutomatonTest do
  use ExUnit.Case

  test "check started statuses" do
    status = GenServer.call(MockSeq1Server, :status)
    assert status == :bh_fresh
    status = GenServer.call(Seq2Action, :status)
    assert status == :bh_fresh
  end

  describe "upon initial update | expected status changes" do
    test "check started statuses" do
      status = GenServer.call(MockSeq1Server, :status)
      assert status == :bh_fresh
      is_running = GenServer.call(MockSeq1Server, :running?)
      assert is_running == false

      _update_status = GenServer.call(MockSeq1Server, :update)
      status1 = GenServer.call(MockSeq1Server, :running?)
      assert status1 == true
      status2 = GenServer.call(Seq4Action, :running?)
      assert status2 == true
    end
  end
end
