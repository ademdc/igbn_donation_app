require "test_helper"

class PaymentConnectionTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    @connection = sumup_connection(@account)
  end

  test "credentials are encrypted at rest" do
    raw = PaymentConnection.connection.select_value("SELECT credentials FROM payment_connections WHERE id = #{@connection.id}")

    assert_not_includes raw, "sup_sk_secret1234"
    assert_equal "sup_sk_secret1234", @connection.reload.credentials["api_key"]
  end

  test "required credentials must be present" do
    connection = create_account(subdomain: "other").payment_connections.new(provider: "sumup", credentials: { "api_key" => "x" })

    assert_not connection.valid?
  end

  test "blank fields keep the stored secret" do
    @connection.merge_credentials("api_key" => "", "merchant_code" => "MK99", "unknown" => "dropped")

    assert_equal "sup_sk_secret1234", @connection.credentials["api_key"]
    assert_equal "MK99", @connection.credentials["merchant_code"]
    assert_not @connection.credentials.key?("unknown")
  end

  test "masks secrets" do
    assert_equal "••••1234", @connection.masked(:api_key)
  end

  test "verify records success and reports rejection" do
    stub_request(:get, %r{/readers}).to_return(body: { items: [] }.to_json)
    assert @connection.verify
    assert @connection.verified_at

    stub_request(:get, %r{/readers}).to_return(status: 401, body: "{}")
    assert_not @connection.verify
    assert @connection.errors[:base].any?
  end
end
