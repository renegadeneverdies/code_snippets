# frozen_string_literal: true

module ExternalResource
  class CancelOrder
    class << self
      def call(order, actor)
        client = ::ExternalResource::Client.new(ExternalResource.api_key)
        response = client.cancel(order.supplier_order_id,
                                reason: order.order_cancel_reason&.reason || "заказ отменен туристом")

        if response.blank?
          mark_success(order, actor)
          response
        else
          mark_fail(order, actor)
          raise ::ExternalResource::Client::ApiError, "Не удалось отменить заказ #{order.id}, " \
                                                      "id заказа в системе '#{order.supplier_order_id}'"
        end
      rescue ::ExternalResource::Client::ApiError => e
        SendToSlack.send_message("#reki_spb", e.message)
        raise ExternalApiError.new(ExternalApiError::GENERIC_ERROR, e.message)
      end

      private

      def mark_success(order, actor)
        PostOrderAction.execute(
          order, actor,
          "supplier_order_cancel_success",
          title: "заказ отменен у поставщика"
        )
      end

      def mark_fail(order, actor)
        PostOrderAction.execute(
          order, actor,
          "supplier_order_cancel_failure",
          title: "не удалось провести отмену"
        )
      end
    end
  end
end
