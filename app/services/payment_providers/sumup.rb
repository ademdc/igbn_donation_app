require "net/http"

# SumUp Solo readers through the Cloud API: https://developer.sumup.com/terminal-payments/cloud-api/
module PaymentProviders
  class Sumup < Base
    API = "https://api.sumup.com"
    TRANSACTION_STATES = {
      "SUCCESSFUL" => "successful", "FAILED" => "failed", "CANCELLED" => "cancelled",
      "REFUNDED" => "cancelled", "PENDING" => "pending"
    }.freeze
    ERROR_CODES = { "READER_BUSY" => :reader_busy, "READER_OFFLINE" => :reader_offline }.freeze

    def self.key
      "sumup"
    end

    def self.fields
      [
        Field.new(key: :api_key, secret: true, required: true),
        Field.new(key: :merchant_code, secret: false, required: true),
        Field.new(key: :affiliate_key, secret: true, required: false),
        Field.new(key: :affiliate_app_id, secret: false, required: false)
      ]
    end

    def self.supports_pairing?
      true
    end

    def verify
      request(Net::HTTP::Get, readers_path)
      true
    end

    def create_checkout(amount:, currency:, reader_id:, description:, webhook_url:)
      body = {
        total_amount: { value: (amount * 100).round, currency: currency, minor_unit: 2 },
        description: description
      }
      # SumUp only accepts HTTPS, so local development falls back to polling
      body[:return_url] = webhook_url if webhook_url.start_with?("https://")
      if @credentials[:affiliate_key].present? && @credentials[:affiliate_app_id].present?
        body[:affiliate] = { app_id: @credentials[:affiliate_app_id], key: @credentials[:affiliate_key] }
      end

      request(Net::HTTP::Post, "#{readers_path}/#{reader_id}/checkout", body).dig("data", "client_transaction_id")
    end

    def checkout_status(checkout_id)
      query = URI.encode_www_form(client_transaction_id: checkout_id)
      transaction = request(Net::HTTP::Get, "/v2.1/merchants/#{merchant_code}/transactions?#{query}")
      CheckoutResult.new(state: TRANSACTION_STATES.fetch(transaction["status"], "pending"),
                         transaction_code: transaction["transaction_code"])
    rescue Error => e
      # SumUp doesn't say how soon a transaction appears after the checkout was accepted
      raise unless e.code == :not_found
      CheckoutResult.new(state: "pending")
    end

    def reader_status(reader_id)
      data = request(Net::HTTP::Get, "#{readers_path}/#{reader_id}/status").fetch("data", {})
      ReaderStatus.new(online: data["status"] == "ONLINE", state: data["state"])
    end

    def pair_reader(code:, name:)
      request(Net::HTTP::Post, readers_path, { pairing_code: code.to_s.strip, name: name })["id"]
    end

    def parse_webhook(payload)
      return unless payload["event_type"] == "solo.transaction.updated"

      WebhookEvent.new(checkout_id: payload.dig("payload", "client_transaction_id"),
                       state: payload.dig("payload", "status"))
    end

    private

    def merchant_code
      @credentials[:merchant_code]
    end

    def readers_path
      "/v0.1/merchants/#{merchant_code}/readers"
    end

    def request(klass, path, body = nil)
      uri = URI("#{API}#{path}")
      req = klass.new(uri)
      req["Authorization"] = "Bearer #{@credentials[:api_key]}"
      req["Content-Type"] = "application/json"
      req.body = body.to_json if body

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(req) }
      json = response.body.present? ? (JSON.parse(response.body) rescue {}) : {}
      raise_error(response, json) unless response.is_a?(Net::HTTPSuccess)
      json
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise Error.new("SumUp unreachable: #{e.message}", code: :provider_unreachable)
    end

    def raise_error(response, json)
      code =
        case response.code.to_i
        when 401, 403 then :unauthorized
        when 404 then :not_found
        else ERROR_CODES.fetch(json.dig("errors", "type"), :provider_error)
        end
      raise Error.new("SumUp #{response.code}: #{json.dig("errors", "detail") || json["message"]}", code: code)
    end
  end
end
