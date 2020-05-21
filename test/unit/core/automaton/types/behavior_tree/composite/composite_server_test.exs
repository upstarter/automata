# Unit Tests for the core functions and behavior of the Composite behaviour
defmodule CompositeServerTest do
  use ExUnit.Case

  # TODO: ex_spec for context, it BDD style, property testing

  setup_all do
    # TODO: Load user-configs into automaton_config
    automata_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    Automata.start_automata(automata_config: automata_config)
  end

  describe "#" do
  end
end
