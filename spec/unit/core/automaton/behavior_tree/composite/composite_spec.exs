# Unit Tests for the core functions and behavior of the Composite behaviour
defmodule CompositeSpec do
  use ESpec
  doctest Automaton.Types.BT.Behavior

  let(:agents_config) do
    agents_config = [
      [name: "MockSeq1", mfa: {MockSeq1, :start_link, []}],
      [name: "MockSeq2", mfa: {MockSeq2, :start_link, []}],
      [name: "MockSeq3", mfa: {MockSeq3, :start_link, []}]
    ]

    [agents_config: agents_config]
  end

  before_all do
    Automata.start_nodes(agents_config)
  end

  context "updating from the root" do
    it "updates all children" do
      send(MockSeq1Server, :update)
      # require IEx
      # IEx.pry()
      # TODO: assert all children receive message update
      assert GenServer.call(MockSeq1Server, :status) == :bh_running
    end
  end

  describe "#add_child" do
    context "" do
      # it(do: expect(true |> to(be_true())))
      # it(do: 1..3 |> should(have(2)))

      it "" do
      end
    end
  end

  describe "#remove_child" do
    context "" do
      it "" do
      end
    end
  end

  describe "#clear_children" do
    context "" do
      it "" do
      end
    end
  end

  describe "#continue_status" do
    context "" do
      it "" do
      end
    end
  end
end
