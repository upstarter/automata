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

  let(:opts) do
  end

  # {:ok, state} = MockSeq1.init(opts)
  # {:noreply, state} = MockSeq1.handle_info({:update, A, 1}, state)
  # # assertion about state
  # {:noreply, state} = MockSeq1.handle_info({:on_init, B, 1}, state)
  # # assertion about state
  # {:noreply, state} = MockSeq1.handle_info({:on_terminate, A, 2}, state)
  # # assertion about state
  # {:noreply, state} = MockSeq1.handle_info({:blah, B, 2}, state)
  # # assertion about state

  describe "#update" do
    context "updating the tree from the root" do
      it "ticks all the children" do
        assert GenServer.call(MockSeq1, :update) == :bh_running
      end
    end
  end

  # describe "#on_init" do
  #   context "" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#on_terminate" do
  #   context "" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#reset" do
  #   context "" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#abort" do
  #   context "" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#running?" do
  #   context "" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#aborted?" do
  #   context "" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#terminated?" do
  #   context "" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#get_status" do
  #   context "" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#set_status" do
  #   context "" do
  #     it "" do
  #     end
  #   end
  # end
end
