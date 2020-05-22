# Unit test the core functions and behavior of an Action
defmodule ActionTest do
  use ExUnit.Case

  describe "#update" do
    test "updates only the action" do
      status = GenServer.call(MockSeq1Server, :status)
      assert status == :bh_fresh
    end
  end
end
