# frozen_string_literal: true

module DataAdapter
  class ExternalResourceApi
    TIMEZONE = "+03:00"

    attr_accessor :options, :event_id, :activity_id

    def initialize(options)
      @options = options
      @activity_id = options[:activity].id
      @event_id = options[:activity].external_schedule.keyword.to_i
      @client = ExternalResource::Client.new(ExternalResource.api_key)
    end

    def call
      tours = @client.event(event_id)["tours"]
      tours.map { |tour| format_tour_data(tour) }.compact
    end

    private

    def format_tour_data(tour)
      datetime = DateTime.parse("#{tour['date']} #{TIMEZONE}")

      return unless day_in_list?(datetime.to_date)

      {
        datetime: datetime,
        capacity: tour["available_seats"].to_i,
        seats_info: tour["available_seats"].to_i,
        foreign_id: tour["id"]
      }
    end

    def day_in_list?(date)
      return true if date_list.blank?

      date_list.include?(date.to_s)
    end

    # tour prices are higher on weekends
    def date_list
      return @date_list if defined?(@date_list)

      @date_list = found_dates_in_settings_by_key("activities-weekday")
      @date_list ||= found_dates_in_settings_by_key("activities-weekend")
    end

    # fetch setting with weekday and weekend days
    def found_dates_in_settings_by_key(setting_key)
      return if Setting.get(setting_key).blank?

      activities, dates = Setting.get(setting_key).split(": ")

      return if activities.split(", ").exclude?(@activity_id.to_s)

      dates.split(", ").presence
    end
  end
end
