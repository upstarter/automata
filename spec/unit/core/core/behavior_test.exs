defmodule BehaviorTest do
  use ESpec
  doctest Automaton.Behavior

  before_all do
    nodes_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}]
    ]

    [nodes_config: nodes_config]

    Automata.start_nodes(nodes_config)
  end

  describe "#update" do
    context "updating the tree from the root" do
      it "ticks all the children" do
        GenServer.call(MockSeq1, :update)
      end
    end
  end

  describe "#on_init" do
    context "" do
      it "" do
      end
    end
  end

  describe "#on_terminate" do
    context "" do
      it "" do
      end
    end
  end

  describe "#reset" do
    context "" do
      it "" do
      end
    end
  end

  describe "#abort" do
    context "" do
      it "" do
      end
    end
  end

  describe "#running?" do
    context "" do
      it "" do
      end
    end
  end

  describe "#aborted?" do
    context "" do
      it "" do
      end
    end
  end

  describe "#terminated?" do
    context "" do
      it "" do
      end
    end
  end

  describe "#get_status" do
    context "" do
      it "" do
      end
    end
  end

  describe "#set_status" do
    context "" do
      it "" do
      end
    end
  end
end
