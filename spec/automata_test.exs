defmodule AutomataTest do
  use Espec
  doctest Automata

  # TODO: ex_spec for context, it BDD style, property testing

  setup_all do
    # TODO: Load user-configs into automaton_configs
    automata_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    [automata_config: automata_config]
  end

  test "context was modified", context do
    # IO.inspect(context[:automata_config])
  end

  test "loads user-defined modules from the nodes/ dir", context do
    assert Automata.start_nodes(context[:automata_config])
  end
end
