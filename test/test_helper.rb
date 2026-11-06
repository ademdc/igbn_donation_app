ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    def create_account(subdomain: "acme", **attributes)
      account = Account.create!(name: subdomain.capitalize, subdomain: subdomain, **attributes)
      account.users.create!(name: "Owner", email: "owner@#{subdomain}.test", password: "correct-horse-battery")
      account
    end

    def connect_test_mode(account)
      account.payment_connections.find_or_create_by!(provider: "test")
    end

    def sumup_connection(account)
      account.payment_connections.create!(provider: "sumup", credentials: { "api_key" => "sup_sk_secret1234", "merchant_code" => "MK01A8C2" })
    end

    def create_terminal(account, slug: "terminal1", connection: connect_test_mode(account), **attributes)
      account.terminals.create!(name: slug, slug: slug, payment_connection: connection, **attributes)
    end
  end
end

class ActionDispatch::IntegrationTest
  def sign_in_to(account, user = account.users.first, password: "correct-horse-battery")
    host! account.host
    post "/login", params: { email: user.email, password: password }
  end
end
