defmodule AutomataTest do
  use Espec
  doctest Automata

  # TODO: ex_spec for context, it BDD style, property testing

  setup_all do
    # TODO: Load user-configs into node_configs
    nodes_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}],
      [name: "MockSeq2", mfa: {MockSeq2, :start_link, []}],
      [name: "MockSeq3", mfa: {MockSeq3, :start_link, []}]
    ]

    [nodes_config: nodes_config]
  end

  test "context was modified", context do
    IO.inspect(context[:nodes_config])
  end

  test "loads user-defined modules from the nodes/ dir", context do
    assert Automata.start_nodes(context[:nodes_config])
  end
end
