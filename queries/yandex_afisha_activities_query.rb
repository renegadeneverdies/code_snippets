
# frozen_string_literal: true

module YandexAfisha
  class ActivitiesQuery
    class << self
      def call(city_id: nil, activities_ids: [], updated_after: nil, date_from: nil, date_to: nil)
        relation = yandex_afisha_activities
        relation = filter_by_activities_ids(relation, activities_ids)
        relation = filter_by_city_id(relation, city_id)
        relation = filter_by_updated_after(relation, updated_after)
        filter_by_dates(relation, date_from, date_to)
      end

      private

      def filter_by_activities_ids(relation, activities_ids)
        activities_ids.present? ? relation.where(id: activities_ids) : relation
      end

      def filter_by_city_id(relation, city_id)
        city_id.present? ? relation.where(city_id: city_id) : relation
      end

      def filter_by_updated_after(relation, updated_after)
        updated_after.present? ? relation.where("activities.updated_at > ?", updated_after.to_datetime) : relation
      end

      def filter_by_dates(relation, date_from, date_to)
        return relation if date_from.blank? && date_to.blank?

        new_relation = activities_joined_with_events(relation)
        new_relation = activities_with_bookable_events(new_relation)
        new_relation = filter_by_date_from(new_relation, date_from)
        filter_by_date_to(new_relation, date_to)
      end

      def activities_joined_with_events(relation)
        relation.left_joins(:events)
      end

      def activities_with_bookable_events(relation)
        relation.where("events.book_before > NOW() AND events.is_hidden = 'f'")
      end

      def filter_by_date_from(relation, date)
        return relation if date.blank?

        relation.where("(events.date + events.time) >= :date", date: date.to_datetime)
      end

      def filter_by_date_to(relation, date)
        return relation if date.blank?

        relation.where("(events.date + events.time) <= :date", date: date.to_datetime)
      end

      def yandex_afisha_activities
        setting_activities_on_index
          .with_languages(ShownLocales.lang_ids_for_locale(:ru))
          .includes(:host, :city, :translations)
          .references(:host, :city, :translations)
      end

      def setting_activities_on_index
        scope = Activity.where(id: YandexAfisha::SettingActivityIdsReceiverService.call).active.not_test
        parents_ids = Activity.where(id: scope.pluck(:parent_activity_id), not_on_index: false).pluck(:id)
        scope.where(parent_activity_id: nil, not_on_index: false).or(scope.where(parent_activity_id: parents_ids))
      end
    end
  end
end
