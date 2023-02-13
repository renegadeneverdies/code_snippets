# frozen_string_literal: true

module ExternalResource
  class Client
    class ApiError < StandardError; end

    def initialize(api_key)
      @api_key = api_key
    end

    def routes
      get("availableRoutes")
    end

    def event(route_id, date: nil)
      options = date.nil? ? { api_key: @api_key } : { api_key: @api_key, date_from: date, date_to: date }
      get("availableTours/#{route_id}", options)
    end

    def book(tour_id, agent_info: nil, adults: 0, kids: 0, social: 0)
      post("bookTickets", { api_key: @api_key, tour_id: tour_id, adults: adults, kids: kids, social: social,
                            order_info: agent_info[:order_info],
                            agent_prices_info: agent_info[:agent_prices_info] })
    end

    def cancel(ticket_id, reason: "cancelled_by_attendee")
      post("transactionCancel", { api_key: @api_key, ticketID: ticket_id, cancellation_reason: reason })
    end

    private

    attr_reader :api_key

    def get(path, params = {})
      uri = URI("#{API_BASE_URL}/#{path}")
      uri.query = params.to_query
      request = Net::HTTP::Get.new(uri.request_uri)

      response = proxy_https_client(uri).request(request)
      handle_response(uri, response)
    end

    def post(path, body = {})
      uri = URI("#{API_BASE_URL}/#{path}")
      request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      request.body = body.to_json

      response = proxy_https_client(uri).request(request)
      handle_response(uri, response)
    end

    def handle_response(uri, response)
      json = JSON.parse(response.body)

      return json if json["error"] == "Total tickets should be less or equal to available seats"

      raise ApiError, "Failed request #{uri}: #{json['error']}" unless json["success"]

      json["response"]
    rescue JSON::ParserError
      raise ApiError, "JSON parse error at request #{uri}: #{response.body}"
    end

    def proxy_https_client(uri)
      http = Proximo.http_client.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end
  end
end
