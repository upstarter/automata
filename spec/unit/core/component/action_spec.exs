# Unit test the core functions and behavior of an Action
defmodule ActionSpec do
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
    context "updating from the root" do
      it "updates all children" do
        send(MockSeq1Server, :update)
        # require IEx
        # IEx.pry()
        assert GenServer.call(MockSeq1Server, :status) == :bh_running
      end
    end
  end

  # describe "#on_init" do
  #   context "when status == :fresh" do
  #     it "" do
  #     end
  #   end

  #   context "when status == :running" do
  #     it "" do
  #     end
  #   end
  #
  #   context "when status == :success" do
  #     it "" do
  #     end
  #   end
  #
  #   context "when status == :failure" do
  #     it "" do
  #     end
  #   end

  #   context "when status == :aborted" do
  #     it "" do
  #     end
  #   end
  #
  # end
  #
  # describe "#on_terminate" do
  #   context "when status == :fresh" do
  #     it "" do
  #     end
  #   end

  #   context "when status == :running" do
  #     it "" do
  #     end
  #   end
  #
  #   context "when status == :success" do
  #     it "" do
  #     end
  #   end
  #
  #   context "when status == :failure" do
  #     it "" do
  #     end
  #   end

  #   context "when status == :aborted" do
  #     it "" do
  #     end
  #   end
  # end
  # end
end
