defmodule AutomataTest do
  use ExUnit.Case
  doctest Automata

  test "greets the world" do
    nodes_config = [
      [name: "Automaton1", mfa: {Automaton, :start_link, []}, size: 4],
      [name: "Automaton2", mfa: {Automaton, :start_link, []}, size: 2],
      [name: "Automaton3", mfa: {Automaton, :start_link, []}, size: 1]
    ]

    assert Automata.start_nodes(nodes_config)
  end
end
