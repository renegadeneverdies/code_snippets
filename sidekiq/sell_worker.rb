class Atol::SellWorker
  AtolSellAlreadyExistError = Class.new(StandardError)

  include Sidekiq::Worker
  sidekiq_options queue: "atol"

  def perform(payable_id, payable_type, transaction_id, received_paid_amount_in_rub = nil, time_interval = 30)
    payable = payable_type.constantize.find(payable_id)
    mark_start = "atol_#{payable_type}_sell_start_#{transaction_id}"
    mark_end = "atol_#{payable_type}_sell_end_#{transaction_id}"
    mark_fail = "atol_#{payable_type}_sell failed"

    return if payable.marked?(mark_start) && !payable.marked?(mark_fail) || payable.marked?(mark_end)

    payable.mark!(mark_start)
    begin
      case payable.class.to_s
      when "Order"
        Atol::Order::Sell.call(payable, received_paid_amount_in_rub: received_paid_amount_in_rub)
      when "OrderList::UnpaidFee"
        Atol::Fee::SellerService.call(payable) if payable.extra_conversion_amount > 0
      when "Coupon"
        Atol::Coupon::SellerService.call(payable)
      end
    rescue OpenURI::HTTPError, URI::InvalidURIError, OpenSSL::SSL::SSLError,
           Net::HTTPServerException, Net::ReadTimeout, Zlib::DataError
      payable.mark!(mark_fail)
      Atol::SellWorker.perform_in(time_interval.seconds, payable_id, payable_type,
                                  transaction_id, received_paid_amount_in_rub, time_interval * 2)
    end
    payable.mark!(mark_end)
  end
end
