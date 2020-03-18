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

  describe "#on_init" do
    context "" do
      it(do: expect(true |> to(be_true())))
      it(do: 1..3 |> should(have(2)))

      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#update" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#on_terminate" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#reset" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#abort" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#running?" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#aborted?" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#terminated?" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#get_status" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end

  describe "#et_status" do
    context "" do
      it "" do
        Automata.start_nodes(nodes_config)
      end
    end
  end
end
