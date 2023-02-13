require "rails_helper"

describe Atol::SellWorker do
  subject(:worker) { described_class.new }

  let(:order) { create(:order) }
  let(:amount) { 100 }
  let(:transaction_id) { "123" }
  let(:mark_start) { "atol_Order_sell_start_#{transaction_id}" }
  let(:mark_end) { "atol_Order_sell_end_#{transaction_id}" }
  let(:perform) { worker.perform(order.id, "Order", transaction_id, amount) }

  before { allow(Atol::Order::Sell).to receive(:call) }

  context "when order is not marked at all" do
    it "calls sell" do
      expect(Atol::Order::Sell).to receive(:call)
      perform
    end
  end

  context "when worker tries to duplicate a sale" do
    before do
      order.mark!(mark_start)
      order.mark!(mark_end)
    end

    it "returns without action" do
      expect(perform).to be_nil
    end
  end
end
