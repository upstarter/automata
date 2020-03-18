defmodule BehaviorTest do
  use ESpec
  doctest Automaton.Behavior

  # TODO: ex_spec for context, it BDD style, property testing

  let(:nodes_config) do
    # TODO: Load user-configs into node_configs
    nodes_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}],
      [name: "MockSeq2", mfa: {MockSeq2, :start_link, []}],
      [name: "MockSeq3", mfa: {MockSeq3, :start_link, []}]
    ]

    [nodes_config: nodes_config]
  end

  describe "#add_child" do
    context "" do
      it(do: expect(true |> to(be_true())))
      it(do: 1..3 |> should(have(2)))

      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#remove_child" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#clear_children" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#continue_status" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end
end
