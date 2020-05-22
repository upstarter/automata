defmodule MockUserNodeTest do
  use ExUnit.Case
  #
  # TODO: ex_spec for context, it BDD style, property testing

  # TODO: how to put in shared context (for sharing across files)?
  setup_all do
    # TODO: Load user-configs into automaton_configs
    automata_config = [
      [name: "MockSeq1", mfa: {TestMockSeq1, :start_link, []}]
    ]

    [automata_config: automata_config]
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
