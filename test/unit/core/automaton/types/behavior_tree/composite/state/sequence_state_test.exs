# test the sequence state changes, data flows, and contract checking as applicable
defmodule SequenceStateTest do
  use ExUnit.Case

  setup_all do
    automata_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    Automata.start_automata(automata_config: automata_config)
  end

  describe "#update" do
    #   describe "when status == :fresh" do
    #     test "" do
    #     end
    #   end

    #   describe "when status == :running" do
    #     test "" do
    #     end
    #   end
    #
    #   describe "when status == :success" do
    #     test "" do
    #     end
    #   end
    #
    #   describe "when status == :failure" do
    #     test "" do
    #     end
    #   end

    #   describe "when status == :aborted" do
    #     test "" do
    #     end
    #   end
  end
end
