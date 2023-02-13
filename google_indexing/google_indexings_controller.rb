# frozen_string_literal: true

# manually add entity page for indexing from its editing page
module Admin
  class GoogleIndexingsController < AdminController
    before_action :authorize_client, only: [:update, :destroy]
    before_action :check_policy, only: [:update, :destroy]
    BASE_URL = "https://www.example.org"

    def update
      client.update_url(insert_domain(params[:url]))
      redirect_back(fallback_location: root_path)
    end

    def destroy
      client.delete_url(insert_domain(params[:url]))
      redirect_back(fallback_location: root_path)
    end

    private

    def insert_domain(url)
      "#{BASE_URL}#{url}"
    end

    def client
      @client ||= Google::IndexingClient.new
    end

    def authorize_client
      client.authorize
    end

    def check_policy
      Google::IndexingPolicy.allowed?(params[:url])
    end
  end
end
