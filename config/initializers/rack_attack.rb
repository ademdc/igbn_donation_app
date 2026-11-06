# Throttle login and password-reset attempts to slow down guessing.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

Rack::Attack.enabled = !Rails.env.test?

AUTH_PATHS = %r{\A(/[a-z]{2})?/(login|password_resets|admin/login)\z}

Rack::Attack.throttle("auth/ip", limit: 10, period: 1.minute) do |request|
  request.ip if request.post? && request.path.match?(AUTH_PATHS)
end

Rack::Attack.throttle("auth/email", limit: 5, period: 1.minute) do |request|
  if request.post? && request.path.match?(AUTH_PATHS)
    email = request.params["email"].to_s.strip.downcase.presence
    "#{request.host}:#{email}" if email
  end
end

# A terminal page is public, so anyone with the link could wake its card reader over and over
Rack::Attack.throttle("donations/host", limit: 20, period: 1.minute) do |request|
  request.host if request.post? && request.path == "/donations"
end

Rack::Attack.throttle("signup/ip", limit: 5, period: 1.hour) do |request|
  request.ip if request.post? && request.path.match?(%r{\A/[a-z]{2}/signup\z})
end
