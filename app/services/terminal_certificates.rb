require "net/http"

# terminal1.acme.domain.com is two labels deep, so the *.domain.com certificate doesn't
# cover it (the DNS wildcard does). Each terminal gets its own Let's Encrypt certificate
# through the Fly Machines API, validated by Fly itself once the hostname resolves.
#
# ENV: FLY_API_TOKEN (fly tokens create deploy). Fly sets FLY_APP_NAME itself.
module TerminalCertificates
  API = "https://api.machines.dev/v1"

  class Error < StandardError; end

  def self.configured?
    ENV["FLY_API_TOKEN"].present? && ENV["FLY_APP_NAME"].present?
  end

  def self.needed?
    configured? && Rails.configuration.x.terminal_hosts != "flat"
  end

  # Requests the certificate if it's new. Returns true once it's issued.
  def self.request_for(hostname)
    issued?(call(Net::HTTP::Post, "/apps/#{app}/certificates/acme", { hostname: hostname }))
  rescue Error
    # Already requested: ask Fly to check it again
    issued?(call(Net::HTTP::Post, "/apps/#{app}/certificates/#{hostname}/check"))
  end

  def self.remove(hostname)
    return unless configured?
    call(Net::HTTP::Delete, "/apps/#{app}/certificates/#{hostname}")
  rescue Error => e
    Rails.logger.error "Certificate for #{hostname} not removed: #{e.message}"
  end

  def self.app
    ENV.fetch("FLY_APP_NAME")
  end
  private_class_method :app

  def self.issued?(json)
    Array(json["certificates"]).any? { |certificate| certificate["status"] == "active" } ||
      json["status"].to_s.casecmp?("ready")
  end
  private_class_method :issued?

  # `fly tokens create` prints "FlyV1 …" tokens, older personal tokens are plain bearer tokens
  def self.authorization
    token = ENV.fetch("FLY_API_TOKEN")
    token.start_with?("FlyV1 ") ? token : "Bearer #{token}"
  end
  private_class_method :authorization

  def self.call(klass, path, body = nil)
    uri = URI("#{API}#{path}")
    req = klass.new(uri)
    req["Authorization"] = authorization
    req["Content-Type"] = "application/json"
    req.body = body.to_json if body

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(req) }
    json = response.body.present? ? (JSON.parse(response.body) rescue { "error" => response.body }) : {}
    raise Error, "#{response.code} #{json["error"] || json["message"]}" unless response.is_a?(Net::HTTPSuccess)
    json
  end
  private_class_method :call
end
