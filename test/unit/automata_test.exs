defmodule AutomataTest do
  use ExUnit.Case, async: true

  setup_all do
    automata_config = [
      [name: "MockSeq1", mfa: {TestMockSeq1, :start_link, []}]
    ]

    # Automata.start_automata(automata_config: automata_config)
    :ok
  end

  describe "start" do
    test "start", _context do
      # # Automata.start_automata(_context[:automata_config])
    end
  end

  describe "start_worlds" do
    test "start_worlds", _context do
    end
  end

  describe "start_world" do
    test "start_world", _context do
    end
  end

  describe "start_automata" do
    test "start_automata", _context do
    end
  end

  describe "status" do
    test "status", _context do
    end
  end
end
