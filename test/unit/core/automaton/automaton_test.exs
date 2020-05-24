# Unit Tests for the core functions and behavior of the Automaton module
defmodule AutomatonTest do
  use ExUnit.Case

  describe "before update" do
    test "check started statuses" do
      status = GenServer.call(TestMockSeq1Server, :status)
      assert status == :bh_fresh
      status = GenServer.call(TestSeq2Action, :status)
      assert status == :bh_fresh
    end
  end

  describe "before update | expected status changes" do
    test "check started statuses" do
      status = GenServer.call(TestMockSeq1Server, :status)
      assert status == :bh_fresh
      is_running = GenServer.call(TestMockSeq1Server, :running?)
      assert is_running == false
    end
  end

  # describe "upon initial update | expected status changes" do
  #   test "check started statuses" do
  #     _update_status = GenServer.call(TestMockSeq1Server, :update)
  #     status1 = GenServer.call(TestMockSeq1Server, :running?)
  #     assert status1 == true
  #     status2 = GenServer.call(TestSeq4Action, :running?)
  #     assert status2 == true
  #   end
  # end
end
