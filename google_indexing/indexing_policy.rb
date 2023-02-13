# frozen_string_literal: true

module Google
  class IndexingPolicy
    class << self
      def allowed?(url)
        if url == "back" || url.include?("admin")
          redirect_back(fallback_location: root_path)
        else
          false
        end
      end
    end
  end
end
