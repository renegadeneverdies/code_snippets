# frozen_string_literal: true

require "google/apis/indexing_v3"
require "googleauth"

module Google
  class ApiError < StandardError; end

  class IndexingClient
    Indexing = Google::Apis::IndexingV3

    attr_reader :indexer

    SCOPE = "https://www.googleapis.com/auth/indexing"
    JSON_KEY_FILE = ::Rails.root.join("config", "credentials.json")

    def initialize
      @indexer = Indexing::IndexingService.new
    end

    def authorize
      @indexer.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(JSON_KEY_FILE),
        scope: SCOPE)
      indexer.authorization.fetch_access_token!
    end

    def update_url(url)
      handle(:publish_url_notification, url, "URL_UPDATED")
    end

    def delete_url(url)
      handle(:publish_url_notification, url, "URL_DELETED")
    end

    def check_status(url)
      handle(:get_url_notification_metadata, url)
    end

    private

    def create_url_object(url, type = nil)
      url_object = Indexing::UrlNotification.new
      url_object.url = url
      url_object.type = type
      url_object
    end

    def handle(method, url, type = nil)
      indexer.send(method, create_url_object(url, type))
    rescue Google::Apis::ClientError => e
      raise ApiError, "Indexer #{e} with url=#{url} & type=#{type}"
    rescue Google::Apis::AuthorizationError
      raise ApiError, "Indexer failed authorization"
    end
  end
end
