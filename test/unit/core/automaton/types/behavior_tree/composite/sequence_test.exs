# test the sequence,
defmodule SequencExUnit do
  use ExUnit.Case

  # TODO: ex_spec for context, it BDD style, property testing

  def setup_all() do
    # TODO: Load user-configs into automaton_config
    automata_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}],
      [name: "MockSeq2", mfa: {MockSeq2, :start_link, []}],
      [name: "MockSeq3", mfa: {MockSeq3, :start_link, []}]
    ]

    Automata.start_automata(automata_config: automata_config)
  end
end
