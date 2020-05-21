defmodule AutomataTest do
  use ExUnit.Case

  def setup do
    automata_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    {:ok, automata_config: automata_config}
  end

  test "context was modified", context do
    # Automata.start_automata(context[:automata_config])
  end
end
