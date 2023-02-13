# frozen_string_literal: true

module ExternalResource
  class CreateOrder
    def initialize(order)
      @order = order
      @client = ::ExternalResource::Client.new(ExternalResource.api_key)
    end

    def call
      response = client.book(event_id, **ticket_counts)
      if response["error"]
        mark_fail
        raise ::ExternalResource::Client::ApiError, "Не удалось создать заказ #{order.id}, " \
                                                    "id заказа в системе '#{response&.dig('Ticket ID')}': #{response['error']}"
      else
        mark_success
        SupplierOrderLink.create(order: order, link: response["ticket_url"])
        response["Ticket ID"]
      end
    rescue ::ExternalResource::Client::ApiError => e
      SendToSlack.send_message("#reki_spb", e.message)
      raise ExternalApiError.new(ExternalApiError::GENERIC_ERROR, e.message)
    end

    private

    attr_reader :order, :client

    def event_id
      order.event.foreign_id.to_i
    end

    def ticket_counts
      result = Hash.new(0)

      line_items_by_category.each do |category, items|
        count = items.sum(&:quantity)
        result[category.to_sym] += count
      end

      result.merge({ agent_info: agent_info })
    end

    def agent_info
      { order_info:
        { customer_name: order.attendee.name.wrapped_string,
          customer_phone: order.attendee.phone,
          all_cost: order.real_cost,
          amount_paid: order.amount_paid,
          amount_to_pay: order.amount_due_in },
        agent_prices_info:
        { adults: order.tickets.find_by(supplier_category_code: "adults")&.ticket_cost,
          social: order.tickets.find_by(supplier_category_code: "social")&.ticket_cost,
          kids: order.tickets.find_by(supplier_category_code: "kids")&.ticket_cost } }
    end

    def line_items_by_category
      order.line_items_with_quantity.includes(:ticket).group_by(&:supplier_category_code)
    end

    def mark_success
      PostOrderAction.execute(
        order, nil,
        "supplier_order_create_success",
        title: "заказ подтвержден у поставщика"
      )
    end

    def mark_fail
      PostOrderAction.execute(
        order, nil,
        "supplier_order_create_failure",
        title: "не удалось провести бронирование; недостаточно свободных мест"
      )
    end
  end
end
