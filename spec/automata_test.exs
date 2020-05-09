defmodule AutomataTest do
  use Espec
  doctest Automata

  # TODO: ex_spec for context, it BDD style, property testing

  setup_all do
    # TODO: Load user-configs into agent_configs
    agents_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    [agents_config: agents_config]
  end

  test "context was modified", context do
    # IO.inspect(context[:agents_config])
  end

  test "loads user-defined modules from the nodes/ dir", context do
    assert Automata.start_nodes(context[:agents_config])
  end
end
