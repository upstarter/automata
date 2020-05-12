# test the sequence,
defmodule SequenceSpec do
  use ESpec
  doctest Automaton.Types.BT.Behavior

  # TODO: ex_spec for context, it BDD style, property testing

  let(:agents_config) do
    # TODO: Load user-configs into agent_config
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
  #
  # describe "#reset" do
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
  #
  # describe "#abort" do
  #   context "when running" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#running?" do
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
  #
  # describe "#aborted?" do
  #   context "when running" do
  #     it "" do
  #     end
  #   end
  # end
  #
  # describe "#terminated?" do
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
  #
  # describe "#get_status" do
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
  #
  # describe "#set_status" do
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
end
