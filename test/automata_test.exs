defmodule AutomataTest do
  use ExUnit.Case
  doctest Automata

  test "greets the world" do
    nodes_config = [
      [name: "MockUserNode1", mfa: {MockUserNode1, :start_link, []}],
      [name: "MockUserNode2", mfa: {MockUserNode2, :start_link, []}],
      [name: "MockUserNode3", mfa: {MockUserNode3, :start_link, []}]
    ]

    assert Automata.start_nodes(nodes_config)
  end
end
