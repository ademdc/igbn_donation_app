# The apex domain the product runs on (e.g. domain.com). Accounts and terminals
# live on its subdomains; the apex and www serve the marketing site.
module AppDomain
  def self.host
    ENV.fetch("APP_DOMAIN", "localhost").downcase
  end

  def self.marketing_host?(host)
    host = host.to_s.downcase
    host == self.host || host == "www.#{self.host}"
  end

  # Absolute URL on a given host, e.g. for emails and QR codes
  def self.url(host, path = "/")
    port = Rails.configuration.x.app_port
    "#{Rails.configuration.x.app_protocol}://#{host}#{":#{port}" if port}#{path}"
  end

  def self.marketing_url(path = "/")
    url(self.host, path)
  end

  # Routing constraint for the marketing site and the super admin
  def self.matches?(request)
    marketing_host?(request.host)
  end
end
