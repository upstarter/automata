defmodule AutomataTest do
  use ExUnit.Case
  doctest Automata
  # TODO: ex_spec for context, it BDD style, property testing

  setup_all do
    # TODO: Load user-configs into node_configs

    nodes_config = [
      [name: "MockUserNode1", mfa: {MockUserNode1, :start_link, []}],
      [name: "MockUserNode2", mfa: {MockUserNode2, :start_link, []}],
      [name: "MockUserNode3", mfa: {MockUserNode3, :start_link, []}]
    ]

    [nodes_config: nodes_config]
  end

  test "context was modified", context do
    IO.inspect(context[:nodes_config])
  end

  test "loads user-defined modules from the nodes/ dir", context do
    assert Automata.start_nodes(context[:nodes_config])
  end

  test "updates a sequence" do
    # just the abstract stuff (messages passed, etc..)
    # assert all nodes get ticked
    # assert all nodes get updated
  end

  test "runs a sequence defined by user" do
    # the concrete user-defined behaviors are completed
  end
end
