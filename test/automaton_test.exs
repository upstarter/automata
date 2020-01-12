defmodule AutomatonTest do
  use ExUnit.Case
  doctest Automaton

  test "greets the world" do
    assert Automaton.hello() == :world
  end
end
