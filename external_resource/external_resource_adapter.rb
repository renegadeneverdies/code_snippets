# frozen_string_literal: true

# adapter for making order by external suppliers
module ExternalResource
  class Adapter
    SUPPLIER_CATEGORIES = ["adults", "kids", "social"]

    TEMPORARY_ERRORS = []

    def initialize(order, actor)
      @order = order
      @actor = actor
    end

    def create_order(_log_io)
      supplier_order_id = ExternalResource::CreateOrder.new(order).call

      { supplier_order_id: supplier_order_id }
    end

    def cancel_order(_supplier_order_id, _log_io = nil)
      ExternalResource::CancelOrder.call(@order, @actor)
    end

    def config_errors
      errors = []
      errors << "тур не найден в расписании поставщика" if blank_foreign_id?
      errors << "не все билеты имеют корректную категорию у поставщика" if wrong_supplier_categories?

      errors
    end

    private

    attr_reader :order

    def blank_foreign_id?
      order.event.foreign_id.blank?
    end

    def wrong_supplier_categories?
      order_supplier_categories = order.line_items_with_quantity.joins(:ticket).pluck(:supplier_category_code)
      unknown_categories = order_supplier_categories - SUPPLIER_CATEGORIES
      unknown_categories.present?
    end
  end
end
