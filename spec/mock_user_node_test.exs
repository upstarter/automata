defmodule MockUserNodeTest do
  use Espec
  # doctest MockUserNodeTest
  # TODO: ex_spec for context, it BDD style, property testing

  # TODO: how to put in shared context (for sharing across files)?
  setup_all do
    # TODO: Load user-configs into agent_configs
    agents_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}],
      [name: "MockSeq2", mfa: {MockSeq2, :start_link, []}],
      [name: "MockSeq3", mfa: {MockSeq3, :start_link, []}]
    ]

    [agents_config: agents_config]
  end

  describe "run a simple sequence" do
    test "updates a sequence" do
      # just the abstract stuff (messages passed, etc..)
      # assert all nodes get ticked
      # assert all nodes get updated
    end

    test "runs a sequence defined by user" do
      # the concrete user-defined behaviors are completed
    end
  end
end
