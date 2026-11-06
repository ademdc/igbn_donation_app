require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DonationApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1
    config.autoload_lib(ignore: %w(assets tasks))

    config.hosts << "#{ENV["FLY_APP_NAME"]}.fly.dev" if ENV["FLY_APP_NAME"].present?

    # Account and terminal hosts, e.g. acme.domain.com and terminal1.acme.domain.com.
    # In development *.localhost is allowed by default.
    if ENV["APP_DOMAIN"].present?
      config.hosts << ENV["APP_DOMAIN"]
      config.hosts << /([a-z0-9-]+\.){1,2}#{Regexp.escape(ENV["APP_DOMAIN"])}/
    end
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.yml")]
    config.i18n.available_locales = %i[de en bs]
    config.i18n.default_locale = :de

    config.x.brand_name = ENV.fetch("BRAND_NAME", "Digital Donation")
    config.x.contact_email = ENV.fetch("CONTACT_EMAIL", "hello@#{ENV.fetch("APP_DOMAIN", "example.com")}")
    config.x.mail_from = ENV.fetch("MAIL_FROM", "#{config.x.brand_name} <#{config.x.contact_email}>")

    # "nested": terminal1.acme.domain.com, one Let's Encrypt certificate per terminal via the Fly API.
    # "flat":   terminal1-acme.domain.com, covered by the *.domain.com certificate.
    config.x.terminal_hosts = ENV.fetch("TERMINAL_HOSTS", "nested")

    # Encrypts the payment providers' API keys. `bin/rails db:encryption:init` generates these.
    config.active_record.encryption.primary_key = ENV.fetch("ENCRYPTION_PRIMARY_KEY") { "dev-only-primary-key-000000000000" unless Rails.env.production? }
    config.active_record.encryption.deterministic_key = ENV.fetch("ENCRYPTION_DETERMINISTIC_KEY") { "dev-only-deterministic-key-000000" unless Rails.env.production? }
    config.active_record.encryption.key_derivation_salt = ENV.fetch("ENCRYPTION_KEY_DERIVATION_SALT") { "dev-only-key-derivation-salt-0000" unless Rails.env.production? }

    # Used to build absolute links to account and terminal hosts
    config.x.app_protocol = "https"
    config.x.app_port = nil
  end
end
