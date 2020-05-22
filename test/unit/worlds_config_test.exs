defmodule WorldsConfigTest do
  use ExUnit.Case, async: true

  describe "start" do
    test "start", _context do
      # # Automata.start_automata(_context[:automata_config])
    end
  end

  describe "start_worlds" do
    test "start_worlds" do
      status = GenServer.call(MockSeq1Server, :status)
      assert status == :bh_fresh
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
